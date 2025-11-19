import SwiftUI

// struct ContentView can be used as the root view.

struct ContentView: View {
    @StateObject var engine = ModelEngine()
    
    var body: some View {
        NavigationStack {
            HomeView(engine: engine)
        }
        .preferredColorScheme(.dark)
    }
}
