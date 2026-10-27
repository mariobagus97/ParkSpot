import SwiftUI

@main
struct ParkSpotApp: App {
    var body: some Scene {
        WindowGroup {
            Text("hello")
                .font(.largeTitle.bold())
                .foregroundStyle(Theme.text1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.bg)
                .preferredColorScheme(.dark)
        }
    }
}
