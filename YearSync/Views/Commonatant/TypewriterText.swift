import SwiftUI

struct TypewriterText: View {
    let text: String
    @State private var displayedText = ""
    @State private var isAnimating = false
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        Text(displayedText)
            .font(.custom("PlayfairDisplay-Regular", size: 17))
            .onAppear {
                withAnimation(.linear(duration: 0.8)) {
                    animateText()
                }
            }
    }
    
    private func animateText() {
        guard !isAnimating else { return }
        isAnimating = true
        displayedText = ""
        
        let interval = 0.02  // Faster interval
        let characters = Array(text)
        
        // Use Timer for smoother animation
        var index = 0
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            if index < characters.count {
                displayedText += String(characters[index])
                index += 1
            } else {
                timer.invalidate()
                isAnimating = false
            }
        }
    }
} 