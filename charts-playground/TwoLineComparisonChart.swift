import SwiftUI
import Charts

/// A two-line comparison chart that fills the band between lines and supports interactive snapping.
public struct TwoLineComparisonChart: View {
    public var data: [PairedPoint]

    @State private var selectedX: Int? = nil
    @State private var dragLocation: CGPoint? = nil // overlay (GeometryReader) coordinates

    public init(data: [PairedPoint]) {
        self.data = data
    }

    private var sorted: [PairedPoint] {
        data.sorted { $0.x < $1.x }
    }

    // Precomputed contiguous segments of the area between the two lines,
    // split exactly at intersections so color can switch cleanly.
    private var segments: [Segment] {
        makeSegments(from: sorted)
    }

    public var body: some View {
        let sortedData = sorted
        let segs = segments
        let cutoffX = selectedX.map(Double.init)
        let trimmed = trimmedSegments(from: segs, cutoffX: cutoffX)

        return Chart {
            // Series 1 line
            ForEach(sortedData, id: \.x) { point in
                LineMark(
                    x: .value("X", Double(point.x)),
                    y: .value("Value", point.y1)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(by: .value("Series", "First"))
            }

            // Series 2 line
            ForEach(sortedData, id: \.x) { point in
                LineMark(
                    x: .value("X", Double(point.x)),
                    y: .value("Value", point.y2)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(by: .value("Series", "Second"))
            }

            // Points highlighting when selected
            if let sx = selectedX, let sel = sortedData.first(where: { $0.x == sx }) {
                PointMark(x: .value("X", Double(sel.x)), y: .value("Series 1", sel.y1))
                    .symbolSize(80)
                    .foregroundStyle(sel.isFirstAbove ? .green : .red)
                PointMark(x: .value("X", Double(sel.x)), y: .value("Series 2", sel.y2))
                    .symbolSize(80)
                    .foregroundStyle(sel.isFirstAbove ? .green : .red)
            }

            // Band fill between the two lines, split at intersections with color per segment
            ForEach(trimmed) { segment in
                ForEach(segment.points) { p in
                    AreaMark(
                        x: .value("X", p.x),
                        yStart: .value("Low", min(p.y1, p.y2)),
                        yEnd: .value("High", max(p.y1, p.y2)),
                        series: .value("Segment", segment.id.uuidString)
                    )
                    .interpolationMethod(.catmullRom)
                    // Area is RED when first > second, GREEN when first < second
                    .foregroundStyle(segment.isFirstAbove ? Color.green.opacity(0.18) : Color.red.opacity(0.18))
                }
            }
        }
        .chartXAxis { AxisMarks(position: .bottom) }
        .chartYAxis { AxisMarks(position: .leading) }
        .chartOverlay { proxy in
            overlayContent(proxy: proxy, sortedData: sortedData)
        }
        // Removed implicit animation on data; updates will be immediate.
        .chartLegend(position: .top, alignment: .leading)
    }

    @ViewBuilder
    private func overlayContent(proxy: ChartProxy, sortedData: [PairedPoint]) -> some View {
        GeometryReader { geo in
            let plotFrame: CGRect = geo[proxy.plotFrame!]

            // Gesture only within the plot area to avoid accidental selections
            Rectangle()
                .fill(.clear)
                .frame(width: plotFrame.size.width, height: plotFrame.size.height)
                .position(x: plotFrame.midX, y: plotFrame.midY)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            dragLocation = value.location
                            updateSelection(at: value.location, proxy: proxy, plotFrame: plotFrame)
                        }
                        .onEnded { _ in
                            selectedX = nil
                            dragLocation = nil
                        }
                )

            if let sx = selectedX, let sel = sortedData.first(where: { $0.x == sx }) {
                // Convert from plot coordinates to overlay coordinates by adding the plot origin
                let origin = plotFrame.origin

                // Vertical rule snapped to nearest x
                let xPosPlot = proxy.position(forX: Double(sx)) ?? 0
                let xPos = xPosPlot + origin.x

                ZStack(alignment: .topLeading) {
                    // Rule
                    Rectangle()
                        .fill(Color.primary.opacity(0.35))
                        .frame(width: 1)
                        .position(x: xPos, y: geo.size.height / 2)

                    // Difference label positioned near the finger, clamped to edges
                    let diff = sel.diff
                    let diffText = String(format: "%+.1f", diff)
                    let labelBG = diff >= 0 ? Color.green.opacity(0.2) : Color.red.opacity(0.2)
                    let labelFG = diff >= 0 ? Color.green : Color.red

                    let finger = dragLocation ?? CGPoint(x: xPos, y: origin.y + 12)
                    let desired = desiredLabelPosition(near: finger, in: geo.size)
                    let clamped = clamp(desired, in: geo.size, padding: 8)

                    Group {
                        Text(diffText)
                            .font(.caption.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(.white, in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(.black, lineWidth: 1)
                            }
                            .foregroundStyle(labelFG)
                    }
                    .position(x: clamped.x, y: clamped.y)
                    .zIndex(100)

                    // Connector segment between the two series at selected x
                    let y1PosPlot = proxy.position(forY: sel.y1) ?? 0
                    let y2PosPlot = proxy.position(forY: sel.y2) ?? 0
                    let y1Pos = y1PosPlot + origin.y
                    let y2Pos = y2PosPlot + origin.y

                    Path { p in
                        p.move(to: CGPoint(x: xPos, y: y1Pos))
                        p.addLine(to: CGPoint(x: xPos, y: y2Pos))
                    }
                    .stroke(diff >= 0 ? Color.green : Color.red, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .zIndex(0)
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
    }

    // MARK: - Selection
    private func updateSelection(at location: CGPoint, proxy: ChartProxy, plotFrame: CGRect) {
        // Only update when the drag is inside the plot area
        guard plotFrame.contains(location) else {
            selectedX = nil
            return
        }
        // Convert overlay location to plot-area coordinates expected by value(atX:)
        let locationInPlot = CGPoint(x: location.x - plotFrame.origin.x, y: location.y - plotFrame.origin.y)
        if let xVal: Double = proxy.value(atX: locationInPlot.x) {
            if let nearest = sorted.min(by: { abs(Double($0.x) - xVal) < abs(Double($1.x) - xVal) }) {
                selectedX = nearest.x
            }
        } else {
            selectedX = nil
        }
    }

    // MARK: - Label positioning helpers
    private func desiredLabelPosition(near finger: CGPoint, in size: CGSize) -> CGPoint {
        // Prefer above and to the right of the finger; if near top edge, place below instead.
        let xOffset: CGFloat = 14
        let yOffset: CGFloat = 28
        let placeAbove = finger.y > yOffset + 12
        let x = finger.x + xOffset
        let y = placeAbove ? (finger.y - yOffset) : (finger.y + yOffset)
        return CGPoint(x: x, y: y)
    }

    private func clamp(_ point: CGPoint, in size: CGSize, padding: CGFloat) -> CGPoint {
        let x = min(max(point.x, padding), size.width - padding)
        let y = min(max(point.y, padding), size.height - padding)
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Segmented band model and computation
private struct SegmentPoint: Identifiable {
    let id = UUID()
    let x: Double
    let y1: Double
    let y2: Double
}

private struct Segment: Identifiable {
    let id = UUID()
    var points: [SegmentPoint]
    var isFirstAbove: Bool
}

private struct TrimmedSegment: Identifiable {
    let id: UUID
    let isFirstAbove: Bool
    let points: [SegmentPoint]
}

// Trim segments up to the cutoff x. If the cutoff lies inside a segment, interpolate a point at the cutoff
// so the area ends exactly under the selection rule.
private func trimmedSegments(from segments: [Segment], cutoffX: Double?) -> [TrimmedSegment] {
    guard let cutoffX = cutoffX else {
        return segments.map { TrimmedSegment(id: $0.id, isFirstAbove: $0.isFirstAbove, points: $0.points) }
    }

    return segments.compactMap { seg in
        guard let firstX = seg.points.first?.x, let lastX = seg.points.last?.x else { return nil }
        // If cutoff is before this segment starts, skip it.
        if cutoffX <= firstX { return nil }
        // If cutoff is after this segment ends, include entire segment.
        if cutoffX >= lastX { return TrimmedSegment(id: seg.id, isFirstAbove: seg.isFirstAbove, points: seg.points) }

        // Cutoff falls inside this segment. Keep all points up to the cutoff and add an interpolated point at cutoff.
        let pts = seg.points
        // Exact match: include up to that point.
        if let exactIndex = pts.firstIndex(where: { $0.x == cutoffX }) {
            let sub = Array(pts.prefix(exactIndex + 1))
            return sub.count >= 2 ? TrimmedSegment(id: seg.id, isFirstAbove: seg.isFirstAbove, points: sub) : nil
        }
        // Find the first point with x greater than cutoff
        guard let upperIndex = pts.firstIndex(where: { $0.x > cutoffX }), upperIndex > 0 else { return nil }
        let lowerIndex = upperIndex - 1
        let a = pts[lowerIndex]
        let b = pts[upperIndex]
        let span = max(b.x - a.x, .ulpOfOne)
        let t = (cutoffX - a.x) / span
        let y1 = a.y1 + t * (b.y1 - a.y1)
        let y2 = a.y2 + t * (b.y2 - a.y2)
        let cutoffPoint = SegmentPoint(x: cutoffX, y1: y1, y2: y2)
        let trimmedPoints = Array(pts.prefix(upperIndex)) + [cutoffPoint]
        return trimmedPoints.count >= 2 ? TrimmedSegment(id: seg.id, isFirstAbove: seg.isFirstAbove, points: trimmedPoints) : nil
    }
}

private func makeSegments(from points: [PairedPoint]) -> [Segment] {
    guard points.count >= 2 else {
        if let first = points.first {
            let sp = SegmentPoint(x: Double(first.x), y1: first.y1, y2: first.y2)
            return [Segment(points: [sp], isFirstAbove: first.isFirstAbove)]
        }
        return []
    }

    var segments: [Segment] = []

    func segPoint(_ p: PairedPoint) -> SegmentPoint {
        SegmentPoint(x: Double(p.x), y1: p.y1, y2: p.y2)
    }

    var currentPoints: [SegmentPoint] = [segPoint(points[0])]
    var currentAbove = points[0].isFirstAbove

    for i in 0..<(points.count - 1) {
        let a = points[i]
        let b = points[i + 1]

        let aAbove = a.isFirstAbove
        let bAbove = b.isFirstAbove

        if aAbove == bAbove {
            // Same side: just continue the segment
            currentPoints.append(segPoint(b))
        } else {
            // Crossing between a and b. Compute linear intersection.
            let x0 = Double(a.x)
            let x1 = Double(b.x)
            let dy1 = b.y1 - a.y1
            let dy2 = b.y2 - a.y2
            let denom = (dy1 - dy2)

            // If denom is 0, treat as no distinct crossing; just split at midpoint to avoid degenerate case.
            let t: Double
            if abs(denom) < .ulpOfOne {
                t = 0.5
            } else {
                t = (a.y2 - a.y1) / denom
            }
            let clampedT = max(0, min(1, t))
            let xCross = x0 + clampedT * (x1 - x0)
            let yCross = a.y1 + clampedT * dy1 // == a.y2 + clampedT * dy2
            let cross = SegmentPoint(x: xCross, y1: yCross, y2: yCross)

            // Close current segment at the intersection
            currentPoints.append(cross)
            segments.append(Segment(points: currentPoints, isFirstAbove: currentAbove))

            // Start a new segment from the intersection
            currentPoints = [cross, segPoint(b)]
            currentAbove = bAbove
        }
    }

    // Append the last running segment
    if !currentPoints.isEmpty {
        segments.append(Segment(points: currentPoints, isFirstAbove: currentAbove))
    }

    return segments
}

#Preview {
    TwoLineComparisonChart(data: TwoLineData.sample)
        .frame(height: 300)
        .padding()
}
