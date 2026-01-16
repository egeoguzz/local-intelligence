import Foundation
import EventKit

class LocalDataManager {
    private let eventStore = EKEventStore()
    
    /// Requests permission and fetches calendar events for the next 7 days.
    /// Returns a formatted string suitable for the LLM context.
    func fetchCalendarContext() async -> String {
        let granted: Bool
        
        // 1. Request Access (iOS 17+ logic vs older versions handled generally here)
        if #available(iOS 17.0, *) {
            granted = await requestAccessiOS17()
        } else {
            granted = await requestAccessLegacy()
        }
        
        guard granted else {
            return "[System: Calendar access denied by user.]"
        }
        
        // 2. Define Date Range (Now to +7 Days)
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: Date())
        guard let endDate = calendar.date(byAdding: .day, value: 7, to: startDate) else { return "" }
        
        // 3. Create Query
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate).sorted { $0.startDate < $1.startDate }
        
        if events.isEmpty {
            return "User's Calendar: No upcoming events for the next 7 days."
        }
        
        // 4. Format events into text
        var context = "User's Calendar (Next 7 Days):\n"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMM d 'at' HH:mm" // e.g., Monday, Nov 20 at 14:30
        
        for event in events {
            let dateStr = dateFormatter.string(from: event.startDate)
            context += "- [\(dateStr)]: \(event.title ?? "Unknown Event")\n"
        }
        context += "[EVENT] Time: 2026-01-17 (Saturday) 10:00 | Title: VİZE TOPLANTISI (TEST)\n"
        return context
    }
    
    // MARK: - Permission Helpers
    
    @available(iOS 17.0, *)
    private func requestAccessiOS17() async -> Bool {
        return await withCheckedContinuation { continuation in
            eventStore.requestFullAccessToEvents { granted, error in
                continuation.resume(returning: granted)
            }
        }
    }
    
    private func requestAccessLegacy() async -> Bool {
        return await withCheckedContinuation { continuation in
            eventStore.requestAccess(to: .event) { granted, error in
                continuation.resume(returning: granted)
            }
        }
    }
}
