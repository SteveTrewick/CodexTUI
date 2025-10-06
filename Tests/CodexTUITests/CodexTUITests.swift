import XCTest
import TerminalOutput
@testable import CodexTUI

final class CodexTUITests: XCTestCase {
  func testSurfaceDiffDetectsChanges () {
    var surface = Surface(width: 4, height: 2)
    surface.beginFrame()
    surface.clear()
    surface.set(tile: SurfaceTile(character: "A", attributes: ColorPair()), atRow: 1, column: 1)

    let changes = surface.diff()
    XCTAssertEqual(changes.count, 1)
    XCTAssertEqual(changes.first?.row, 1)
    XCTAssertEqual(changes.first?.column, 1)
  }

  func testFocusChainAdvancesAndWraps () {
    let identifierA = FocusIdentifier("a")
    let identifierB = FocusIdentifier("b")
    let nodeA       = FocusNode(identifier: identifierA)
    let nodeB       = FocusNode(identifier: identifierB)
    let chain       = FocusChain(nodes: [nodeA, nodeB])

    XCTAssertEqual(chain.active, identifierA)

    chain.advance()
    XCTAssertEqual(chain.active, identifierB)

    chain.advance()
    XCTAssertEqual(chain.active, identifierA)
  }

  func testSceneRendersText () throws {
    let text      = Text("Hello", origin: (row: 1, column: 1))
    let content   = AnyWidget(text)
    let scene     = Scene.standard(content: content)
    var surface   = Surface(width: 10, height: 3)
    let bounds    = BoxBounds(row: 1, column: 1, width: 10, height: 3)

    let sequences = scene.render(into: &surface, bounds: bounds)

    XCTAssertFalse(sequences.isEmpty)
    let firstTile = surface.tile(atRow: 1, column: 1)
    XCTAssertEqual(firstTile.map { String($0.character) }, "H")
    XCTAssertEqual(firstTile?.attributes.style, TerminalOutput.TextStyle.none)
  }
}
