import SwiftUI

struct HomeView: View {
    @ObservedObject var engine: ModelEngine
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // MARK: - Hero Icon (Calendar & Privacy Focus)
            ZStack {
                // Background Glow
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [.indigo, .purple, .blue, .indigo],
                            center: .center
                        )
                        .opacity(0.15)
                    )
                    .frame(width: 200, height: 200)
                    .blur(radius: 20)
                
                // Main Icon: Calendar + Lock (Private Schedule)
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 90))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(
                        LinearGradient(colors: [.indigo, .blue], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: .indigo.opacity(0.4), radius: 10, x: 0, y: 10)
            }
            .padding(.bottom, 10)
            
            // MARK: - Branding & Value Prop
            VStack(spacing: 16) {
                Text("Local Agenda")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                
                VStack(spacing: 8) {
                    Text("Your Schedule. Your Device.")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Text("An offline AI agent dedicated to managing your time securely. No cloud, no leaks.")
                        .multilineTextAlignment(.center)
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: 300)
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // MARK: - Action Button
            VStack(spacing: 20) {
                switch engine.state {
                case .idle, .error:
                    Button {
                        Task { await engine.startLoading() }
                    } label: {
                        HStack {
                            Image(systemName: engine.isModelDownloaded ? "lock.open.fill" : "arrow.down.circle.fill")
                            Text(engine.isModelDownloaded ? "Access Secure Agent" : "Initialize System")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.indigo)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .shadow(radius: 5)
                    }
                    
                    if case .error(let msg) = engine.state {
                        Text("Error: \(msg)")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                    
                case .downloading(let progress):
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Downloading AI Model...")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(progress * 100))%")
                                .font(.caption.monospacedDigit())
                        }
                        ProgressView(value: progress)
                            .tint(.indigo)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                case .loading:
                    HStack(spacing: 15) {
                        ProgressView()
                        Text("Reading Local Calendar...")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                    }
                    
                case .ready:
                    NavigationLink(destination: ChatView(engine: engine)) {
                        HStack {
                            Image(systemName: "text.bubble.fill")
                            Text("Open Agent")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .shadow(radius: 5)
                    }
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 50)
        }
    }
}
