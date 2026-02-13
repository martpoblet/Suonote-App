import SwiftUI

/// First-launch onboarding flow (U-04)
struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var currentPage = 0
    
    private let pages: [(icon: String, title: String, description: String, color: Color)] = [
        ("music.note.list", "Welcome to Suonote",
         "Your creative companion for songwriting. Capture ideas, build arrangements, and bring your music to life.",
         DesignSystem.Colors.primary),
        ("rectangle.3.group", "Organize with Sections",
         "Structure your songs with Verse, Chorus, Bridge, and more. Drag to arrange, color-code for clarity.",
         DesignSystem.Colors.info),
        ("pianokeys", "Smart Chord Suggestions",
         "Get diatonic chords for any key and mode. Explore Jazz, Blues, Pop patterns — even Roman numeral analysis.",
         DesignSystem.Colors.accent),
        ("waveform", "Record & Produce",
         "Record audio ideas, generate studio arrangements with drums, bass, keys, and strings. Export as MIDI or PDF.",
         DesignSystem.Colors.success),
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    VStack(spacing: 24) {
                        Spacer()
                        
                        Image(systemName: page.icon)
                            .font(.system(size: 72))
                            .foregroundStyle(page.color)
                            .symbolEffect(.bounce, value: currentPage == index)
                        
                        Text(page.title)
                            .font(.title.bold())
                            .multilineTextAlignment(.center)
                        
                        Text(page.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Spacer()
                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            
            // Bottom button
            Button(action: {
                if currentPage < pages.count - 1 {
                    withAnimation { currentPage += 1 }
                } else {
                    onComplete()
                }
            }) {
                Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(DesignSystem.Colors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            
            if currentPage < pages.count - 1 {
                Button("Skip") {
                    onComplete()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 24)
            } else {
                Spacer().frame(height: 48)
            }
        }
    }
}
