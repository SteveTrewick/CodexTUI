import Foundation
import TerminalInput

public enum MenuItemAlignment {
  case leading
  case trailing
}

// Describes a single interactive item within the menu bar.
public struct MenuItem : Equatable {
  public struct Entry : Equatable {
    public var title           : String
    public var acceleratorHint : String?
    public var action          : (() -> Void)?

    public init ( title: String, acceleratorHint: String? = nil, action: (() -> Void)? = nil ) {
      self.title           = title
      self.acceleratorHint = acceleratorHint
      self.action          = action
    }
  }

  public var title          : String
  public var activationKey  : TerminalInput.Token
  public var alignment      : MenuItemAlignment
  public var isHighlighted  : Bool
  public var isOpen         : Bool
  public var entries        : [Entry]

  public init ( title: String, activationKey: TerminalInput.Token, alignment: MenuItemAlignment = .leading, isHighlighted: Bool = false, isOpen: Bool = false, entries: [Entry] = [] ) {
    self.title         = title
    self.activationKey = activationKey
    self.alignment     = alignment
    self.isHighlighted = isHighlighted
    self.isOpen        = isOpen
    self.entries       = entries
  }

  public func matches ( token: TerminalInput.Token ) -> Bool {
    return activationKey == token
  }
}

public func == ( lhs: MenuItem.Entry, rhs: MenuItem.Entry ) -> Bool {
  return lhs.title == rhs.title && lhs.acceleratorHint == rhs.acceleratorHint
}

public func == ( lhs: MenuItem, rhs: MenuItem ) -> Bool {
  return lhs.title == rhs.title &&
    lhs.activationKey == rhs.activationKey &&
    lhs.alignment == rhs.alignment &&
    lhs.isHighlighted == rhs.isHighlighted &&
    lhs.isOpen == rhs.isOpen &&
    lhs.entries == rhs.entries
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
    let row          = context.bounds.row
    let startColumn  = context.bounds.column
    let endColumn    = context.bounds.maxCol
    var commands     = [RenderCommand]()
    var leftColumn   = startColumn
    var rightColumn  = context.bounds.maxCol + 1

    if startColumn <= endColumn {
      for column in startColumn...endColumn {
        commands.append(
          RenderCommand(
            row   : row,
            column: column,
            tile  : SurfaceTile(
              character : " ",
              attributes: style
            )
          )
        )
      }
    }

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
      let attributes : ColorPair

      if item.isOpen {
        attributes = highlightStyle
      } else if isFirst {
        attributes = highlightAttributes(for: item)
      } else {
        attributes = style
      }

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
    if item.isOpen { return highlightStyle }
    return item.isHighlighted ? highlightStyle : dimHighlightStyle
  }
}
