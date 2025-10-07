import Foundation
import TerminalInput

public struct TextEntryBoxButton {
  public let text          : String
  public let activationKey : TerminalInput.ControlKey
  public let handler       : ((String) -> Void)?

  public init ( text: String, activationKey: TerminalInput.ControlKey = .RETURN, handler: ((String) -> Void)? = nil ) {
    self.text          = text
    self.activationKey = activationKey
    self.handler       = handler
  }
}

public struct TextEntryBox : Widget {
  public var title             : String
  public var prompt            : String?
  public var text              : String
  public var caretIndex        : Int
  public var buttons           : [TextEntryBoxButton]
  public var activeButtonIndex : Int
  public var titleStyle        : ColorPair
  public var contentStyle      : ColorPair
  public var fieldStyle        : ColorPair
  public var caretStyle        : ColorPair
  public var buttonStyle       : ColorPair
  public var highlightStyle    : ColorPair
  public var borderStyle       : ColorPair

  public init (
    title: String,
    prompt: String? = nil,
    text: String,
    caretIndex: Int,
    buttons: [TextEntryBoxButton],
    activeButtonIndex: Int = 0,
    titleStyle: ColorPair,
    contentStyle: ColorPair,
    fieldStyle: ColorPair,
    caretStyle: ColorPair,
    buttonStyle: ColorPair,
    highlightStyle: ColorPair,
    borderStyle: ColorPair
  ) {
    self.title             = title
    self.prompt            = prompt
    self.text              = text
    self.caretIndex        = caretIndex
    self.buttons           = buttons
    self.activeButtonIndex = activeButtonIndex
    self.titleStyle        = titleStyle
    self.contentStyle      = contentStyle
    self.fieldStyle        = fieldStyle
    self.caretStyle        = caretStyle
    self.buttonStyle       = buttonStyle
    self.highlightStyle    = highlightStyle
    self.borderStyle       = borderStyle
  }

  public func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    let surface = ModalDialogSurface.layout(
      in               : context,
      contentStyle     : contentStyle,
      borderStyle      : borderStyle,
      buttonTitles     : buttons.map { $0.text },
      activeButtonIndex: activeButtonIndex,
      buttonStyle      : buttonStyle,
      highlightStyle   : highlightStyle
    )

    var commands = surface.result.commands
    let children = surface.result.children
    let interior = surface.interior

    if interior.width <= 0 || interior.height <= 0 {
      return WidgetLayoutResult(bounds: context.bounds, commands: commands, children: children)
    }

    var currentRow = interior.row

    if title.isEmpty == false {
      renderCentered(text: title, row: currentRow, bounds: interior, style: titleStyle, commands: &commands)
      currentRow = min(currentRow + 1, interior.maxRow)
    }

    if let prompt = prompt, prompt.isEmpty == false {
      renderCentered(text: prompt, row: currentRow, bounds: interior, style: contentStyle, commands: &commands)
      currentRow = min(currentRow + 1, interior.maxRow)
    }

    let fieldRowLimit = surface.buttonRow.map { max(interior.row, $0 - 1) } ?? interior.maxRow
    let fieldRow      = min(currentRow, fieldRowLimit)
    renderField(row: fieldRow, bounds: interior, commands: &commands)

    return WidgetLayoutResult(bounds: context.bounds, commands: commands, children: children)
  }

  private func renderCentered ( text: String, row: Int, bounds: BoxBounds, style: ColorPair, commands: inout [RenderCommand] ) {
    guard bounds.width > 0 else { return }
    let usableText = text.prefix(bounds.width)
    let offset     = max(0, (bounds.width - usableText.count) / 2)
    let start      = bounds.column + offset

    for (index, character) in usableText.enumerated() {
      commands.append(
        RenderCommand(
          row   : row,
          column: start + index,
          tile  : SurfaceTile(
            character : character,
            attributes: style
          )
        )
      )
    }
  }

  private func renderField ( row: Int, bounds: BoxBounds, commands: inout [RenderCommand] ) {
    guard bounds.width > 0 else { return }
    let maxColumn    = bounds.maxCol
    let startColumn  = bounds.column
    let characters   = Array(text)
    let maximumCaret = max(0, min(bounds.width - 1, characters.count))
    let caret        = max(0, min(caretIndex, maximumCaret))

    for offset in 0..<bounds.width {
      let column    = startColumn + offset
      if column > maxColumn { break }
      let character : Character

      if offset < characters.count {
        character = characters[offset]
      } else {
        character = " "
      }

      let attributes = offset == caret ? caretStyle : fieldStyle
      commands.append(
        RenderCommand(
          row   : row,
          column: column,
          tile  : SurfaceTile(
            character : character,
            attributes: attributes
          )
        )
      )
    }
  }
}

public extension TextEntryBox {
  static func preferredSize ( title: String, prompt: String?, text: String, buttons: [TextEntryBoxButton], minimumFieldWidth: Int = 1 ) -> (width: Int, height: Int) {
    let promptWidth   = prompt.map { $0.count } ?? 0
    let fieldWidth    = max(minimumFieldWidth, text.count + 1)
    let contentWidths = [title.count, promptWidth, fieldWidth]
    let maxContent    = contentWidths.max() ?? 0

    var contentHeight = 1
    if title.isEmpty == false { contentHeight += 1 }
    if let prompt = prompt, prompt.isEmpty == false { contentHeight += 1 }

    return ModalDialogSurface.preferredSize(
      contentWidth : maxContent,
      contentHeight: contentHeight,
      buttonTitles : buttons.map { $0.text }
    )
  }

  static func centeredBounds ( title: String, prompt: String?, text: String, buttons: [TextEntryBoxButton], minimumFieldWidth: Int = 1, in container: BoxBounds ) -> BoxBounds {
    let promptWidth   = prompt.map { $0.count } ?? 0
    let fieldWidth    = max(minimumFieldWidth, text.count + 1)
    let contentWidths = [title.count, promptWidth, fieldWidth]
    let maxContent    = contentWidths.max() ?? 0

    var contentHeight = 1
    if title.isEmpty == false { contentHeight += 1 }
    if let prompt = prompt, prompt.isEmpty == false { contentHeight += 1 }

    return ModalDialogSurface.centeredBounds(
      contentWidth : maxContent,
      contentHeight: contentHeight,
      buttonTitles : buttons.map { $0.text },
      in           : container
    )
  }
}
