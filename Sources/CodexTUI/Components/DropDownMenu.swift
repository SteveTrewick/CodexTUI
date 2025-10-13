import Foundation

/// Widget that shows a menu item's submenu as a boxed list. It is effectively a specialised
/// wrapper around `SelectionListSurface` that converts the menu entries into selection entries and
/// exposes a simplified API tailored for menu interactions.
public struct DropDownMenu : Widget {
  public var entries        : [MenuItem.Entry]
  public var selectionIndex : Int
  public var styleOverride          : ColorPair?
  public var highlightStyleOverride : ColorPair?
  public var borderStyleOverride    : ColorPair?

  public init ( entries: [MenuItem.Entry], selectionIndex: Int = 0, style: ColorPair, highlightStyle: ColorPair, borderStyle: ColorPair ) {
    self.entries        = entries
    self.selectionIndex = selectionIndex
    self.styleOverride          = style
    self.highlightStyleOverride = highlightStyle
    self.borderStyleOverride    = borderStyle
  }

  public init ( entries: [MenuItem.Entry], selectionIndex: Int = 0, style: ColorPair? = nil, highlightStyle: ColorPair? = nil, borderStyle: ColorPair? = nil ) {
    self.entries                 = entries
    self.selectionIndex          = selectionIndex
    self.styleOverride           = style
    self.highlightStyleOverride  = highlightStyle
    self.borderStyleOverride     = borderStyle
  }

  public init ( selectionIndex: Int = 0, style: ColorPair? = nil, highlightStyle: ColorPair? = nil, borderStyle: ColorPair? = nil, @MenuEntryBuilder entries: () -> [MenuItem.Entry] ) {
    self.entries                 = entries()
    self.selectionIndex          = selectionIndex
    self.styleOverride           = style
    self.highlightStyleOverride  = highlightStyle
    self.borderStyleOverride     = borderStyle
  }

  /// Delegates to `SelectionListSurface.layout` after converting the menu entries into the common
  /// selection list representation. The resulting layout mirrors the behaviour of the standalone
  /// selection list widget so the menu system benefits from the same scrolling, highlighting and
  /// border logic without duplicating calculations.
  public func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    let listEntries = entries.map { SelectionListEntry(menuEntry: $0) }
    let style        = styleOverride ?? context.theme.contentDefault
    let highlight    = highlightStyleOverride ?? context.theme.highlight
    let border       = borderStyleOverride ?? context.theme.windowChrome
    let surface     = SelectionListSurface.layout(
      entries        : listEntries,
      selectionIndex : selectionIndex,
      style          : style,
      highlightStyle : highlight,
      borderStyle    : border,
      in             : context
    )

    return surface.result
  }
}

public extension DropDownMenu {
  static func preferredSize ( for entries: [MenuItem.Entry] ) -> (width: Int, height: Int) {
    let listEntries = entries.map { SelectionListEntry(menuEntry: $0) }
    return SelectionListSurface.preferredSize(for: listEntries)
  }

  static func anchoredBounds ( for entries: [MenuItem.Entry], anchoredTo itemBounds: BoxBounds, in container: BoxBounds ) -> BoxBounds {
    let listEntries = entries.map { SelectionListEntry(menuEntry: $0) }
    return SelectionListSurface.anchoredBounds(for: listEntries, anchoredTo: itemBounds, in: container)
  }
}
