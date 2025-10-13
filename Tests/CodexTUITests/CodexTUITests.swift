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
    let text      = Text("Hello")
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

  func testPanelWrapsBodyLinesWithinInteriorWidth () {
    let theme        = Theme.codex
    let bounds       = BoxBounds(row: 1, column: 1, width: 18, height: 6)
    let context      = LayoutContext(bounds: bounds, theme: theme, focus: FocusChain().snapshot())
    let panel        = Panel(title: "Guide", bodyLines: ["Words that should wrap cleanly inside the panel interior."], theme: theme)
    let layout       = panel.layout(in: context)
    let commands     = layout.flattenedCommands()
    let bodyTiles    = commands.filter { $0.tile.attributes == theme.contentDefault }
    let interior     = bounds.column + 2
    let interiorMax  = bounds.maxCol - 2

    XCTAssertFalse(bodyTiles.isEmpty)
    XCTAssertTrue(bodyTiles.allSatisfy { $0.column >= interior && $0.column <= interiorMax })

    let uniqueRows = Set(bodyTiles.map { $0.row })
    XCTAssertGreaterThan(uniqueRows.count, 1)
  }

  func testPanelDrawsBorderUsingWindowChrome () {
    let theme        = Theme.codex
    let bounds       = BoxBounds(row: 2, column: 3, width: 16, height: 5)
    let context      = LayoutContext(bounds: bounds, theme: theme, focus: FocusChain().snapshot())
    let panel        = Panel(title: "Info", bodyLines: ["Body"], theme: theme)
    let layout       = panel.layout(in: context)
    let commands     = layout.flattenedCommands()
    let borderTiles  = commands.filter { $0.tile.attributes == theme.windowChrome }

    XCTAssertFalse(borderTiles.isEmpty)

    let corners = [
      (row: bounds.row, column: bounds.column, character: "┌"),
      (row: bounds.row, column: bounds.maxCol, character: "┐"),
      (row: bounds.maxRow, column: bounds.column, character: "└"),
      (row: bounds.maxRow, column: bounds.maxCol, character: "┘")
    ]

    for corner in corners {
      let tile = borderTiles.first { command in
        return command.row == corner.row && command.column == corner.column && String(command.tile.character) == corner.character
      }

      XCTAssertNotNil(tile)
    }
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
    let scene         = Scene.standard(content: AnyWidget(Text("")))
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

  func testMessageBoxLayoutHighlightsActiveButton () {
    let theme      = Theme.codex
    let buttons    = [
      MessageBoxButton(text: "First"),
      MessageBoxButton(text: "Second")
    ]
    let messageBox = MessageBox(
      title             : "Title",
      messageLines      : ["Body"],
      buttons           : buttons,
      activeButtonIndex : 1,
      titleStyle        : theme.highlight,
      contentStyle      : theme.contentDefault,
      buttonStyle       : theme.dimHighlight,
      highlightStyle    : theme.highlight,
      borderStyle       : theme.windowChrome
    )
    let bounds     = BoxBounds(row: 1, column: 1, width: 30, height: 7)
    let context    = LayoutContext(bounds: bounds, theme: theme, focus: FocusChain().snapshot())
    let layout     = messageBox.layout(in: context)
    let commands   = layout.flattenedCommands()
    let buttonRow  = bounds.maxRow - 1

    let highlightTiles = commands.filter { command in
      return command.row == buttonRow && command.tile.attributes == theme.highlight
    }

    XCTAssertFalse(highlightTiles.isEmpty)

    let interior      = bounds.inset(by: EdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1))
    let edgeCommands  = commands.filter { command in
      return command.row == buttonRow && command.column == interior.maxCol
    }
    XCTAssertFalse(edgeCommands.isEmpty)
    XCTAssertEqual(edgeCommands.last?.tile.attributes, theme.highlight)
  }

  func testMessageBoxLayoutAppliesMessageLineOverrides () {
    let theme        = Theme.codex
    let overridePair = ColorPair(foreground: .yellow, background: .black)
    let messageBox   = MessageBox(
      title             : "",
      messageLines      : ["Override", "Default"],
      messageLineStyles : [overridePair, nil],
      buttons           : [],
      activeButtonIndex : 0,
      titleStyle        : theme.highlight,
      contentStyle      : theme.contentDefault,
      buttonStyle       : theme.dimHighlight,
      highlightStyle    : theme.highlight,
      borderStyle       : theme.windowChrome
    )
    let bounds      = BoxBounds(row: 1, column: 1, width: 30, height: 6)
    let context     = LayoutContext(bounds: bounds, theme: theme, focus: FocusChain().snapshot())
    let layout      = messageBox.layout(in: context)
    let commands    = layout.flattenedCommands()

    guard let details = messageContentInterior(commands: commands, bounds: bounds) else {
      XCTFail("Expected content interior to be available")
      return
    }

    let contentBounds   = details.bounds
    let separators      = details.separators
    let topSeparator    = separators.top
    let bottomSeparator = separators.bottom

    let topRuleCommands = commands.filter { command in
      return command.row == topSeparator && command.tile.attributes == theme.windowChrome
    }
    XCTAssertTrue(topRuleCommands.contains { String($0.tile.character) == "─" })

    let bottomRuleCommands = commands.filter { command in
      return command.row == bottomSeparator && command.tile.attributes == theme.windowChrome
    }
    XCTAssertFalse(bottomRuleCommands.isEmpty)
    XCTAssertTrue(bottomRuleCommands.contains { String($0.tile.character) == "─" })

    let firstRow   = contentBounds.row
    let secondRow  = min(firstRow + 1, contentBounds.maxRow)
    let firstLine  = commands.filter { $0.row == firstRow && $0.tile.attributes == overridePair }
    let secondLine = commands.filter { $0.row == secondRow && $0.tile.attributes == theme.contentDefault }

    XCTAssertFalse(firstLine.isEmpty)
    XCTAssertFalse(secondLine.isEmpty)
  }

  func testModalDialogSurfaceLayoutProvidesInteriorAndHighlight () {
    let theme   = Theme.codex
    let bounds  = BoxBounds(row: 1, column: 1, width: 24, height: 7)
    let context = LayoutContext(bounds: bounds, theme: theme, focus: FocusChain().snapshot())
    let layout  = ModalDialogSurface.layout(
      in               : context,
      contentStyle     : theme.contentDefault,
      borderStyle      : theme.windowChrome,
      buttonTitles     : ["One", "Two"],
      activeButtonIndex: 1,
      buttonStyle      : theme.dimHighlight,
      highlightStyle   : theme.highlight
    )

    XCTAssertEqual(layout.interior, bounds.inset(by: EdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1)))
    guard let buttonRow = layout.buttonRow else {
      XCTFail("Expected button row to be present")
      return
    }

    let highlightTiles = layout.result.commands.filter { command in
      return command.row == buttonRow && command.tile.attributes == theme.highlight
    }

    XCTAssertFalse(highlightTiles.isEmpty)

    let edgeCommands = layout.result.commands.filter { command in
      return command.row == buttonRow && command.column == layout.interior.maxCol
    }
    XCTAssertFalse(edgeCommands.isEmpty)
    XCTAssertEqual(edgeCommands.last?.tile.attributes, theme.highlight)
  }

  func testTextEntryBoxLayoutHighlightsCaret () {
    let theme   = Theme.codex
    let buttons = [
      TextEntryBoxButton(text: "OK"),
      TextEntryBoxButton(text: "Cancel")
    ]
    let widget  = TextEntryBox(
      title             : "Edit",
      prompt            : "Name",
      text              : "abc",
      caretIndex        : 1,
      buttons           : buttons,
      activeButtonIndex : 0,
      titleStyle        : theme.highlight,
      promptStyle       : theme.contentDefault,
      contentStyle      : theme.contentDefault,
      fieldStyle        : theme.contentDefault,
      caretStyle        : theme.highlight,
      buttonStyle       : theme.dimHighlight,
      highlightStyle    : theme.highlight,
      borderStyle       : theme.windowChrome
    )
    let bounds  = BoxBounds(row: 1, column: 1, width: 30, height: 7)
    let context = LayoutContext(bounds: bounds, theme: theme, focus: FocusChain().snapshot())
    let layout  = widget.layout(in: context)
    let commands = layout.flattenedCommands()

    guard let contentInfo = textEntryContentInterior(commands: commands, bounds: bounds) else {
      XCTFail("Expected text entry interior bounds to be available")
      return
    }

    let contentBounds   = contentInfo.bounds
    let contentInterior = contentInfo.interior
    let topSeparator    = contentInfo.separators.top
    let bottomSeparator = contentInfo.separators.bottom

    let leftTopConnector = commands.first { command in
      return command.row == topSeparator && command.column == bounds.column && String(command.tile.character) == "├"
    }
    XCTAssertNotNil(leftTopConnector)

    let rightTopConnector = commands.first { command in
      return command.row == topSeparator && command.column == bounds.maxCol && String(command.tile.character) == "┤"
    }
    XCTAssertNotNil(rightTopConnector)

    let leftBottomConnector = commands.first { command in
      return command.row == bottomSeparator && command.column == bounds.column && String(command.tile.character) == "├"
    }
    XCTAssertNotNil(leftBottomConnector)

    let rightBottomConnector = commands.first { command in
      return command.row == bottomSeparator && command.column == bounds.maxCol && String(command.tile.character) == "┤"
    }
    XCTAssertNotNil(rightBottomConnector)

    let borderRowCommands = commands.filter { command in
      return command.row == bottomSeparator && command.tile.attributes == theme.windowChrome
    }
    XCTAssertFalse(borderRowCommands.isEmpty)

    var caretRow = contentInterior.row
    if let prompt = widget.prompt, prompt.isEmpty == false { caretRow = min(caretRow + 1, contentInterior.maxRow) }
    let caretCol = min(contentInterior.column + widget.caretIndex, contentInterior.maxCol)
    let caretTile = commands.first { command in
      return command.row == caretRow && command.column == caretCol && command.tile.attributes == theme.highlight
    }

    if let caretTile = caretTile {
      XCTAssertEqual(String(caretTile.tile.character), "b")
    } else {
      let fallback = commands.first { command in
        return command.tile.attributes == theme.highlight && String(command.tile.character) == "b"
      }
      XCTAssertNotNil(fallback)
      if let fallback = fallback {
        XCTAssertEqual(fallback.row, caretRow)
        XCTAssertEqual(fallback.column, caretCol)
      }
    }

    let buttonRow      = bottomSeparator + 1
    let edgeCommands   = commands.filter { command in
      return command.row == buttonRow && command.column == contentBounds.maxCol
    }
    XCTAssertFalse(edgeCommands.isEmpty)
    XCTAssertEqual(edgeCommands.last?.tile.attributes, theme.dimHighlight)
  }

  func testMessageBoxControllerHandlesInputAndDismissal () {
    let theme      = Theme.codex
    let buffer     = TextBuffer(identifier: FocusIdentifier("log"), isInteractive: true)
    let focusChain = FocusChain()
    focusChain.register(node: buffer.focusNode())
    let scene      = Scene.standard(content: AnyWidget(buffer), configuration: SceneConfiguration(theme: theme), focusChain: focusChain)
    let viewport   = BoxBounds(row: 1, column: 1, width: 60, height: 18)
    let controller = MessageBoxController(scene: scene, viewportBounds: viewport)
    let initialOverlays = scene.overlays
    let initialFocus    = scene.focusChain.active
    var activationCount = 0

    let buttons = [
      MessageBoxButton(text: "OK"),
      MessageBoxButton(text: "Details", handler: { activationCount += 1 })
    ]

    controller.present(title: "Notice", messageLines: ["Testing"], buttons: buttons)

    XCTAssertTrue(controller.isPresenting)
    XCTAssertEqual(controller.activeButton, 0)
    XCTAssertEqual(scene.overlays.count, initialOverlays.count + 1)

    var expectedTitleStyle = theme.contentDefault
    expectedTitleStyle.style.insert(.bold)

    guard let bounds = controller.currentBounds else {
      XCTFail("Expected message box bounds to be available")
      return
    }

    let context        = scene.layoutContext(for: viewport)
    let overlayLayout  = scene.overlays.last!.layout(in: context)
    let overlayCommands = overlayLayout.flattenedCommands()
    let interior       = bounds.inset(by: EdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1))
    let titleRow       = interior.row
    let titleCommands  = overlayCommands.filter { command in
      return command.row == titleRow && command.column >= interior.column && command.column <= interior.maxCol
    }

    let messageTitleCommands = titleCommands.filter { $0.tile.attributes == expectedTitleStyle }.sorted { $0.column < $1.column }

    XCTAssertFalse(messageTitleCommands.isEmpty)
    let renderedMessageTitle = String(messageTitleCommands.map { $0.tile.character })
    XCTAssertEqual(renderedMessageTitle, "Notice")

    XCTAssertTrue(controller.handle(token: .control(.TAB)))
    XCTAssertEqual(controller.activeButton, 1)

    XCTAssertTrue(controller.handle(token: .control(.RETURN)))
    XCTAssertEqual(activationCount, 1)
    XCTAssertFalse(controller.isPresenting)
    XCTAssertEqual(scene.overlays.count, initialOverlays.count)
    XCTAssertEqual(scene.focusChain.active, initialFocus)

    controller.present(title: "Notice", messageLines: ["Testing"], buttons: buttons)
    XCTAssertTrue(controller.isPresenting)
    XCTAssertTrue(controller.handle(token: .escape))
    XCTAssertFalse(controller.isPresenting)
    XCTAssertEqual(scene.overlays.count, initialOverlays.count)
    XCTAssertEqual(scene.focusChain.active, initialFocus)
  }

  func testMessageBoxControllerDefaultsAndOverridesButtonStyle () {
    let theme      = Theme.codex
    let buffer     = TextBuffer(identifier: FocusIdentifier("log"), isInteractive: true)
    let focusChain = FocusChain()
    focusChain.register(node: buffer.focusNode())
    let scene      = Scene.standard(content: AnyWidget(buffer), configuration: SceneConfiguration(theme: theme), focusChain: focusChain)
    let viewport   = BoxBounds(row: 1, column: 1, width: 60, height: 18)
    let controller = MessageBoxController(scene: scene, viewportBounds: viewport)
    let buttons    = [
      MessageBoxButton(text: "OK"),
      MessageBoxButton(text: "Cancel")
    ]

    controller.present(title: "Notice", messageLines: ["Testing"], buttons: buttons)

    guard let bounds = controller.currentBounds else {
      XCTFail("Expected message box bounds to be available")
      return
    }

    let context             = scene.layoutContext(for: viewport)
    let overlayLayout       = scene.overlays.last!.layout(in: context)
    let overlayCommands     = overlayLayout.flattenedCommands()
    let interior            = bounds.inset(by: EdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1))
    let buttonRow           = interior.maxRow
    let buttonRowCommands   = overlayCommands.filter { $0.row == buttonRow }
    let defaultStyleCommand = buttonRowCommands.first { $0.tile.attributes == theme.menuBar }
    let highlightCommand    = buttonRowCommands.first { $0.tile.attributes == theme.highlight }

    XCTAssertNotNil(defaultStyleCommand)
    XCTAssertNotNil(highlightCommand)

    controller.dismiss()

    let overrideStyle = ColorPair(foreground: .red, background: .black)

    controller.present(title: "Notice", messageLines: ["Testing"], buttons: buttons, buttonStyleOverride: overrideStyle)

    guard let overrideBounds = controller.currentBounds else {
      XCTFail("Expected message box bounds to be available")
      return
    }

    let overrideContext         = scene.layoutContext(for: viewport)
    let overrideLayout          = scene.overlays.last!.layout(in: overrideContext)
    let overrideCommands        = overrideLayout.flattenedCommands()
    let overrideInterior        = overrideBounds.inset(by: EdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1))
    let overrideButtonRow       = overrideInterior.maxRow
    let overrideButtonCommands  = overrideCommands.filter { $0.row == overrideButtonRow }
    let overrideStyleCommand    = overrideButtonCommands.first { $0.tile.attributes == overrideStyle }
    let overrideHighlight       = overrideButtonCommands.first { $0.tile.attributes == theme.highlight }

    XCTAssertNotNil(overrideStyleCommand)
    XCTAssertNotNil(overrideHighlight)
  }

  func testMessageBoxControllerAppliesTitleAndMessageOverrides () {
    let theme      = Theme.codex
    let buffer     = TextBuffer(identifier: FocusIdentifier("log"), isInteractive: true)
    let focusChain = FocusChain()
    focusChain.register(node: buffer.focusNode())
    let scene      = Scene.standard(content: AnyWidget(buffer), configuration: SceneConfiguration(theme: theme), focusChain: focusChain)
    let viewport   = BoxBounds(row: 1, column: 1, width: 60, height: 18)
    let controller = MessageBoxController(scene: scene, viewportBounds: viewport)
    let title      = "Styled"
    let message    = ["Custom", "Default"]
    let buttons    = [MessageBoxButton(text: "OK")]
    let titleStyle = ColorPair(foreground: .cyan, background: .black)
    let lineStyle  = ColorPair(foreground: .magenta, background: .black)

    controller.present(
      title                : title,
      messageLines         : message,
      buttons              : buttons,
      titleStyleOverride   : titleStyle,
      messageStyleOverrides: [lineStyle, nil]
    )

    guard let bounds = controller.currentBounds else {
      XCTFail("Expected message box bounds to be available")
      return
    }

    let context        = scene.layoutContext(for: viewport)
    let overlayLayout  = scene.overlays.last!.layout(in: context)
    let overlayCommands = overlayLayout.flattenedCommands()
    let interior       = bounds.inset(by: EdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1))

    guard let details = messageContentInterior(commands: overlayCommands, bounds: bounds) else {
      XCTFail("Expected content interior to be available")
      return
    }

    let contentInterior = details.interior

    let titleRow   = interior.row
    let messageRow = contentInterior.row
    let secondRow  = min(messageRow + 1, contentInterior.maxRow)

    let titleCommands = overlayCommands.filter { $0.row == titleRow && $0.tile.attributes == titleStyle }
    XCTAssertFalse(titleCommands.isEmpty)

    let customCommands = overlayCommands.filter { $0.row == messageRow && $0.tile.attributes == lineStyle }
    XCTAssertFalse(customCommands.isEmpty)

    let defaultCommands = overlayCommands.filter { $0.row == secondRow && $0.tile.attributes == theme.contentDefault }
    XCTAssertFalse(defaultCommands.isEmpty)
  }

  func testTextEntryBoxControllerHandlesInputAndDismissal () {
    let theme      = Theme.codex
    let buffer     = TextBuffer(identifier: FocusIdentifier("log"), isInteractive: true)
    let focusChain = FocusChain()
    focusChain.register(node: buffer.focusNode())
    let scene      = Scene.standard(content: AnyWidget(buffer), configuration: SceneConfiguration(theme: theme), focusChain: focusChain)
    let viewport   = BoxBounds(row: 1, column: 1, width: 60, height: 18)
    let controller = TextEntryBoxController(scene: scene, viewportBounds: viewport)
    let initialOverlays = scene.overlays
    let initialFocus    = scene.focusChain.active
    var capturedText    = ""

    let buttons = [
      TextEntryBoxButton(text: "Save", handler: { text in capturedText = text }),
      TextEntryBoxButton(text: "Cancel")
    ]

    controller.present(title: "Input", prompt: "Name", text: "", buttons: buttons)

    XCTAssertTrue(controller.isPresenting)
    XCTAssertEqual(controller.currentText, "")
    XCTAssertEqual(controller.caretIndex, 0)

    var expectedTitleStyle = theme.contentDefault
    expectedTitleStyle.style.insert(.bold)

    guard let bounds = controller.currentBounds else {
      XCTFail("Expected text entry box bounds to be available")
      return
    }

    let context        = scene.layoutContext(for: viewport)
    let overlayLayout  = scene.overlays.last!.layout(in: context)
    let overlayCommands = overlayLayout.flattenedCommands()
    let interior       = bounds.inset(by: EdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1))
    let titleRow       = interior.row
    let titleCommands  = overlayCommands.filter { command in
      return command.row == titleRow && command.column >= interior.column && command.column <= interior.maxCol
    }

    let entryTitleCommands = titleCommands.filter { $0.tile.attributes == expectedTitleStyle }.sorted { $0.column < $1.column }

    XCTAssertFalse(entryTitleCommands.isEmpty)
    let renderedEntryTitle = String(entryTitleCommands.map { $0.tile.character })
    XCTAssertEqual(renderedEntryTitle, "Input")

    guard let contentInfo = textEntryContentInterior(commands: overlayCommands, bounds: bounds) else {
      XCTFail("Expected text entry interior bounds to be available")
      return
    }

    let contentInterior = contentInfo.interior
    let promptRow       = contentInterior.row
    let promptCommands = overlayCommands.filter { command in
      return command.row == promptRow && command.column >= interior.column && command.column <= interior.maxCol
    }

    let entryPromptCommands = promptCommands.filter { $0.tile.attributes == theme.contentDefault }.sorted { $0.column < $1.column }

    XCTAssertFalse(entryPromptCommands.isEmpty)
    let promptCharacters    = entryPromptCommands.map { $0.tile.character }
    let renderedEntryPrompt = String(promptCharacters.filter { $0 != " " })
    XCTAssertEqual(renderedEntryPrompt, "Name")

    XCTAssertTrue(controller.handle(token: .text("ab")))
    XCTAssertEqual(controller.currentText, "ab")
    XCTAssertEqual(controller.caretIndex, 2)

    XCTAssertTrue(controller.handle(token: .cursor(.left)))
    XCTAssertEqual(controller.caretIndex, 1)

    XCTAssertTrue(controller.handle(token: .control(.BACKSPACE)))
    XCTAssertEqual(controller.currentText, "b")
    XCTAssertEqual(controller.caretIndex, 0)

    XCTAssertTrue(controller.handle(token: .cursor(.right)))
    XCTAssertEqual(controller.caretIndex, 1)

    XCTAssertTrue(controller.handle(token: .control(.DEL)))
    XCTAssertEqual(controller.currentText, "")
    XCTAssertEqual(controller.caretIndex, 0)

    XCTAssertTrue(controller.handle(token: .control(.TAB)))
    XCTAssertEqual(controller.activeButton, 1)

    XCTAssertTrue(controller.handle(token: .control(.TAB)))
    XCTAssertEqual(controller.activeButton, 0)

    XCTAssertTrue(controller.handle(token: .control(.RETURN)))
    XCTAssertEqual(capturedText, "")
    XCTAssertFalse(controller.isPresenting)
    XCTAssertEqual(scene.overlays.count, initialOverlays.count)
    XCTAssertEqual(scene.focusChain.active, initialFocus)

    controller.present(title: "Input", prompt: "Name", text: "seed", buttons: buttons)
    XCTAssertTrue(controller.isPresenting)
    XCTAssertTrue(controller.handle(token: .escape))
    XCTAssertFalse(controller.isPresenting)
    XCTAssertEqual(scene.overlays.count, initialOverlays.count)
    XCTAssertEqual(scene.focusChain.active, initialFocus)
  }

  func testTextEntryBoxControllerDefaultsAndOverridesStyles () {
    let theme      = Theme.codex
    let buffer     = TextBuffer(identifier: FocusIdentifier("log"), isInteractive: true)
    let focusChain = FocusChain()
    focusChain.register(node: buffer.focusNode())
    let scene      = Scene.standard(content: AnyWidget(buffer), configuration: SceneConfiguration(theme: theme), focusChain: focusChain)
    let viewport   = BoxBounds(row: 1, column: 1, width: 60, height: 18)
    let controller = TextEntryBoxController(scene: scene, viewportBounds: viewport)
    let buttons    = [
      TextEntryBoxButton(text: "Save"),
      TextEntryBoxButton(text: "Cancel")
    ]

    controller.present(title: "Input", prompt: "Name", text: "", buttons: buttons)

    guard let bounds = controller.currentBounds else {
      XCTFail("Expected text entry box bounds to be available")
      return
    }

    let context             = scene.layoutContext(for: viewport)
    let overlayLayout       = scene.overlays.last!.layout(in: context)
    let overlayCommands     = overlayLayout.flattenedCommands()
    let interior            = bounds.inset(by: EdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1))
    let buttonRow           = interior.maxRow
    let buttonRowCommands   = overlayCommands.filter { $0.row == buttonRow }
    let defaultStyleCommand = buttonRowCommands.first { $0.tile.attributes == theme.menuBar }
    let highlightCommand    = buttonRowCommands.first { $0.tile.attributes == theme.highlight }

    XCTAssertNotNil(defaultStyleCommand)
    XCTAssertNotNil(highlightCommand)

    let titleRow           = interior.row
    let titleCommands      = overlayCommands.filter { $0.row == titleRow }
    var expectedTitleStyle = theme.contentDefault
    expectedTitleStyle.style.insert(.bold)
    let defaultTitleCommand = titleCommands.first { $0.tile.attributes == expectedTitleStyle }

    XCTAssertNotNil(defaultTitleCommand)

    guard let contentInfo = textEntryContentInterior(commands: overlayCommands, bounds: bounds) else {
      XCTFail("Expected text entry interior bounds to be available")
      return
    }

    let contentInterior      = contentInfo.interior
    let promptRow            = contentInterior.row
    let promptCommands       = overlayCommands.filter { $0.row == promptRow }
    let defaultPromptCommand = promptCommands.first { $0.tile.attributes == theme.contentDefault }

    XCTAssertNotNil(defaultPromptCommand)

    controller.dismiss()

    let overrideButtonStyle = ColorPair(foreground: .red, background: .black)
    let overrideTitleStyle  = ColorPair(foreground: .yellow, background: .blue)
    let overridePromptStyle = ColorPair(foreground: .cyan, background: .magenta)

    controller.present(
      title               : "Input",
      prompt              : "Name",
      text                : "",
      buttons             : buttons,
      titleStyleOverride  : overrideTitleStyle,
      promptStyleOverride : overridePromptStyle,
      buttonStyleOverride : overrideButtonStyle
    )

    guard let overrideBounds = controller.currentBounds else {
      XCTFail("Expected text entry box bounds to be available")
      return
    }

    let overrideContext         = scene.layoutContext(for: viewport)
    let overrideLayout          = scene.overlays.last!.layout(in: overrideContext)
    let overrideCommands        = overrideLayout.flattenedCommands()
    let overrideInterior        = overrideBounds.inset(by: EdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1))
    let overrideButtonRow       = overrideInterior.maxRow
    let overrideButtonCommands  = overrideCommands.filter { $0.row == overrideButtonRow }
    let overrideStyleCommand    = overrideButtonCommands.first { $0.tile.attributes == overrideButtonStyle }
    let overrideHighlight       = overrideButtonCommands.first { $0.tile.attributes == theme.highlight }

    XCTAssertNotNil(overrideStyleCommand)
    XCTAssertNotNil(overrideHighlight)

    let overrideTitleRow        = overrideInterior.row
    let overrideTitleCommands   = overrideCommands.filter { $0.row == overrideTitleRow }
    let overrideTitleCommand    = overrideTitleCommands.first { $0.tile.attributes == overrideTitleStyle }

    XCTAssertNotNil(overrideTitleCommand)

    guard let overrideContentInfo = textEntryContentInterior(commands: overrideCommands, bounds: overrideBounds) else {
      XCTFail("Expected override text entry interior bounds to be available")
      return
    }

    let overrideContentInterior = overrideContentInfo.interior
    let overridePromptRow       = overrideContentInterior.row
    let overridePromptCommands  = overrideCommands.filter { $0.row == overridePromptRow }
    let overridePromptCommand   = overridePromptCommands.first { $0.tile.attributes == overridePromptStyle }

    XCTAssertNotNil(overridePromptCommand)
  }

  func testTextEntryBoxControllerRespectsStartWidth () {
    let theme      = Theme.codex
    let buffer     = TextBuffer(identifier: FocusIdentifier("log"), isInteractive: true)
    let focusChain = FocusChain()
    focusChain.register(node: buffer.focusNode())
    let scene      = Scene.standard(content: AnyWidget(buffer), configuration: SceneConfiguration(theme: theme), focusChain: focusChain)
    let viewport   = BoxBounds(row: 1, column: 1, width: 60, height: 18)
    let startWidth = 20
    let controller = TextEntryBoxController(scene: scene, viewportBounds: viewport, startWidth: startWidth)
    let buttons    = [
      TextEntryBoxButton(text: "Save"),
      TextEntryBoxButton(text: "Cancel")
    ]

    controller.present(title: "Input", prompt: "Name", text: "", buttons: buttons)

    XCTAssertTrue(controller.isPresenting)

    guard let bounds = controller.currentBounds else {
      XCTFail("Expected bounds to be set")
      return
    }

    let expected = TextEntryBox.centeredBounds(title: "Input", prompt: "Name", text: "", buttons: buttons, minimumFieldWidth: startWidth, in: viewport)

    XCTAssertEqual(bounds.width, expected.width)
  }

  func testMenuControllerOpensMenuAndProducesOverlay () {
    let theme      = Theme.codex
    let entries    = [
      MenuItem.Entry(title: "First", acceleratorHint: "Ctrl+F"),
      MenuItem.Entry(title: "Second", acceleratorHint: "Ctrl+S")
    ]
    let menuBar    = MenuBar {
      MenuItem(title: "File", activationKey: .meta(.alt("f")), isHighlighted: true) {
        entries
      }
    }
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
    let menuBar    = MenuBar {
      MenuItem(title: "File", activationKey: .meta(.alt("f")), isHighlighted: true) {
        entries
      }
    }
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
    let menuBar    = MenuBar {
      MenuItem(title: "File", activationKey: .meta(.alt("f")), isHighlighted: true) {
        entries
      }
    }
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

  func testSelectionListSurfaceRendersAcceleratorHints () {
    let theme     = Theme.codex
    let entries   = [
      SelectionListEntry(title: "Open", acceleratorHint: "⌘O"),
      SelectionListEntry(title: "Save", acceleratorHint: "⌘S")
    ]
    let bounds    = BoxBounds(row: 1, column: 1, width: 20, height: 6)
    let focus     = FocusChain().snapshot()
    let context   = LayoutContext(bounds: bounds, theme: theme, focus: focus)
    let surface   = SelectionListSurface.layout(
      entries        : entries,
      selectionIndex : 0,
      style          : theme.contentDefault,
      highlightStyle : theme.highlight,
      borderStyle    : theme.windowChrome,
      in             : context
    )
    let commands  = surface.result.flattenedCommands()
    let interior  = surface.interior

    let highlightRow = interior.row
    let hint         = "⌘O"
    let hintStart    = interior.maxCol - hint.count + 1

    for (offset, character) in hint.enumerated() {
      let column  = hintStart + offset
      let command = commands.last { $0.row == highlightRow && $0.column == column }
      XCTAssertEqual(command?.tile.character, character)
      XCTAssertEqual(command?.tile.attributes, theme.highlight)
    }

    let secondaryRow     = interior.row + 1
    let secondaryCommand = commands.last { $0.row == secondaryRow && $0.column == interior.column }
    XCTAssertEqual(secondaryCommand?.tile.attributes, theme.contentDefault)
  }

  func testSelectionListLayoutCentersTitleAndHighlightsSelection () {
    let theme       = Theme.codex
    let entries     = [
      SelectionListEntry(title: "Alpha"),
      SelectionListEntry(title: "Beta")
    ]
    let title       = "Select Item"
    let size        = SelectionList.preferredSize(title: title, entries: entries)
    let bounds      = BoxBounds(row: 1, column: 1, width: size.width, height: size.height)
    let focus       = FocusChain().snapshot()
    let context     = LayoutContext(bounds: bounds, theme: theme, focus: focus)
    let selection   = SelectionList(
      title          : title,
      selectionIndex : 1
    ) {
      entries
    }
    let layout      = selection.layout(in: context)
    let commands    = layout.flattenedCommands()
    let interior    = bounds.inset(by: EdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1))
    let usableTitle = title.prefix(interior.width)
    let offset      = max(0, (interior.width - usableTitle.count) / 2)
    let startColumn = interior.column + offset
    let titleRow    = interior.row

    let titleCommand = commands.last { $0.row == titleRow && $0.column == startColumn }
    XCTAssertEqual(titleCommand?.tile.character, usableTitle.first)
    var expectedTitleStyle = theme.contentDefault
    expectedTitleStyle.style.insert(.bold)
    XCTAssertEqual(titleCommand?.tile.attributes, expectedTitleStyle)

    let entryStartRow   = interior.row + 1
    let firstRowCommand = commands.last { $0.row == entryStartRow && $0.column == interior.column }
    XCTAssertEqual(firstRowCommand?.tile.attributes, theme.contentDefault)

    let highlightRow    = entryStartRow + 1
    let highlightCommand = commands.last { $0.row == highlightRow && $0.column == interior.column }
    XCTAssertEqual(highlightCommand?.tile.attributes, theme.highlight)
  }

  func testSelectionListControllerHandlesKeyboardInteractions () {
    let content    = AnyWidget(Text(""))
    let scene      = Scene.standard(content: content)
    let controller = SelectionListController(scene: scene)
    var activated  = [Int]()
    let entries    = [
      SelectionListEntry(title: "First", action: { activated.append(0) }),
      SelectionListEntry(title: "Second", action: { activated.append(1) })
    ]

    controller.present(title: "Pick", entries: entries, selectionIndex: 1)
    XCTAssertTrue(controller.isPresenting)
    XCTAssertEqual(controller.activeIndex, 1)

    XCTAssertTrue(controller.handle(token: .cursor(.down)))
    XCTAssertEqual(controller.activeIndex, 0)

    XCTAssertTrue(controller.handle(token: .control(.RETURN)))
    XCTAssertEqual(activated, [0])
    XCTAssertFalse(controller.isPresenting)

    controller.present(title: "Pick", entries: entries)
    XCTAssertTrue(controller.isPresenting)
    XCTAssertTrue(controller.handle(token: .escape))
    XCTAssertFalse(controller.isPresenting)
  }

  func testSplitContainerPropagatesFocusAndEnvironment () {
    let focusIdentifier = FocusIdentifier("target")
    let focusNode       = FocusNode(identifier: focusIdentifier)
    let focusChain      = FocusChain(nodes: [focusNode])
    let bounds          = BoxBounds(row: 1, column: 1, width: 10, height: 6)
    let environment     = EnvironmentValues(menuBarHeight: 1, statusBarHeight: 1, contentInsets: EdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1))
    let context         = LayoutContext(bounds: bounds, theme: Theme.codex, focus: focusChain.snapshot(), environment: environment)

    var capturedFocusIdentifiers = [FocusIdentifier?]()
    var capturedInsets           = [EdgeInsets]()

    let recorder = RecordingWidget { layoutContext in
      capturedFocusIdentifiers.append(layoutContext.focus.active)
      capturedInsets.append(layoutContext.environment.contentInsets)
    }

    let container = Split(
      axis      : .vertical,
      firstSize : .fixed(2),
      secondSize: .flexible,
      first     : { recorder },
      second    : { recorder }
    )

    _ = container.layout(in: context)

    XCTAssertEqual(capturedFocusIdentifiers.count, 2)
    XCTAssertTrue(capturedFocusIdentifiers.allSatisfy { $0 == focusIdentifier })
    XCTAssertEqual(capturedInsets.count, 2)
    XCTAssertTrue(capturedInsets.allSatisfy { $0 == environment.contentInsets })
  }

  func testEnvironmentScopeOverridesContentInsets () {
    let bounds   = BoxBounds(row: 1, column: 1, width: 8, height: 4)
    let context  = LayoutContext(bounds: bounds, theme: Theme.codex, focus: FocusChain().snapshot(), environment: EnvironmentValues(contentInsets: EdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2)))
    var captured = [EdgeInsets]()

    let recorder = RecordingWidget { layoutContext in
      captured.append(layoutContext.environment.contentInsets)
    }

    let scope = EnvironmentScope(applying: { values in values.contentInsets = EdgeInsets() }) {
      recorder
    }

    _ = scope.layout(in: context)

    XCTAssertEqual(captured.count, 1)
    XCTAssertEqual(captured.first, EdgeInsets())
  }

  private struct ModalContentArea {
    let bounds     : BoxBounds
    let interior   : BoxBounds
    let separators : (top: Int, bottom: Int)
  }

  private func textEntryContentInterior ( commands: [RenderCommand], bounds: BoxBounds ) -> ModalContentArea? {
    let leftColumn   = bounds.column
    let rightColumn  = bounds.maxCol
    let separatorRows = commands.compactMap { command -> Int? in
      guard command.column == leftColumn else { return nil }
      guard String(command.tile.character) == "├" else { return nil }
      return command.row
    }.sorted()

    guard let topSeparator = separatorRows.first else { return nil }
    guard let bottomSeparator = separatorRows.last else { return nil }
    guard bottomSeparator > topSeparator else { return nil }

    let hasRightTop = commands.contains { command in
      return command.row == topSeparator && command.column == rightColumn && String(command.tile.character) == "┤"
    }
    guard hasRightTop else { return nil }

    let hasRightBottom = commands.contains { command in
      return command.row == bottomSeparator && command.column == rightColumn && String(command.tile.character) == "┤"
    }
    guard hasRightBottom else { return nil }

    let width = max(0, bounds.width - 2)
    guard width > 0 else { return nil }

    let contentTop    = topSeparator + 1
    let contentBottom = max(contentTop, bottomSeparator - 1)
    let height        = max(0, contentBottom - contentTop + 1)
    guard height > 0 else { return nil }

    let contentBounds = BoxBounds(row: contentTop, column: bounds.column + 1, width: width, height: height)
    return ModalContentArea(bounds: contentBounds, interior: contentBounds, separators: (top: topSeparator, bottom: bottomSeparator))
  }

  private func messageContentInterior ( commands: [RenderCommand], bounds: BoxBounds ) -> ModalContentArea? {
    let leftColumn    = bounds.column
    let rightColumn   = bounds.maxCol
    let separatorRows = commands.compactMap { command -> Int? in
      guard command.column == leftColumn else { return nil }
      guard String(command.tile.character) == "├" else { return nil }
      return command.row
    }.sorted()

    guard let topSeparator = separatorRows.first else { return nil }
    guard let bottomSeparator = separatorRows.last else { return nil }
    guard bottomSeparator >= topSeparator else { return nil }

    let hasTopRight = commands.contains { command in
      return command.row == topSeparator && command.column == rightColumn && String(command.tile.character) == "┤"
    }
    guard hasTopRight else { return nil }

    let hasBottomRight = commands.contains { command in
      return command.row == bottomSeparator && command.column == rightColumn && String(command.tile.character) == "┤"
    }
    guard hasBottomRight else { return nil }

    let width = max(0, bounds.width - 2)
    guard width > 0 else { return nil }

    let contentTopCandidate    = topSeparator + 1
    let clampedContentTop      = min(bounds.maxRow, contentTopCandidate)
    let contentBottomCandidate = bottomSeparator - 1
    let clampedContentBottom   = min(bounds.maxRow, contentBottomCandidate)
    let contentBottom          = max(clampedContentTop, clampedContentBottom)
    let height                 = max(0, contentBottom - clampedContentTop + 1)
    guard height > 0 else { return nil }

    let contentBounds = BoxBounds(row: clampedContentTop, column: bounds.column + 1, width: width, height: height)
    let interior      = contentBounds.inset(by: EdgeInsets(top: 0, leading: 1, bottom: 0, trailing: 1))
    return ModalContentArea(bounds: contentBounds, interior: interior, separators: (top: topSeparator, bottom: bottomSeparator))
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

private struct RecordingWidget : Widget {
  var onLayout : (LayoutContext) -> Void

  func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    onLayout(context)
    return WidgetLayoutResult(bounds: context.bounds)
  }
}
