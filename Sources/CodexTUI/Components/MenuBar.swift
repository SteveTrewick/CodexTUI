import Foundation
import TerminalInput

/// Alignment strategy for positioning menu items inside the menu bar. Leading items flow from the
/// left edge while trailing items are packed against the right edge.
public enum MenuItemAlignment {
  case leading
  case trailing
}

@resultBuilder
public struct MenuItemBuilder {
  public static func buildBlock ( _ components: [MenuItem]... ) -> [MenuItem] {
    return components.flatMap { $0 }
  }

  public static func buildExpression ( _ expression: MenuItem ) -> [MenuItem] {
    return [expression]
  }

  public static func buildExpression ( _ expression: [MenuItem] ) -> [MenuItem] {
    return expression
  }

  public static func buildOptional ( _ component: [MenuItem]? ) -> [MenuItem] {
    return component ?? []
  }

  public static func buildEither ( first component: [MenuItem] ) -> [MenuItem] {
    return component
  }

  public static func buildEither ( second component: [MenuItem] ) -> [MenuItem] {
    return component
  }

  public static func buildArray ( _ components: [[MenuItem]] ) -> [MenuItem] {
    return components.flatMap { $0 }
  }

  public static func buildLimitedAvailability ( _ component: [MenuItem] ) -> [MenuItem] {
    return component
  }
}

@resultBuilder
public struct MenuEntryBuilder {
  public static func buildBlock ( _ components: [MenuItem.Entry]... ) -> [MenuItem.Entry] {
    return components.flatMap { $0 }
  }

  public static func buildExpression ( _ expression: MenuItem.Entry ) -> [MenuItem.Entry] {
    return [expression]
  }

  public static func buildExpression ( _ expression: [MenuItem.Entry] ) -> [MenuItem.Entry] {
    return expression
  }

  public static func buildOptional ( _ component: [MenuItem.Entry]? ) -> [MenuItem.Entry] {
    return component ?? []
  }

  public static func buildEither ( first component: [MenuItem.Entry] ) -> [MenuItem.Entry] {
    return component
  }

  public static func buildEither ( second component: [MenuItem.Entry] ) -> [MenuItem.Entry] {
    return component
  }

  public static func buildArray ( _ components: [[MenuItem.Entry]] ) -> [MenuItem.Entry] {
    return components.flatMap { $0 }
  }

  public static func buildLimitedAvailability ( _ component: [MenuItem.Entry] ) -> [MenuItem.Entry] {
    return component
  }
}

/// Describes a single interactive menu bar item, including its accelerator token, alignment and
/// dropdown entries. The structure is intentionally value-based so scenes can easily diff and update
/// menu state.
public struct MenuItem : Equatable {
  /// Represents a selectable entry inside a menu item's dropdown list.
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

  public init ( title: String, activationKey: TerminalInput.Token, alignment: MenuItemAlignment = .leading, isHighlighted: Bool = false, isOpen: Bool = false, @MenuEntryBuilder entries: () -> [Entry] ) {
    self.init(
      title        : title,
      activationKey: activationKey,
      alignment    : alignment,
      isHighlighted: isHighlighted,
      isOpen       : isOpen,
      entries      : entries()
    )
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

/// Widget that renders a single-line menu bar. It handles background clearing, accelerator
/// highlighting and left/right alignment rules for menu items.
public struct MenuBar : Widget {
  public var items            : [MenuItem]
  public var barStyleOverride         : ColorPair?
  public var highlightStyleOverride   : ColorPair?
  public var dimHighlightStyleOverride: ColorPair?

  public init ( items: [MenuItem], style: ColorPair, highlightStyle: ColorPair, dimHighlightStyle: ColorPair ) {
    self.items                       = items
    self.barStyleOverride            = style
    self.highlightStyleOverride      = highlightStyle
    self.dimHighlightStyleOverride   = dimHighlightStyle
  }

  public init ( items: [MenuItem], barStyle: ColorPair? = nil, highlightStyle: ColorPair? = nil, dimHighlightStyle: ColorPair? = nil ) {
    self.items                       = items
    self.barStyleOverride            = barStyle
    self.highlightStyleOverride      = highlightStyle
    self.dimHighlightStyleOverride   = dimHighlightStyle
  }

  public init ( barStyle: ColorPair? = nil, highlightStyle: ColorPair? = nil, dimHighlightStyle: ColorPair? = nil, @MenuItemBuilder items: () -> [MenuItem] ) {
    self.items                       = items()
    self.barStyleOverride            = barStyle
    self.highlightStyleOverride      = highlightStyle
    self.dimHighlightStyleOverride   = dimHighlightStyle
  }

  /// Renders the menu bar within the supplied bounds. The routine first paints a solid background
  /// across the entire row so gaps never appear between items. It then walks the leading items from
  /// left to right updating a cursor as titles are written, and finally walks the trailing items in
  /// reverse so they pack neatly against the right edge without requiring prior measurements. Each
  /// item is rendered via `render(item:row:column:)`, which decides whether to use highlight colours
  /// based on the item's state.
  public func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    let barStyle        = barStyleOverride ?? context.theme.menuBar
    let highlightStyle  = highlightStyleOverride ?? context.theme.highlight
    let dimHighlight    = dimHighlightStyleOverride ?? context.theme.dimHighlight
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
              attributes: barStyle
            )
          )
        )
      }
    }

    // Leading entries are emitted left-to-right, adding a space between each title.
    for item in items where item.alignment == .leading {
      commands.append(contentsOf: render(item: item, row: row, column: leftColumn, barStyle: barStyle, highlightStyle: highlightStyle, dimHighlightStyle: dimHighlight))
      leftColumn += item.title.count + 2
    }

    // Trailing entries are walked in reverse so the right edge is packed tightly without layout maths for preceding items.
    for item in items.reversed() where item.alignment == .trailing {
      let start = rightColumn - item.title.count
      commands.append(contentsOf: render(item: item, row: row, column: start, barStyle: barStyle, highlightStyle: highlightStyle, dimHighlightStyle: dimHighlight))
      rightColumn = start - 2
    }

    return WidgetLayoutResult(bounds: BoxBounds(row: row, column: context.bounds.column, width: context.bounds.width, height: 1), commands: commands)
  }

  private func render ( item: MenuItem, row: Int, column: Int, barStyle: ColorPair, highlightStyle: ColorPair, dimHighlightStyle: ColorPair ) -> [RenderCommand] {
    var commands = [RenderCommand]()
    let characters = Array(item.title)

    for (index, character) in characters.enumerated() {
      let isFirst    = index == 0
      let attributes : ColorPair

      if item.isOpen {
        attributes = highlightStyle
      } else if isFirst {
        attributes = highlightAttributes(for: item, highlightStyle: highlightStyle, dimHighlightStyle: dimHighlightStyle)
      } else {
        attributes = barStyle
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

  private func highlightAttributes ( for item: MenuItem, highlightStyle: ColorPair, dimHighlightStyle: ColorPair ) -> ColorPair {
    if item.isOpen { return highlightStyle }
    return item.isHighlighted ? highlightStyle : dimHighlightStyle
  }
}
