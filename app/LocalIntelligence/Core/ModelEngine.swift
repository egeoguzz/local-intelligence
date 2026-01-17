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
    private let modelId = "mlx-community/Llama-3.2-1B-Instruct-4bit" 
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
        
    /// Hybrid Prompt Builder using Pre-Computed Responses (PCR).
        /// This architecture bypasses the LLM's weak reasoning capabilities on 1B models by
        /// injecting the correct answer directly into the system context.
        private func buildContextualPrompt(history: [Message], currentInput: String, contextData: String) -> String {
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "EEEE, MMMM d"
            dateFormatter.locale = Locale(identifier: "en_US")
            
            let today = Date()
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
            let todayStr = dateFormatter.string(from: today)
            let tomorrowStr = dateFormatter.string(from: tomorrow)
            
            let lowerInput = currentInput.lowercased()
            
            // --- STEP 1: PRE-COMPUTE THE ANSWER IN SWIFT (The "Brain") ---
            // We determine exactly what the output should look like using native Swift logic.
            
            var forcedSystemInstruction = ""
            var isStrict = false
            
            // CASE A: TOMORROW
            if lowerInput.contains("tomorrow") || lowerInput.contains("tmrw") {
                isStrict = true
                let lines = contextData.components(separatedBy: "\n")
                let matches = lines.filter { $0.contains(tomorrowStr) }
                
                let finalAnswer = matches.isEmpty ? "No plans for tomorrow." : matches.joined(separator: "\n")
                
                forcedSystemInstruction = """
                USER QUESTION: "Any plans for tomorrow?"
                REQUIRED ANSWER:
                \(finalAnswer)
                
                INSTRUCTION: Output the REQUIRED ANSWER exactly. Do not add any extra text.
                """
            }
            // CASE B: NEXT EVENT
            else if lowerInput.contains("next") {
                isStrict = true
                let lines = contextData.components(separatedBy: "\n").filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).starts(with: "-") }
                let nextEvent = lines.first ?? "No upcoming events found."
                
                forcedSystemInstruction = """
                USER QUESTION: "What's next?"
                REQUIRED ANSWER:
                \(nextEvent)
                
                INSTRUCTION: Output the REQUIRED ANSWER exactly. Do not explain.
                """
            }
            // CASE C: SUMMARIZE / WEEK
            else if lowerInput.contains("summarize") || lowerInput.contains("week") {
                isStrict = true
                let summary = contextData.isEmpty ? "Your schedule is empty." : contextData
                
                forcedSystemInstruction = """
                USER QUESTION: "Summarize my week"
                REQUIRED ANSWER:
                Here is your schedule:
                \(summary)
                
                INSTRUCTION: Output the REQUIRED ANSWER exactly. Do not change "sea", "as" or generic titles.
                """
            }
            // CASE D: TODAY
            else if lowerInput.contains("today") {
                isStrict = true
                let lines = contextData.components(separatedBy: "\n")
                let matches = lines.filter { $0.contains(todayStr) }
                let finalAnswer = matches.isEmpty ? "You are free today." : matches.joined(separator: "\n")
                
                forcedSystemInstruction = """
                USER QUESTION: "Am I busy today?"
                REQUIRED ANSWER:
                \(finalAnswer)
                
                INSTRUCTION: Output the REQUIRED ANSWER.
                """
            }
            // CASE E: GENERAL CONVERSATION
            else {
                isStrict = false
                forcedSystemInstruction = """
                CONTEXT DATA:
                \(contextData)
                
                INSTRUCTION: Answer the user's question using the CONTEXT DATA. Be brief.
                """
            }
            
            // --- STEP 2: CONSTRUCT PROMPT ---
            
            var prompt = "<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\n"
            prompt += "You are DailyMind. Follow instructions strictly.\n"
            prompt += forcedSystemInstruction
            prompt += "<|eot_id|>"
            
            if !isStrict {
                for msg in history.suffix(4) {
                    let role = msg.isUser ? "user" : "assistant"
                    prompt += "<|start_header_id|>\(role)<|end_header_id|>\n\n\(msg.content)<|eot_id|>"
                }
            }
            
            prompt += "<|start_header_id|>user<|end_header_id|>\n\n\(currentInput)<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n\n"
            
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
                    let parameters = GenerateParameters(maxTokens: 1024, temperature: 0.0)
                    
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
