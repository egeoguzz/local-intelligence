import Foundation
import SwiftUI
import Combine
import MLX
import MLXLLM
import MLXLMCommon
import Tokenizers

// MARK: - Model State Management
enum ModelState: Equatable {
    case idle
    case downloading(Double)
    case loading
    case ready
    case error(String)
}

@MainActor
class ModelEngine: ObservableObject {
    
    // MARK: - Published Properties
    @Published var state: ModelState = .idle
    @Published var messages: [Message] = [] // Changed from single String to Array
    @Published var isGenerating: Bool = false
    @Published var isModelDownloaded: Bool = false
    
    private var modelContainer: ModelContainer?
    private let modelId = "mlx-community/Qwen2.5-1.5B-Instruct-4bit" // Configuration: Qwen 2.5 - 1.5B
    private let dataManager = LocalDataManager()
        
    
    init() {
        self.isModelDownloaded = UserDefaults.standard.bool(forKey: "isModelDownloaded")
    }
    
    // MARK: - Model Loading
    func startLoading() async {
        if !isModelDownloaded {
            withAnimation { self.state = .downloading(0) }
        } else {
            withAnimation { self.state = .loading }
        }
        
        do {
            let modelConfiguration = ModelConfiguration(id: modelId)
            
            let container = try await LLMModelFactory.shared.loadContainer(
                configuration: modelConfiguration
            ) { progress in
                Task { @MainActor in
                    if progress.fractionCompleted < 1.0 {
                        self.state = .downloading(progress.fractionCompleted)
                    }
                }
            }
            
            UserDefaults.standard.set(true, forKey: "isModelDownloaded")
            self.isModelDownloaded = true
            
            withAnimation { self.state = .loading }
            self.modelContainer = container
            
            try await Task.sleep(for: .seconds(0.5))
            withAnimation { self.state = .ready }
            
        } catch {
            print("Model Load Error: \(error)")
            withAnimation { self.state = .error(error.localizedDescription) }
        }
    }
    
    // MARK: - History Management
        
        /// Converts the recent chat history into a single string for the model's context window.
        /// We take the last 'limit' messages to prevent the context from getting too large (Memory Management).
        private func buildContextualPrompt(history: [Message], currentInput: String, contextData: String) -> String {
            var prompt = ""
            
            // 1. System Prompt (The Core Personality & Data)
            let dateString = Date().formatted(date: .complete, time: .shortened)
            
            prompt += """
            <|im_start|>system
            You are 'Local Mind', a strictly schedule-focused offline assistant.
            Current Date: \(dateString)
            
            [DATA]
            \(contextData)
            
            RULES:
            1. Your ONLY job is to manage the calendar and schedule.
            2. Keep answers VERY SHORT (max 2 sentences).
            3. Do NOT answer general knowledge questions (like history, math, coding). If asked, say: "I am focused only on your schedule."
            4. Use the [DATA] provided above to answer precise questions.
            <|im_end|>
            """
            
            // 2. Chat History (The Memory)
            // We take the last 6 messages (3 turns) to keep it fast.
            // Adjust this number based on performance needs.
            let recentMessages = history.suffix(6)
            
            for msg in recentMessages {
                let role = msg.isUser ? "user" : "assistant"
                // Clean the content to avoid format injection issues
                let content = msg.content.replacingOccurrences(of: "<|im_end|>", with: "")
                
                if !content.isEmpty {
                    prompt += "<|im_start|>\(role)\n\(content)<|im_end|>\n"
                }
            }
            
            // 3. Current User Input
            prompt += """
            <|im_start|>user
            \(currentInput)<|im_end|>
            <|im_start|>assistant
            """
            
            return prompt
        }
    
    // MARK: - Generation (With Memory & RAG)
        func generate(prompt: String) async {
            guard let container = modelContainer, case .ready = state else { return }
            
            self.isGenerating = true
            
            // 1. Create User Message
            let userMsg = Message(role: .user, content: prompt)
            
            // NOTE: We do NOT append to self.messages yet to avoid duplicating logic in buildContextualPrompt.
            // Or we can append, but exclude the last one in builder.
            // Strategy: Append to UI immediately for responsiveness.
            self.messages.append(userMsg)
            
            // 2. Create Placeholder Assistant Message
            let assistantMsg = Message(role: .assistant, content: "")
            self.messages.append(assistantMsg)
            
            let lastIndex = self.messages.count - 1
            
            // 3. Fetch Real-Time Data (RAG)
            let calendarContext = await dataManager.fetchCalendarContext()
            
            // 4. Build Full Prompt with History
            // We exclude the last 2 messages (the new user prompt and the empty assistant placeholder)
            // from the history array, because we pass 'prompt' explicitly as currentInput.
            let historyForContext = self.messages.dropLast(2)
            let fullPrompt = buildContextualPrompt(
                history: Array(historyForContext),
                currentInput: prompt,
                contextData: calendarContext
            )
            
            // Debug: Check if history is attached
            // print(fullPrompt)
            
            do {
                let _ = try await container.perform { context in
                    let userInput = UserInput(prompt: fullPrompt)
                    let input = try await context.processor.prepare(input: userInput)
                    
                    // Temperature 0.5 is a good balance for chat + facts
                    let parameters = GenerateParameters(maxTokens: 1024, temperature: 0.5)
                    
                    return try MLXLMCommon.generate(
                        input: input,
                        parameters: parameters,
                        context: context
                    ) { tokens in
                        
                        let fullText = context.tokenizer.decode(tokens: tokens)
                        
                        Task { @MainActor in
                            if lastIndex < self.messages.count {
                                self.messages[lastIndex].content = fullText
                            }
                        }
                        return .more
                    }
                }
            } catch {
                if lastIndex < self.messages.count {
                    self.messages[lastIndex].content += "\n[Error: \(error.localizedDescription)]"
                }
            }
            
            self.isGenerating = false
        }
}
