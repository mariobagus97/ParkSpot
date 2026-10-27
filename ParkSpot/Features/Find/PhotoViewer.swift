import SwiftUI

/// The spot photo full screen: pinch to zoom up to 4×, double tap to jump between 1× and 2×.
struct PhotoViewer: View {
    let photos: PhotoStoring
    let fileName: String
    let onClose: () -> Void

    @State private var scale = 1.0
    @State private var lastScale = 1.0
    @State private var image: UIImage?

    private static let maxScale = 4.0

    var body: some View {
        ZStack(alignment: .topLeading) {
            Theme.black.ignoresSafeArea()

            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .gesture(
                            MagnifyGesture()
                                .onChanged { value in
                                    scale = min(max(lastScale * value.magnification, 1), Self.maxScale)
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.easeOut(duration: 0.2)) {
                                scale = scale > 1 ? 1 : 2
                                lastScale = scale
                            }
                        }
                        .accessibilityLabel(Text("your_car"))
                } else {
                    CoverArt(photos: photos, fileName: fileName, tint: nil, cornerRadius: 0)
                        .padding(.horizontal, 16)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            CircleIconButton(systemImage: "xmark", labelKey: "close", filled: true, action: onClose)
                .padding(12)
        }
        .task(id: fileName) {
            image = photos.image(named: fileName)
        }
    }
}
