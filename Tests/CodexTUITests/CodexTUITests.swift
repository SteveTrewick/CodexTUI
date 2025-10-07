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
    let accelerator  = TerminalInput.Token.meta(.alt("f"))
    let item         = MenuItem(title: "File", activationKey: accelerator)

    let metaMatching = TerminalInput.Token.meta(.alt("f"))
    let nonMatching  = TerminalInput.Token.text("f")

    XCTAssertTrue(item.matches(token: metaMatching))
    XCTAssertFalse(item.matches(token: nonMatching))
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
      signalObserver : SignalObserver(signalQueue: DispatchQueue(label: "test-signal-queue"))
    )

    let expectation = expectation(description: "Key event delivered without buffering")

    driver.onKeyEvent = { token in
      switch token {
        case .text(let string) : XCTAssertEqual(string, "a")
        default                : XCTFail("Unexpected token: \(token)")
      }
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

  func testMenuControllerOpensMenuAndProducesOverlay () {
    let theme      = Theme.codex
    let entries    = [
      MenuItem.Entry(title: "First", acceleratorHint: "Ctrl+F"),
      MenuItem.Entry(title: "Second", acceleratorHint: "Ctrl+S")
    ]
    let menuItems  = [
      MenuItem(
        title         : "File",
        activationKey : .meta(.alt("f")),
        alignment     : .leading,
        isHighlighted : true,
        entries       : entries
      )
    ]
    let menuBar    = MenuBar(
      items : menuItems,
      style : theme.menuBar,
      highlightStyle   : theme.highlight,
      dimHighlightStyle: theme.dimHighlight
    )
    let buffer     = TextBuffer(identifier: FocusIdentifier("log"), isInteractive: true)
    let content    = AnyWidget(buffer)
    let focusChain = FocusChain()
    focusChain.register(node: buffer.focusNode())
    let scene      = Scene.standard(menuBar: menuBar, content: content, configuration: SceneConfiguration(theme: theme), focusChain: focusChain)
    let viewport   = BoxBounds(row: 1, column: 1, width: 40, height: 12)
    let controller = MenuController(scene: scene, menuBar: menuBar, content: content, viewportBounds: viewport)

    XCTAssertTrue(controller.handle(token: .meta(.alt("f"))))
    XCTAssertEqual(scene.overlays.count, 1)
    XCTAssertNotNil(controller.activeOverlayBounds)

    let overlayBounds = controller.activeOverlayBounds!
    let context       = scene.layoutContext(for: viewport)
    let layout        = scene.overlays[0].layout(in: context)
    XCTAssertEqual(layout.bounds, overlayBounds)

    let commands = layout.flattenedCommands()
    let highlightTile = commands.first { command in
      return command.row == overlayBounds.row + 1 && command.column == overlayBounds.column + 1
    }

    XCTAssertEqual(highlightTile?.tile.attributes, theme.highlight)
  }

  func testMenuControllerNavigationUpdatesHighlight () {
    let theme      = Theme.codex
    let entries    = [
      MenuItem.Entry(title: "First"),
      MenuItem.Entry(title: "Second")
    ]
    let menuItems  = [
      MenuItem(
        title         : "File",
        activationKey : .meta(.alt("f")),
        alignment     : .leading,
        isHighlighted : true,
        entries       : entries
      )
    ]
    let menuBar    = MenuBar(items: menuItems, style: theme.menuBar, highlightStyle: theme.highlight, dimHighlightStyle: theme.dimHighlight)
    let buffer     = TextBuffer(identifier: FocusIdentifier("log"), isInteractive: true)
    let content    = AnyWidget(buffer)
    let focusChain = FocusChain()
    focusChain.register(node: buffer.focusNode())
    let scene      = Scene.standard(menuBar: menuBar, content: content, configuration: SceneConfiguration(theme: theme), focusChain: focusChain)
    let viewport   = BoxBounds(row: 1, column: 1, width: 40, height: 12)
    let controller = MenuController(scene: scene, menuBar: menuBar, content: content, viewportBounds: viewport)

    XCTAssertTrue(controller.handle(token: .meta(.alt("f"))))
    XCTAssertTrue(controller.handle(token: .cursor(.down)))

    let overlayBounds = controller.activeOverlayBounds!
    let context       = scene.layoutContext(for: viewport)
    let layout        = scene.overlays[0].layout(in: context)
    let commands      = layout.flattenedCommands()

    let secondRowTile = commands.first { command in
      return command.row == overlayBounds.row + 2 && command.column == overlayBounds.column + 1
    }

    XCTAssertEqual(secondRowTile?.tile.attributes, theme.highlight)
  }

  func testMenuControllerEscapeRestoresFocusAndClearsOverlay () {
    let theme      = Theme.codex
    let entries    = [MenuItem.Entry(title: "Only Item")]
    let menuItems  = [
      MenuItem(
        title         : "File",
        activationKey : .meta(.alt("f")),
        alignment     : .leading,
        isHighlighted : true,
        entries       : entries
      )
    ]
    let menuBar    = MenuBar(items: menuItems, style: theme.menuBar, highlightStyle: theme.highlight, dimHighlightStyle: theme.dimHighlight)
    let buffer     = TextBuffer(identifier: FocusIdentifier("log"), isInteractive: true)
    let content    = AnyWidget(buffer)
    let focusChain = FocusChain()
    focusChain.register(node: buffer.focusNode())
    let scene      = Scene.standard(menuBar: menuBar, content: content, configuration: SceneConfiguration(theme: theme), focusChain: focusChain)
    let viewport   = BoxBounds(row: 1, column: 1, width: 40, height: 12)
    let controller = MenuController(scene: scene, menuBar: menuBar, content: content, viewportBounds: viewport)

    let initialFocus = scene.focusChain.active

    XCTAssertTrue(controller.handle(token: .meta(.alt("f"))))
    XCTAssertEqual(scene.overlays.isEmpty, false)
    XCTAssertTrue(controller.handle(token: .escape))
    XCTAssertTrue(scene.overlays.isEmpty)
    XCTAssertEqual(scene.focusChain.active, initialFocus)
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
