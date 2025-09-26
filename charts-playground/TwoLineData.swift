import Foundation

/// A single x-position with two y-values to compare.
public struct PairedPoint: Identifiable, Hashable {
    public var id: Int { x }
    public var x: Int
    public var y1: Double
    public var y2: Double

    public init(x: Int, y1: Double, y2: Double) {
        self.x = x
        self.y1 = y1
        self.y2 = y2
    }

    /// Difference between the two series at this x (y1 - y2).
    public var diff: Double { y1 - y2 }
    /// True if the first series is greater than or equal to the second at this x.
    public var isFirstAbove: Bool { y1 >= y2 }
}

/// Convenience helpers to generate example data for the two-line comparison chart.
public enum TwoLineData {
    /// A small, smooth sample for previews and initial display.
    public static let sample: [PairedPoint] = [
        PairedPoint(x: 0,  y1: 34, y2: 20),
        PairedPoint(x: 1,  y1: 42, y2: 23),
        PairedPoint(x: 2,  y1: 39, y2: 30),
        PairedPoint(x: 3,  y1: 50, y2: 36),
        PairedPoint(x: 4,  y1: 58, y2: 45),
        PairedPoint(x: 5,  y1: 62, y2: 53),
        PairedPoint(x: 6,  y1: 65, y2: 60),
        PairedPoint(x: 7,  y1: 60, y2: 66),
        PairedPoint(x: 8,  y1: 55, y2: 70),
        PairedPoint(x: 9,  y1: 49, y2: 72),
        PairedPoint(x: 10, y1: 44, y2: 71),
        PairedPoint(x: 11, y1: 40, y2: 68),
        PairedPoint(x: 12, y1: 38, y2: 62),
        PairedPoint(x: 13, y1: 36, y2: 55),
        PairedPoint(x: 14, y1: 35, y2: 48),
        PairedPoint(x: 15, y1: 37, y2: 43),
        PairedPoint(x: 16, y1: 41, y2: 40),
        PairedPoint(x: 17, y1: 47, y2: 39),
        PairedPoint(x: 18, y1: 52, y2: 38),
        PairedPoint(x: 19, y1: 58, y2: 37)
    ]

    /// Generate random points in range 0...100 for both series.
    /// - Parameter count: Number of points to create, spaced by x = 0..<(count).
    public static func random(count: Int = 20) -> [PairedPoint] {
        (0..<max(count, 0)).map { i in
            PairedPoint(x: i,
                        y1: Double.random(in: 0...100),
                        y2: Double.random(in: 0...100))
        }
    }
}
