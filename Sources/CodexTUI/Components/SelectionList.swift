import Foundation

@resultBuilder
public enum SelectionListEntryBuilder {
  public static func buildBlock ( _ components: [SelectionListEntry]... ) -> [SelectionListEntry] {
    return components.flatMap { $0 }
  }

  public static func buildExpression ( _ expression: SelectionListEntry ) -> [SelectionListEntry] {
    return [expression]
  }

  public static func buildExpression ( _ expression: [SelectionListEntry] ) -> [SelectionListEntry] {
    return expression
  }

  public static func buildOptional ( _ component: [SelectionListEntry]? ) -> [SelectionListEntry] {
    return component ?? []
  }

  public static func buildEither ( first component: [SelectionListEntry] ) -> [SelectionListEntry] {
    return component
  }

  public static func buildEither ( second component: [SelectionListEntry] ) -> [SelectionListEntry] {
    return component
  }

  public static func buildArray ( _ components: [[SelectionListEntry]] ) -> [SelectionListEntry] {
    return components.flatMap { $0 }
  }

  public static func buildLimitedAvailability ( _ component: [SelectionListEntry] ) -> [SelectionListEntry] {
    return component
  }
}

/// Composite widget that displays a titled selection list inside a bordered surface. It reuses the
/// shared `SelectionListSurface` to render the scrollable body and adds optional title rendering on
/// top of the calculated interior bounds.
public struct SelectionList : Widget {
  public var title                  : String
  public var entries                : [SelectionListEntry]
  public var selectionIndex         : Int
  public var titleStyleOverride     : ColorPair?
  public var contentStyleOverride   : ColorPair?
  public var highlightStyleOverride : ColorPair?
  public var borderStyleOverride    : ColorPair?

  public init ( title: String, selectionIndex: Int = 0, titleStyleOverride: ColorPair? = nil, contentStyleOverride: ColorPair? = nil, highlightStyleOverride: ColorPair? = nil, borderStyleOverride: ColorPair? = nil, @SelectionListEntryBuilder entries: () -> [SelectionListEntry] ) {
    self.title                  = title
    self.entries                = entries()
    self.selectionIndex         = selectionIndex
    self.titleStyleOverride     = titleStyleOverride
    self.contentStyleOverride   = contentStyleOverride
    self.highlightStyleOverride = highlightStyleOverride
    self.borderStyleOverride    = borderStyleOverride
  }

  public init ( title: String, entries: [SelectionListEntry], selectionIndex: Int = 0, titleStyle: ColorPair, style: ColorPair, highlightStyle: ColorPair, borderStyle: ColorPair ) {
    self.init(
      title                  : title,
      selectionIndex         : selectionIndex,
      titleStyleOverride     : titleStyle,
      contentStyleOverride   : style,
      highlightStyleOverride : highlightStyle,
      borderStyleOverride    : borderStyle,
      entries                : { entries }
    )
  }

  /// Lays out the selection list by delegating the heavy lifting to `SelectionListSurface`. The
  /// returned interior bounds are used to optionally render the header row, ensuring the title shares
  /// the same padding and centring rules as the list content. Control flow mirrors the surface helper:
  /// we quickly exit when there is no interior space and otherwise append the title commands before
  /// returning the combined layout tree.
  public func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    let headerRows             = title.isEmpty ? 0 : 1
    let resolvedContentStyle   = contentStyleOverride ?? context.theme.contentDefault
    let resolvedHighlightStyle = highlightStyleOverride ?? context.theme.highlight
    let resolvedBorderStyle    = borderStyleOverride ?? context.theme.windowChrome
    let resolvedTitleStyle     : ColorPair

    if let override = titleStyleOverride {
      resolvedTitleStyle = override
    } else {
      var defaultTitle = context.theme.contentDefault
      defaultTitle.style.insert(.bold)
      resolvedTitleStyle = defaultTitle
    }

    let surface    = SelectionListSurface.layout(
      entries        : entries,
      selectionIndex : selectionIndex,
      style          : resolvedContentStyle,
      highlightStyle : resolvedHighlightStyle,
      borderStyle    : resolvedBorderStyle,
      contentOffset  : headerRows,
      in             : context
    )

    var commands  = surface.result.commands
    let children  = surface.result.children
    let bounds    = surface.result.bounds
    let interior  = surface.interior

    if headerRows > 0 && interior.width > 0 {
      renderTitle(in: interior, style: resolvedTitleStyle, commands: &commands)
    }

    return WidgetLayoutResult(bounds: bounds, commands: commands, children: children)
  }

  private func renderTitle ( in interior: BoxBounds, style: ColorPair, commands: inout [RenderCommand] ) {
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
            attributes: style
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
