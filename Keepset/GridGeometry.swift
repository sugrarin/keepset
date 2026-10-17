import CoreGraphics

struct GridGeometry: Equatable {
    let width: CGFloat
    let columns: Int
    let spacing: CGFloat
    let inset: CGFloat

    var cellSide: CGFloat {
        (width - inset * 2 - spacing * CGFloat(columns - 1)) / CGFloat(columns)
    }

    func index(at point: CGPoint, count: Int) -> Int? {
        guard columns > 0, cellSide > 0 else { return nil }
        let pitch = cellSide + spacing
        let x = point.x - inset
        let y = point.y - inset
        guard x >= 0, y >= 0, x < width - inset * 2 else { return nil }
        let column = min(Int(x / pitch), columns - 1)
        let index = Int(y / pitch) * columns + column
        return index < count ? index : nil
    }
}
