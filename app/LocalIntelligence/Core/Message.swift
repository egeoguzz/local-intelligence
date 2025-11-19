import Foundation

enum MessageRole {
    case user
    case assistant
}

struct Message: Identifiable, Equatable {
    let id = UUID()
    let role: MessageRole
    var content: String
    let timestamp = Date()
    
    // Helper to check if it is a user message
    var isUser: Bool {
        return role == .user
    }
}
