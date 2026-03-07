import SwiftUI

enum DrawingTool {
    case pen, arrow, circle, eraser
}

struct FieldCanvasView: View {
    @Binding var elements: [DrawingElement]
    @Binding var currentTool: DrawingTool
    @Binding var currentColor: String
    let isHorizontal: Bool

    @State private var currentStrokePoints: [CGPoint] = []
    @State private var arrowStart: CGPoint?
    @State private var undoStack: [[DrawingElement]] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                FieldBackground(isHorizontal: isHorizontal)

                Canvas { context, size in
                    for element in elements {
                        draw(element, in: &context, size: size)
                    }
                    if !currentStrokePoints.isEmpty {
                        let stroke = DrawingElement.stroke(points: currentStrokePoints, color: currentColor, lineWidth: 3)
                        draw(stroke, in: &context, size: size)
                    }
                }
                .gesture(drawingGesture(in: geo.size))
            }
        }
    }

    private func draw(_ element: DrawingElement, in context: inout GraphicsContext, size: CGSize) {
        switch element {
        case .stroke(let points, let color, let lineWidth):
            guard points.count > 1 else { return }
            var path = Path()
            path.move(to: points[0])
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            context.stroke(path, with: .color(Color(namedColor: color)), lineWidth: lineWidth)

        case .arrow(let from, let to, let color):
            var path = Path()
            path.move(to: from)
            path.addLine(to: to)
            let angle = atan2(to.y - from.y, to.x - from.x)
            let headLength: CGFloat = 15
            let head1 = CGPoint(
                x: to.x - headLength * cos(angle - .pi / 6),
                y: to.y - headLength * sin(angle - .pi / 6)
            )
            let head2 = CGPoint(
                x: to.x - headLength * cos(angle + .pi / 6),
                y: to.y - headLength * sin(angle + .pi / 6)
            )
            path.move(to: to)
            path.addLine(to: head1)
            path.move(to: to)
            path.addLine(to: head2)
            context.stroke(path, with: .color(Color(namedColor: color)), lineWidth: 3)

        case .circle(let center, let color):
            let radius: CGFloat = 12
            let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(Color(namedColor: color)))
        }
    }

    private func drawingGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let point = value.location
                switch currentTool {
                case .pen:
                    currentStrokePoints.append(point)
                case .arrow:
                    if arrowStart == nil {
                        arrowStart = point
                    }
                case .circle:
                    break
                case .eraser:
                    currentStrokePoints.append(point)
                }
            }
            .onEnded { value in
                let point = value.location
                switch currentTool {
                case .pen:
                    if currentStrokePoints.count > 1 {
                        saveUndo()
                        elements.append(.stroke(points: currentStrokePoints, color: currentColor, lineWidth: 3))
                    }
                    currentStrokePoints = []
                case .arrow:
                    if let start = arrowStart {
                        saveUndo()
                        elements.append(.arrow(from: start, to: point, color: currentColor))
                    }
                    arrowStart = nil
                case .circle:
                    saveUndo()
                    elements.append(.circle(center: point, color: currentColor))
                case .eraser:
                    saveUndo()
                    removeIntersecting(with: currentStrokePoints)
                    currentStrokePoints = []
                }
            }
    }

    private func removeIntersecting(with eraserPoints: [CGPoint]) {
        let threshold: CGFloat = 20
        elements.removeAll { element in
            switch element {
            case .stroke(let points, _, _):
                return points.contains { sp in
                    eraserPoints.contains { ep in
                        hypot(sp.x - ep.x, sp.y - ep.y) < threshold
                    }
                }
            case .arrow(let from, let to, _):
                return eraserPoints.contains { ep in
                    hypot(from.x - ep.x, from.y - ep.y) < threshold ||
                    hypot(to.x - ep.x, to.y - ep.y) < threshold
                }
            case .circle(let center, _):
                return eraserPoints.contains { ep in
                    hypot(center.x - ep.x, center.y - ep.y) < threshold
                }
            }
        }
    }

    func undo() {
        if let previous = undoStack.popLast() {
            elements = previous
        }
    }

    private func saveUndo() {
        undoStack.append(elements)
    }
}

struct FieldBackground: View {
    let isHorizontal: Bool

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let endZoneDepth: CGFloat = isHorizontal ? w * 0.15 : h * 0.15

            Canvas { context, size in
                let fieldRect = CGRect(origin: .zero, size: size)
                context.fill(Path(fieldRect), with: .color(.green.opacity(0.3)))

                if isHorizontal {
                    let leftEZ = CGRect(x: 0, y: 0, width: endZoneDepth, height: h)
                    let rightEZ = CGRect(x: w - endZoneDepth, y: 0, width: endZoneDepth, height: h)
                    context.fill(Path(leftEZ), with: .color(.green.opacity(0.5)))
                    context.fill(Path(rightEZ), with: .color(.green.opacity(0.5)))
                    var left = Path(); left.move(to: CGPoint(x: endZoneDepth, y: 0)); left.addLine(to: CGPoint(x: endZoneDepth, y: h))
                    var right = Path(); right.move(to: CGPoint(x: w - endZoneDepth, y: 0)); right.addLine(to: CGPoint(x: w - endZoneDepth, y: h))
                    var mid = Path(); mid.move(to: CGPoint(x: w / 2, y: 0)); mid.addLine(to: CGPoint(x: w / 2, y: h))
                    context.stroke(left, with: .color(.white.opacity(0.6)), lineWidth: 2)
                    context.stroke(right, with: .color(.white.opacity(0.6)), lineWidth: 2)
                    context.stroke(mid, with: .color(.white.opacity(0.3)), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                } else {
                    let topEZ = CGRect(x: 0, y: 0, width: w, height: endZoneDepth)
                    let bottomEZ = CGRect(x: 0, y: h - endZoneDepth, width: w, height: endZoneDepth)
                    context.fill(Path(topEZ), with: .color(.green.opacity(0.5)))
                    context.fill(Path(bottomEZ), with: .color(.green.opacity(0.5)))
                    var top = Path(); top.move(to: CGPoint(x: 0, y: endZoneDepth)); top.addLine(to: CGPoint(x: w, y: endZoneDepth))
                    var bottom = Path(); bottom.move(to: CGPoint(x: 0, y: h - endZoneDepth)); bottom.addLine(to: CGPoint(x: w, y: h - endZoneDepth))
                    var mid = Path(); mid.move(to: CGPoint(x: 0, y: h / 2)); mid.addLine(to: CGPoint(x: w, y: h / 2))
                    context.stroke(top, with: .color(.white.opacity(0.6)), lineWidth: 2)
                    context.stroke(bottom, with: .color(.white.opacity(0.6)), lineWidth: 2)
                    context.stroke(mid, with: .color(.white.opacity(0.3)), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                }
            }
        }
    }
}

extension Color {
    init(namedColor: String) {
        switch namedColor {
        case "red": self = .red
        case "blue": self = .blue
        case "yellow": self = .yellow
        case "white": self = .white
        case "black": self = .black
        default: self = .white
        }
    }
}
