import CoreGraphics
import Testing
@testable import Keepset

struct GridGeometryTests {
    // 3 columns, 3 pt inset and spacing: (309 - 6 - 6) / 3 = 99 pt cells, 102 pt pitch.
    let geometry = GridGeometry(width: 309, columns: 3, spacing: 3, inset: 3)

    @Test func cellSideFillsWidthMinusInsetsAndGaps() {
        #expect(geometry.cellSide == 99)
    }

    @Test func findsCellsAcrossColumnsAndRows() {
        #expect(geometry.index(at: CGPoint(x: 4, y: 4), count: 10) == 0)
        #expect(geometry.index(at: CGPoint(x: 106, y: 4), count: 10) == 1)
        #expect(geometry.index(at: CGPoint(x: 208, y: 50), count: 10) == 2)
        #expect(geometry.index(at: CGPoint(x: 4, y: 106), count: 10) == 3)
    }

    @Test func gapBelongsToPrecedingCell() {
        #expect(geometry.index(at: CGPoint(x: 103, y: 4), count: 10) == 0)
    }

    @Test func pointsOutsideGridOrPastLastPhotoHaveNoCell() {
        #expect(geometry.index(at: CGPoint(x: 1, y: 4), count: 10) == nil)
        #expect(geometry.index(at: CGPoint(x: 4, y: -10), count: 10) == nil)
        #expect(geometry.index(at: CGPoint(x: 308, y: 4), count: 10) == nil)
        #expect(geometry.index(at: CGPoint(x: 106, y: 310), count: 10) == nil)
    }
}
