import SwiftUI
import UIKit

struct MarkedSelectionEditorView: View {
    let images: [UIImage]
    let onCancel: () -> Void
    let onComplete: ([MarkedScanSelection], Int) -> Void

    @State private var currentPage = 0
    @State private var brushWidth: CGFloat = 6
    @State private var strokesByPage: [[SelectionStroke]]
    @State private var contentVisible = false

    init(
        images: [UIImage],
        onCancel: @escaping () -> Void,
        onComplete: @escaping ([MarkedScanSelection], Int) -> Void
    ) {
        self.images = images
        self.onCancel = onCancel
        self.onComplete = onComplete
        _strokesByPage = State(initialValue: Array(repeating: [], count: images.count))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                PlayfulBackground()

                VStack(spacing: 10) {
                    topBar
                        .opacity(contentVisible ? 1 : 0)
                        .offset(y: contentVisible ? 0 : 16)
                    editorPanel
                        .opacity(contentVisible ? 1 : 0)
                        .offset(y: contentVisible ? 0 : 22)
                    toolbar
                        .opacity(contentVisible ? 1 : 0)
                        .offset(y: contentVisible ? 0 : 24)
                }
                .padding(.horizontal, 14)
                .padding(.top, max(proxy.safeAreaInsets.top, 22) + 10)
                .padding(.bottom, max(proxy.safeAreaInsets.bottom, 12))
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            guard !contentVisible else { return }
            withAnimation(AppStyle.softSpring.delay(0.04)) {
                contentVisible = true
            }
        }
        .animation(AppStyle.softSpring, value: currentPage)
    }
}

private extension MarkedSelectionEditorView {
    var topBar: some View {
        HStack(spacing: 10) {
            Button(action: onCancel) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppColors.primaryText)
                    .frame(width: 48, height: 48)
                    .background(AppColors.background)
                    .clipShape(Circle())
            }

            VStack(spacing: 2) {
                Text("选择单词")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppColors.primaryText)

                Text("第 \(currentPage + 1) / \(images.count) 页")
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryText)
            }
            .frame(maxWidth: .infinity)

            Button(action: finishSelection) {
                Text("完成")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(canFinish ? AppColors.primary : AppColors.secondaryText)
                    .frame(height: 48)
                    .padding(.horizontal, 20)
                    .background(AppColors.background)
                    .clipShape(Capsule())
            }
            .disabled(!canFinish)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppColors.elevatedCard)
        .overlay(
            RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous)
                .stroke(AppColors.cardStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous))
        .shadow(color: AppStyle.cardShadow, radius: 10, y: 6)
    }

    var editorPanel: some View {
        GeometryReader { _ in
            ZStack {
                RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous)
                    .fill(AppColors.elevatedCard)
                    .shadow(color: AppStyle.cardShadow, radius: 16, y: 8)

                SelectionCanvasView(
                    image: images[currentPage],
                    strokes: pageStrokesBinding,
                    brushWidth: brushWidth
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: AppStyle.cornerRadius - 2, style: .continuous))
                .padding(6)
            }
        }
    }

    var toolbar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Button {
                    guard !strokesByPage[currentPage].isEmpty else { return }
                    strokesByPage[currentPage].removeLast()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(strokesByPage[currentPage].isEmpty ? AppColors.secondaryText : AppColors.primary)
                        .frame(width: 40, height: 40)
                        .background((strokesByPage[currentPage].isEmpty ? AppColors.background : AppColors.primary).opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(strokesByPage[currentPage].isEmpty)

                Button {
                    strokesByPage[currentPage] = []
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppColors.danger)
                        .frame(width: 40, height: 40)
                        .background(AppColors.danger.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                HStack(spacing: 6) {
                    Button {
                        currentPage = max(0, currentPage - 1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(SecondaryCapsuleButtonStyle())
                    .disabled(currentPage == 0)

                    Text("\(currentPage + 1) / \(images.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.secondaryText)
                        .frame(minWidth: 48)

                    Button {
                        currentPage = min(images.count - 1, currentPage + 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(SecondaryCapsuleButtonStyle())
                    .disabled(currentPage == images.count - 1)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            HStack(spacing: 8) {
                Image(systemName: "circle.lefthalf.filled")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColors.secondaryText)

                Slider(value: $brushWidth, in: 3...22, step: 1)
                    .tint(AppColors.primary)

                Text("\(Int(brushWidth))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.secondaryText)
                    .frame(width: 24)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(AppColors.background)
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppColors.elevatedCard)
        .overlay(
            RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous)
                .stroke(AppColors.cardStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous))
        .shadow(color: AppStyle.cardShadow, radius: 10, y: 6)
    }

    var pageStrokesBinding: Binding<[SelectionStroke]> {
        Binding(
            get: { strokesByPage[currentPage] },
            set: { strokesByPage[currentPage] = $0 }
        )
    }

    var canFinish: Bool {
        strokesByPage.contains { !$0.isEmpty }
    }

    func finishSelection() {
        let selections = images.enumerated().compactMap { index, image -> MarkedScanSelection? in
            guard let maskImage = SelectionMaskRenderer.makeMaskImage(
                strokes: strokesByPage[index],
                imageSize: image.size
            ) else {
                return nil
            }

            return MarkedScanSelection(
                image: image,
                selectionMask: maskImage,
                normalizedRegions: SelectionMaskRenderer.makeNormalizedRegions(strokes: strokesByPage[index])
            )
        }

        onComplete(selections, images.count)
    }
}

private struct SelectionStroke: Equatable {
    let normalizedWidth: CGFloat
    let points: [CGPoint]
}

private struct SelectionCanvasView: UIViewRepresentable {
    let image: UIImage
    @Binding var strokes: [SelectionStroke]
    let brushWidth: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> SelectionCanvasContainerView {
        let view = SelectionCanvasContainerView()
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ uiView: SelectionCanvasContainerView, context: Context) {
        context.coordinator.parent = self
        uiView.update(
            image: image,
            strokes: strokes,
            brushWidth: brushWidth
        )
    }

    final class Coordinator: NSObject, SelectionCanvasContainerViewDelegate {
        var parent: SelectionCanvasView

        init(parent: SelectionCanvasView) {
            self.parent = parent
        }

        func selectionCanvas(_ canvas: SelectionCanvasContainerView, didChangeStrokes strokes: [SelectionStroke]) {
            parent.strokes = strokes
        }
    }
}

private protocol SelectionCanvasContainerViewDelegate: AnyObject {
    func selectionCanvas(_ canvas: SelectionCanvasContainerView, didChangeStrokes strokes: [SelectionStroke])
}

private final class SelectionCanvasContainerView: UIView, SelectionOverlayViewDelegate {
    weak var delegate: SelectionCanvasContainerViewDelegate?

    private let imageView = UIImageView()
    private let overlayView = SelectionOverlayView()

    private var currentImageSize: CGSize = .zero
    private var currentStrokes: [SelectionStroke] = []
    private var currentBrushWidth: CGFloat = 24

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func update(image: UIImage, strokes: [SelectionStroke], brushWidth: CGFloat) {
        imageView.image = image
        currentImageSize = image.size
        currentBrushWidth = brushWidth
        currentStrokes = strokes
        overlayView.strokes = strokes
        overlayView.brushWidth = brushWidth
        setNeedsLayout()
        layoutIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutContent(in: bounds)
    }

    func selectionOverlayView(_ overlayView: SelectionOverlayView, didChangeStrokes strokes: [SelectionStroke]) {
        currentStrokes = strokes
        delegate?.selectionCanvas(self, didChangeStrokes: strokes)
    }

    private func setup() {
        backgroundColor = .clear

        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        addSubview(imageView)

        overlayView.backgroundColor = .clear
        overlayView.delegate = self
        addSubview(overlayView)
    }

    private func layoutContent(in containerBounds: CGRect) {
        guard containerBounds.width > 0, containerBounds.height > 0, currentImageSize.width > 0, currentImageSize.height > 0 else {
            return
        }

        let fittedSize = aspectFitSize(for: currentImageSize, in: containerBounds.size)
        let origin = CGPoint(
            x: (containerBounds.width - fittedSize.width) / 2,
            y: (containerBounds.height - fittedSize.height) / 2
        )
        let fittedFrame = CGRect(origin: origin, size: fittedSize)

        imageView.frame = fittedFrame
        overlayView.frame = fittedFrame
        overlayView.imageSize = currentImageSize
        overlayView.brushWidth = currentBrushWidth
        overlayView.strokes = currentStrokes
    }

    private func aspectFitSize(for imageSize: CGSize, in containerSize: CGSize) -> CGSize {
        let widthScale = containerSize.width / imageSize.width
        let heightScale = containerSize.height / imageSize.height
        let scale = min(widthScale, heightScale)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }
}

private protocol SelectionOverlayViewDelegate: AnyObject {
    func selectionOverlayView(_ overlayView: SelectionOverlayView, didChangeStrokes strokes: [SelectionStroke])
}

private final class SelectionOverlayView: UIView {
    weak var delegate: SelectionOverlayViewDelegate?

    var imageSize: CGSize = .zero {
        didSet {
            invalidateCommittedImage()
            setNeedsDisplay()
        }
    }

    var brushWidth: CGFloat = 18

    var strokes: [SelectionStroke] = [] {
        didSet {
            invalidateCommittedImage()
            setNeedsDisplay()
        }
    }

    var isDrawingEnabled = true {
        didSet {
            drawGesture.isEnabled = isDrawingEnabled
            tapGesture.isEnabled = isDrawingEnabled
        }
    }

    private var currentPoints: [CGPoint] = []
    private var committedImage: UIImage?
    private var committedImageCanvasSize: CGSize = .zero
    private lazy var drawGesture: UIPanGestureRecognizer = {
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(handleDrawPan(_:)))
        gesture.minimumNumberOfTouches = 1
        gesture.maximumNumberOfTouches = 1
        gesture.cancelsTouchesInView = true
        return gesture
    }()

    private lazy var tapGesture: UITapGestureRecognizer = {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        gesture.numberOfTouchesRequired = 1
        return gesture
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        isMultipleTouchEnabled = true
        backgroundColor = .clear
        isOpaque = false
        addGestureRecognizer(drawGesture)
        addGestureRecognizer(tapGesture)
        tapGesture.require(toFail: drawGesture)
        drawGesture.isEnabled = isDrawingEnabled
        tapGesture.isEnabled = isDrawingEnabled
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if committedImageCanvasSize != bounds.size {
            invalidateCommittedImage()
        }
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.setLineCap(.round)
        context.setLineJoin(.round)

        if committedImage == nil {
            committedImage = renderCommittedImage()
        }

        committedImage?.draw(in: bounds)

        if !currentPoints.isEmpty {
            let previewStroke = SelectionStroke(
                normalizedWidth: max(0.01, brushWidth / max(min(bounds.width, bounds.height), 1)),
                points: currentPoints
            )
            UIColor(AppColors.primary).withAlphaComponent(0.48).setStroke()
            draw(stroke: previewStroke, in: context, canvasSize: bounds.size)
        }
    }

    @objc
    private func handleDrawPan(_ gesture: UIPanGestureRecognizer) {
        let point = gesture.location(in: self)
        let normalized = normalizedPoint(for: point)

        switch gesture.state {
        case .began:
            currentPoints = [normalized]
            setNeedsDisplay()
        case .changed:
            guard currentPoints.last != normalized else { return }
            appendInterpolatedPoints(to: normalized)
            setNeedsDisplay()
        case .ended:
            finishStroke(with: point)
        case .cancelled, .failed:
            currentPoints = []
            setNeedsDisplay()
        default:
            break
        }
    }

    @objc
    private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        let point = gesture.location(in: self)
        currentPoints = [normalizedPoint(for: point)]
        finishStroke(with: point)
    }

    private func finishStroke(with point: CGPoint?) {
        if let point {
            let normalized = normalizedPoint(for: point)
            if currentPoints.last != normalized {
                appendInterpolatedPoints(to: normalized)
            }
        }

        guard !currentPoints.isEmpty else { return }

        let stroke = SelectionStroke(
            normalizedWidth: max(0.01, brushWidth / max(min(bounds.width, bounds.height), 1)),
            points: currentPoints
        )

        strokes.append(stroke)
        currentPoints = []
        delegate?.selectionOverlayView(self, didChangeStrokes: strokes)
    }

    private func invalidateCommittedImage() {
        committedImage = nil
        committedImageCanvasSize = .zero
    }

    private func renderCommittedImage() -> UIImage? {
        guard !strokes.isEmpty, bounds.width > 0, bounds.height > 0 else {
            committedImageCanvasSize = bounds.size
            return nil
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: bounds.size, format: format)
        let image = renderer.image { _ in
            guard let context = UIGraphicsGetCurrentContext() else { return }
            context.setLineCap(.round)
            context.setLineJoin(.round)
            UIColor(AppColors.primary).withAlphaComponent(0.36).setStroke()

            for stroke in strokes {
                draw(stroke: stroke, in: context, canvasSize: bounds.size)
            }
        }
        committedImageCanvasSize = bounds.size
        return image
    }

    private func draw(stroke: SelectionStroke, in context: CGContext, canvasSize: CGSize) {
        let points = stroke.points.map { point in
            CGPoint(x: point.x * canvasSize.width, y: point.y * canvasSize.height)
        }
        guard let first = points.first else { return }

        let lineWidth = max(1.0, stroke.normalizedWidth * min(canvasSize.width, canvasSize.height))
        context.setLineWidth(lineWidth)

        if points.count == 1 {
            let radius = lineWidth / 2
            context.strokeEllipse(in: CGRect(
                x: first.x - radius,
                y: first.y - radius,
                width: radius * 2,
                height: radius * 2
            ))
            return
        }

        context.beginPath()
        context.move(to: first)
        for point in points.dropFirst() {
            context.addLine(to: point)
        }
        context.strokePath()
    }

    private func normalizedPoint(for point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x / max(bounds.width, 1), 0), 1),
            y: min(max(point.y / max(bounds.height, 1), 0), 1)
        )
    }

    private func appendInterpolatedPoints(to point: CGPoint) {
        guard let last = currentPoints.last else {
            currentPoints = [point]
            return
        }

        let dx = point.x - last.x
        let dy = point.y - last.y
        let distance = hypot(dx * bounds.width, dy * bounds.height)
        let stepLength = max(1.6, brushWidth * 0.3)
        let stepCount = max(1, Int(ceil(distance / stepLength)))

        guard stepCount > 1 else {
            currentPoints.append(point)
            return
        }

        for step in 1...stepCount {
            let progress = CGFloat(step) / CGFloat(stepCount)
            currentPoints.append(
                CGPoint(
                    x: last.x + dx * progress,
                    y: last.y + dy * progress
                )
            )
        }
    }
}

private enum SelectionMaskRenderer {
    static func hasSelection(strokes: [SelectionStroke], imageSize: CGSize) -> Bool {
        makeMaskImage(strokes: strokes, imageSize: imageSize) != nil
    }

    static func makeMaskImage(strokes: [SelectionStroke], imageSize: CGSize) -> UIImage? {
        guard imageSize.width > 0, imageSize.height > 0 else { return nil }
        guard !strokes.isEmpty else { return nil }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        let size = CGSize(width: max(1, imageSize.width), height: max(1, imageSize.height))

        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.clear.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            for stroke in strokes {
                let points = stroke.points.map { point in
                    CGPoint(x: point.x * size.width, y: point.y * size.height)
                }
                guard let first = points.first else { continue }

                let path = UIBezierPath()
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                    path.lineWidth = max(1.0, stroke.normalizedWidth * min(size.width, size.height))

                if points.count == 1 {
                    let radius = path.lineWidth / 2
                    path.append(UIBezierPath(ovalIn: CGRect(
                        x: first.x - radius,
                        y: first.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )))
                } else {
                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }

                UIColor.white.setStroke()
                UIColor.white.setFill()
                path.stroke()
                path.fill()
            }
        }

        guard let cgImage = image.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width * 4
        var pixels = Array(repeating: UInt8(0), count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let hasOpaquePixel = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 20 }
        return hasOpaquePixel ? image : nil
    }

    static func makeNormalizedRegions(strokes: [SelectionStroke]) -> [CGRect] {
        let rects = strokes.compactMap { stroke -> CGRect? in
            guard !stroke.points.isEmpty else { return nil }

            let minX = stroke.points.map(\.x).min() ?? 0
            let maxX = stroke.points.map(\.x).max() ?? 0
            let minY = stroke.points.map(\.y).min() ?? 0
            let maxY = stroke.points.map(\.y).max() ?? 0
            let expansion = max(stroke.normalizedWidth * 0.72, 0.012)

            let rect = CGRect(
                x: max(0, minX - expansion),
                y: max(0, minY - expansion),
                width: min(1, maxX + expansion) - max(0, minX - expansion),
                height: min(1, maxY + expansion) - max(0, minY - expansion)
            )

            guard rect.width > 0, rect.height > 0 else { return nil }
            return rect
        }

        guard !rects.isEmpty else { return [] }
        return mergeNearbyNormalizedRects(rects)
    }

    private static func mergeNearbyNormalizedRects(_ rects: [CGRect]) -> [CGRect] {
        var merged: [CGRect] = []

        for rect in rects.sorted(by: { lhs, rhs in
            if lhs.minY == rhs.minY {
                return lhs.minX < rhs.minX
            }
            return lhs.minY < rhs.minY
        }) {
            if let index = merged.firstIndex(where: { existing in
                existing.insetBy(dx: -0.02, dy: -0.02).intersects(rect)
            }) {
                merged[index] = merged[index].union(rect)
            } else {
                merged.append(rect)
            }
        }

        return merged
    }
}

private struct SecondaryCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(AppColors.primaryText)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(AppColors.background.opacity(configuration.isPressed ? 0.65 : 1))
            .clipShape(Capsule())
    }
}
