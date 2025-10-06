import Foundation

// Composes menu, content and status bar regions into a vertically stacked layout.
public struct Scaffold : Widget {
  public var menuBar   : MenuBar?
  public var content   : AnyWidget
  public var statusBar : StatusBar?

  public init ( menuBar: MenuBar? = nil, content: AnyWidget, statusBar: StatusBar? = nil ) {
    self.menuBar   = menuBar
    self.content   = content
    self.statusBar = statusBar
  }

  public func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    var children = [WidgetLayoutResult]()
    let rootBounds = context.bounds

    var contentTop    = rootBounds.row
    var contentBottom = rootBounds.maxRow

    // Attach a menu bar if present and shift the content area down by one line.
    if let menuBar = menuBar {
      let menuBounds  = BoxBounds(row: rootBounds.row, column: rootBounds.column, width: rootBounds.width, height: 1)
      let menuContext = LayoutContext(bounds: menuBounds, theme: context.theme, focus: context.focus, environment: context.environment)
      let menuLayout  = menuBar.layout(in: menuContext)
      children.append(menuLayout)
      contentTop += 1
    }

    // Anchor the status bar to the bottom edge and shrink the content space accordingly.
    if let statusBar = statusBar {
      let statusBounds  = BoxBounds(row: rootBounds.maxRow, column: rootBounds.column, width: rootBounds.width, height: 1)
      let statusContext = LayoutContext(bounds: statusBounds, theme: context.theme, focus: context.focus, environment: context.environment)
      let statusLayout  = statusBar.layout(in: statusContext)
      children.append(statusLayout)
      contentBottom -= 1
    }

    if contentBottom < contentTop {
      contentBottom = contentTop
    }

    // The remaining area is dedicated to the primary content widget.
    let contentBounds = BoxBounds(row: contentTop, column: rootBounds.column, width: rootBounds.width, height: max(0, contentBottom - contentTop + 1))
    let contentContext = LayoutContext(bounds: contentBounds, theme: context.theme, focus: context.focus, environment: context.environment)
    let contentLayout  = content.layout(in: contentContext)
    children.append(contentLayout)

    return WidgetLayoutResult(bounds: rootBounds, children: children)
  }
}
