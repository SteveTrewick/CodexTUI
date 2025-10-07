import Foundation
import TerminalInput

public enum MenuItemAlignment {
  case leading
  case trailing
}

// Describes a single interactive item within the menu bar.
public struct MenuItem : Equatable {
  public var title          : String
  public var activationKey  : TerminalInput.Token
  public var alignment      : MenuItemAlignment
  public var isHighlighted  : Bool

  public init ( title: String, activationKey: TerminalInput.Token, alignment: MenuItemAlignment = .leading, isHighlighted: Bool = false ) {
    self.title         = title
    self.activationKey = activationKey
    self.alignment     = alignment
    self.isHighlighted = isHighlighted
  }

  public func matches ( token: TerminalInput.Token ) -> Bool {
    return activationKey == token
  }
}

// Renders a classic single line menu bar with highlighted accelerator characters.
public struct MenuBar : Widget {
  public var items            : [MenuItem]
  public var style            : ColorPair
  public var highlightStyle   : ColorPair
  public var dimHighlightStyle: ColorPair

  public init ( items: [MenuItem], style: ColorPair, highlightStyle: ColorPair, dimHighlightStyle: ColorPair ) {
    self.items             = items
    self.style             = style
    self.highlightStyle    = highlightStyle
    self.dimHighlightStyle = dimHighlightStyle
  }

  public func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    let row = context.bounds.row
    var commands = [RenderCommand]()

    var leftColumn  = context.bounds.column
    var rightColumn = context.bounds.maxCol + 1

    // Leading entries are emitted left-to-right, adding a space between each title.
    for item in items where item.alignment == .leading {
      commands.append(contentsOf: render(item: item, row: row, column: leftColumn))
      leftColumn += item.title.count + 2
    }

    // Trailing entries are walked in reverse so the right edge is packed tightly without layout maths for preceding items.
    for item in items.reversed() where item.alignment == .trailing {
      let start = rightColumn - item.title.count
      commands.append(contentsOf: render(item: item, row: row, column: start))
      rightColumn = start - 2
    }

    return WidgetLayoutResult(bounds: BoxBounds(row: row, column: context.bounds.column, width: context.bounds.width, height: 1), commands: commands)
  }

  private func render ( item: MenuItem, row: Int, column: Int ) -> [RenderCommand] {
    var commands = [RenderCommand]()
    let characters = Array(item.title)

    for (index, character) in characters.enumerated() {
      let isFirst    = index == 0
      let attributes = isFirst ? highlightAttributes(for: item) : style

      // The first character is styled using either a dim or active highlight to mimic accelerator hints.
      commands.append(
        RenderCommand(
          row   : row,
          column: column + index,
          tile  : SurfaceTile(
            character : character,
            attributes: attributes
          )
        )
      )
    }

    return commands
  }

  private func highlightAttributes ( for item: MenuItem ) -> ColorPair {
    return item.isHighlighted ? highlightStyle : dimHighlightStyle
  }
}
