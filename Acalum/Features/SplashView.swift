import SwiftUI

struct SplashView: View {
    @Binding var isPresented: Bool
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.85

    private let attributionURL = URL(string: "https://commons.wikimedia.org/wiki/File:SAKURAKO_listen_to_music_(46579718321).jpg")!

    var body: some View {
        ZStack(alignment: .bottom) {
            if let _ = UIImage(named: "splash") {
                Image("splash")
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else {
                LinearGradient(
                    colors: [Color.indigo, Color.purple.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            VStack(spacing: 16) {
                Image(systemName: "music.note.house.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.white)
                    .scaleEffect(scale)

                Text("Acalum")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Discover public-domain music")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(maxHeight: .infinity, alignment: .center)

            Link(destination: attributionURL) {
                HStack(spacing: 4) {
                    Image(systemName: "c.circle")
                        .font(.system(size: 10))
                    Text("Photo: MIKI Yoshihito (CC BY 2.0)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                }
                .foregroundStyle(.white.opacity(0.5))
                .padding(.bottom, 12)
            }
        }
        .ignoresSafeArea()
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                opacity = 1
                scale = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    isPresented = false
                }
            }
        }
    }
}
