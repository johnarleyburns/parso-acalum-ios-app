import SwiftUI

@main
struct AcalumApp: App {
    var body: some Scene {
        WindowGroup {
            PlayerHomeView(viewModel: PlayerViewModel())
        }
    }
}
