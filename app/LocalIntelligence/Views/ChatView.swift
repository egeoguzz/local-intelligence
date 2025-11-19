import SwiftUI

// MARK: - Suggestion Chips Component
// This struct must be defined so ChatView can find it.
struct SuggestionScrollView: View {
    var onSelect: (String) -> Void
    
    let suggestions = [
        "What's next?",
        "Any plans for tomorrow?",
        "Summarize my week",
        "Am I busy today?"
    ]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(suggestions, id: \.self) { text in
                    Button {
                        onSelect(text)
                    } label: {
                        Text(text)
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.indigo.opacity(0.8))
                            .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 8)
    }
}

// MARK: - Main Chat View
struct ChatView: View {
    @ObservedObject var engine: ModelEngine
    @State private var input: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            
            // MARK: - Messages List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        
                        // Empty State (Context Aware)
                        if engine.messages.isEmpty {
                            VStack(spacing: 15) {
                                Image(systemName: "calendar.day.timeline.left")
                                    .font(.system(size: 50))
                                    .foregroundStyle(.secondary.opacity(0.4))
                                    .padding(.top, 80)
                                
                                Text("Agenda Agent Ready.\nAsk about your schedule, meetings, or free time.")
                                    .multilineTextAlignment(.center)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        // Message Bubbles
                        ForEach(engine.messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }
                        
                        // Loading Indicator
                        if engine.isGenerating {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Checking schedule...")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.leading)
                            .id("loading")
                        }
                    }
                    .padding(.vertical)
                }
                .onChange(of: engine.messages.last?.content) { _, _ in scrollToBottom(proxy: proxy) }
                .onChange(of: engine.messages.count) { _, _ in scrollToBottom(proxy: proxy) }
            }
            
            // MARK: - Suggestion Chips
            // Only show if not generating
            if !engine.isGenerating {
                SuggestionScrollView { selectedText in
                    self.input = selectedText
                    sendMessage()
                }
            }
            
            Divider()
            
            // MARK: - Input Area
            HStack(spacing: 12) {
                TextField("Ask about your day...", text: $input, axis: .vertical)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .focused($isFocused)
                    .lineLimit(1...5)
                    .disabled(engine.isGenerating)
                
                Button {
                    sendMessage()
                } label: {
                    ZStack {
                        Circle()
                            .fill(engine.isGenerating || input.isEmpty ? Color.gray.opacity(0.3) : Color.indigo)
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .disabled(engine.isGenerating || input.isEmpty)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .navigationTitle("My Agenda")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Logic
    private func sendMessage() {
        let prompt = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        input = ""
        isFocused = false
        Task { await engine.generate(prompt: prompt) }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastId = engine.messages.last?.id else { return }
        if engine.isGenerating {
            proxy.scrollTo(lastId, anchor: .bottom)
        } else {
            withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
        }
    }
}
