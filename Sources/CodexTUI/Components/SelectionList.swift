import Foundation

public struct SelectionList : Widget {
  public var title          : String
  public var entries        : [SelectionListEntry]
  public var selectionIndex : Int
  public var titleStyle     : ColorPair
  public var style          : ColorPair
  public var highlightStyle : ColorPair
  public var borderStyle    : ColorPair

  public init ( title: String, entries: [SelectionListEntry], selectionIndex: Int = 0, titleStyle: ColorPair, style: ColorPair, highlightStyle: ColorPair, borderStyle: ColorPair ) {
    self.title          = title
    self.entries        = entries
    self.selectionIndex = selectionIndex
    self.titleStyle     = titleStyle
    self.style          = style
    self.highlightStyle = highlightStyle
    self.borderStyle    = borderStyle
  }

  public func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    let headerRows = title.isEmpty ? 0 : 1
    let surface    = SelectionListSurface.layout(
      entries        : entries,
      selectionIndex : selectionIndex,
      style          : style,
      highlightStyle : highlightStyle,
      borderStyle    : borderStyle,
      contentOffset  : headerRows,
      in             : context
    )

    var commands  = surface.result.commands
    let children  = surface.result.children
    let bounds    = surface.result.bounds
    let interior  = surface.interior

    if headerRows > 0 && interior.width > 0 {
      renderTitle(in: interior, commands: &commands)
    }

    return WidgetLayoutResult(bounds: bounds, commands: commands, children: children)
  }

  private func renderTitle ( in interior: BoxBounds, commands: inout [RenderCommand] ) {
    guard interior.width > 0 else { return }
    let usableTitle = title.prefix(interior.width)
    let offset      = max(0, (interior.width - usableTitle.count) / 2)
    let start       = interior.column + offset
    let row         = interior.row

    for (index, character) in usableTitle.enumerated() {
      commands.append(
        RenderCommand(
          row   : row,
          column: start + index,
          tile  : SurfaceTile(
            character : character,
            attributes: titleStyle
          )
        )
      )
    }
  }
}

public extension SelectionList {
  static func preferredSize ( title: String, entries: [SelectionListEntry] ) -> (width: Int, height: Int) {
    let headerRows   = title.isEmpty ? 0 : 1
    let contentWidth = max(SelectionListSurface.contentWidth(for: entries), title.count)
    return SelectionListSurface.preferredSize(
      for                   : entries,
      preferredContentWidth : contentWidth,
      headerRows            : headerRows
    )
  }

  static func centeredBounds ( title: String, entries: [SelectionListEntry], in container: BoxBounds ) -> BoxBounds {
    let size   = preferredSize(title: title, entries: entries)
    let width  = min(size.width, container.width)
    let height = min(size.height, container.height)
    let bounds = BoxBounds(row: 1, column: 1, width: width, height: height)
    return bounds.aligned(horizontal: .center, vertical: .center, inside: container)
  }
}
