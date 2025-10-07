import XCTest
import Dispatch
import TerminalInput
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

  func testMenuItemMatchesPrintableAccelerator () {
    let accelerator  = MenuActivationKey(key: .character("f"), modifiers: [.option])
    let item         = MenuItem(title: "File", activationKey: accelerator)
    
    let metaMatching = KeyEvent(key: .meta("f"), modifiers: [.option])
    let nonMatching  = KeyEvent(key: .character("f"))

    
    XCTAssertTrue(item.matches(event: metaMatching))
    XCTAssertFalse(item.matches(event: nonMatching))
  }

  func testTextBufferDefaultsToNewestLine () {
    let buffer        = TextBuffer(identifier: FocusIdentifier("buffer"))
    let focusChain    = FocusChain()
    let focusSnapshot = focusChain.snapshot()
    let bounds        = BoxBounds(row: 1, column: 1, width: 10, height: 2)
    let context       = LayoutContext(bounds: bounds, theme: Theme.codex, focus: focusSnapshot)

    buffer.append(line: "first")
    buffer.append(line: "second")
    buffer.append(line: "third")

    let result      = buffer.layout(in: context)
    let lastRow     = bounds.row + bounds.height - 1
    let lineCommand = result.commands
      .filter { $0.row == lastRow }
      .sorted { $0.column < $1.column }
    let rendered    = String(lineCommand.map { $0.tile.character })

    XCTAssertEqual(buffer.scrollOffset, 1)
    XCTAssertEqual(rendered, "third")
  }

  func testDriverDeliversKeyPressImmediatelyInRawMode () {
    let connection    = TestTerminalConnection()
    let terminal      = TerminalOutput.Terminal(connection: connection)
    let input         = TerminalInput()
    let mode          = TestTerminalModeController()
    let scene         = Scene.standard(content: AnyWidget(Text("", origin: (row: 1, column: 1))))
    let configuration = RuntimeConfiguration(usesAlternateBuffer: false, hidesCursor: false)
    let driver        = TerminalDriver(
      scene          : scene,
      terminal       : terminal,
      input          : input,
      terminalMode   : mode,
      configuration  : configuration,
      signalObserver : SignalObserver(queue: DispatchQueue(label: "test-signal-queue"))
    )

    let expectation = expectation(description: "Key event delivered without buffering")

    driver.onKeyEvent = { event in
      XCTAssertEqual(event, KeyEvent(key: .character("a")))
      XCTAssertTrue(mode.isRawModeActive)
      expectation.fulfill()
    }

    driver.start()

    input.dispatch?(.success(.text("a")))

    wait(for: [expectation], timeout: 1.0)
    XCTAssertEqual(mode.enterRawModeCount, 1)

    driver.stop()

    XCTAssertEqual(mode.restoreCount, 1)
    XCTAssertFalse(mode.isRawModeActive)
  }
}

private final class TestTerminalModeController: TerminalModeController {
  private(set) var enterRawModeCount : Int = 0
  private(set) var restoreCount      : Int = 0
  private(set) var isRawModeActive   : Bool = false

  override func enterRawMode () {
    enterRawModeCount += 1
    isRawModeActive    = true
  }

  override func restore () {
    restoreCount    += 1
    isRawModeActive  = false
  }
}

private final class TestTerminalConnection: TerminalOutput.TerminalConnection {
  func write ( data: Data ) throws { }
  func flush () throws { }
}
