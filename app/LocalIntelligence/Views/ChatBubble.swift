import SwiftUI

struct ChatBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            // If user, spacer on left to push right
            if message.isUser { Spacer() }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .padding(12)
                    .background(message.isUser ? Color.blue : Color(.secondarySystemBackground))
                    .foregroundColor(message.isUser ? .white : .primary)
                    .cornerRadius(16)
                    // Rounded corner logic:
                    // User: TopLeft, TopRight, BottomLeft
                    // Assistant: TopLeft, TopRight, BottomRight
                    .clipShape(
                        .rect(
                            topLeadingRadius: 16,
                            bottomLeadingRadius: message.isUser ? 16 : 4,
                            bottomTrailingRadius: message.isUser ? 4 : 16,
                            topTrailingRadius: 16
                        )
                    )
                
                // Optional: Timestamp
                /*
                Text(message.timestamp.formatted(.dateTime.hour().minute()))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                 */
            }
            .frame(maxWidth: 300, alignment: message.isUser ? .trailing : .leading)
            
            // If assistant, spacer on right to push left
            if !message.isUser { Spacer() }
        }
        .padding(.horizontal)
    }
}
