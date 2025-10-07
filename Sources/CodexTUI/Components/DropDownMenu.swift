import Foundation

// Renders a boxed list of menu entries and highlights the focused row.
public struct DropDownMenu : Widget {
  public var entries        : [MenuItem.Entry]
  public var selectionIndex : Int
  public var style          : ColorPair
  public var highlightStyle : ColorPair
  public var borderStyle    : ColorPair

  public init ( entries: [MenuItem.Entry], selectionIndex: Int = 0, style: ColorPair, highlightStyle: ColorPair, borderStyle: ColorPair ) {
    self.entries        = entries
    self.selectionIndex = selectionIndex
    self.style          = style
    self.highlightStyle = highlightStyle
    self.borderStyle    = borderStyle
  }

  public func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    let listEntries = entries.map { SelectionListEntry(menuEntry: $0) }
    let surface     = SelectionListSurface.layout(
      entries        : listEntries,
      selectionIndex : selectionIndex,
      style          : style,
      highlightStyle : highlightStyle,
      borderStyle    : borderStyle,
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
