// CropZoomView.swift
// A small crop-and-zoom step shown after a photo is picked, so the user can frame
// it themselves before saving. Pinch to zoom, drag to reposition inside a circular
// window, then "Use Photo". Outputs a SQUARE UIImage (callers display it in a
// Circle — profile + couple photos).
//
// Why custom (not UIImagePickerController's allowsEditing): that older path needs
// Photo Library permission, whereas the rest of the app uses PhotosPicker (PHPicker)
// which needs NONE. So we keep PhotosPicker for selection and only add this crop
// step. No third-party dependency — standard SwiftUI gestures + a UIGraphicsImage-
// Renderer that re-uses the exact on-screen geometry to produce the crop.

import SwiftUI

/// Wraps a UIImage so it can drive a `.fullScreenCover(item:)`.
struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct CropZoomView: View {

    let image: UIImage
    let onCancel: () -> Void
    let onCrop: (UIImage) -> Void

    // Pinch/drag state, with a committed baseline so each gesture is relative.
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    // Output edge length in pixels — high enough for any avatar; callers downscale
    // to their own budget afterwards.
    private let output: CGFloat = 1024

    var body: some View {
        GeometryReader { geo in
            // Square crop window, centered, with a small margin.
            let cropSize = min(geo.size.width, geo.size.height) - 40
            let base = baseSize(cropSize: cropSize)   // aspect-fill the square at scale 1
            let dispW = base.width * scale
            let dispH = base.height * scale

            ZStack {
                Color.black.ignoresSafeArea()

                // The image is centered in the ZStack, then offset — so its centre
                // sits at (container centre + offset). Framed to dispW×dispH, which
                // preserves the image aspect (base is aspect-correct), so no stretch.
                Image(uiImage: image)
                    .resizable()
                    .frame(width: dispW, height: dispH)
                    .offset(offset)
                    .gesture(dragGesture(cropSize: cropSize, base: base))
                    .simultaneousGesture(magnifyGesture(cropSize: cropSize, base: base))

                // Dim everything outside the circular crop window.
                Color.black.opacity(0.55)
                    .mask {
                        Rectangle()
                            .overlay {
                                Circle()
                                    .frame(width: cropSize, height: cropSize)
                                    .blendMode(.destinationOut)
                            }
                            .compositingGroup()
                    }
                    .allowsHitTesting(false)
                    .ignoresSafeArea()

                Circle()
                    .strokeBorder(.white.opacity(0.9), lineWidth: 2)
                    .frame(width: cropSize, height: cropSize)
                    .allowsHitTesting(false)

                controls(cropSize: cropSize, base: base)
            }
        }
    }

    // MARK: - Controls

    private func controls(cropSize: CGFloat, base: CGSize) -> some View {
        VStack {
            HStack {
                Button("Cancel") { onCancel() }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
            }

            Spacer()

            Text("Pinch to zoom · drag to reposition")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.bottom, 12)

            Button {
                onCrop(cropped(cropSize: cropSize, base: base))
            } label: {
                Text("Use Photo")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(LouvGradient.coral)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(20)
    }

    // MARK: - Gestures

    private func dragGesture(cropSize: CGFloat, base: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let proposed = CGSize(width: lastOffset.width + value.translation.width,
                                      height: lastOffset.height + value.translation.height)
                offset = clamp(proposed, scale: scale, cropSize: cropSize, base: base)
            }
            .onEnded { _ in lastOffset = offset }
    }

    private func magnifyGesture(cropSize: CGFloat, base: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = max(1, lastScale * value.magnification)
                offset = clamp(offset, scale: scale, cropSize: cropSize, base: base)
            }
            .onEnded { _ in lastScale = scale }
    }

    // MARK: - Geometry

    // Aspect-fill the crop square: the image's smaller side maps to cropSize, the
    // larger overflows (so the square is always fully covered, no gaps).
    private func baseSize(cropSize: CGFloat) -> CGSize {
        let w = image.size.width, h = image.size.height
        guard w > 0, h > 0 else { return CGSize(width: cropSize, height: cropSize) }
        let aspect = w / h
        return aspect >= 1
            ? CGSize(width: cropSize * aspect, height: cropSize)   // landscape
            : CGSize(width: cropSize, height: cropSize / aspect)   // portrait
    }

    // Keep the image covering the crop square (no empty corners).
    private func clamp(_ proposed: CGSize, scale: CGFloat, cropSize: CGFloat, base: CGSize) -> CGSize {
        let dispW = base.width * scale
        let dispH = base.height * scale
        let maxX = max(0, (dispW - cropSize) / 2)
        let maxY = max(0, (dispH - cropSize) / 2)
        return CGSize(width: min(max(proposed.width, -maxX), maxX),
                      height: min(max(proposed.height, -maxY), maxY))
    }

    // Render the crop by re-using the SAME geometry as the on-screen layout: map
    // the crop-square's top-left to (0,0) of an output×output canvas. Whatever sits
    // under the circle (we crop to its bounding square) becomes the result.
    private func cropped(cropSize: CGFloat, base: CGSize) -> UIImage {
        let dispW = base.width * scale
        let dispH = base.height * scale
        let k = output / cropSize
        // Image top-left relative to the crop square's top-left, in view points…
        let relX = (cropSize - dispW) / 2 + offset.width
        let relY = (cropSize - dispH) / 2 + offset.height
        // …scaled into output-pixel space.
        let rect = CGRect(x: relX * k, y: relY * k, width: dispW * k, height: dispH * k)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1        // rect is already in pixels
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: output, height: output), format: format)
        return renderer.image { _ in
            image.draw(in: rect)
        }
    }
}
