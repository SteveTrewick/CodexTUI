import Foundation

public struct HStack : Widget {
  public var spacing  : Int
  public var children : [AnyWidget]

  public init ( spacing: Int = 0, @WidgetBuilder content: () -> [AnyWidget] ) {
    self.spacing  = spacing
    self.children = content()
  }

  public func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    guard context.bounds.width > 0 else {
      return WidgetLayoutResult(bounds: context.bounds)
    }

    var cursorColumn = context.bounds.column
    let maxColumn    = context.bounds.maxCol
    var layouts      = [WidgetLayoutResult]()
    layouts.reserveCapacity(children.count)

    for (index, child) in children.enumerated() {
      guard cursorColumn <= maxColumn else { break }

      let remainingWidth = max(0, maxColumn - cursorColumn + 1)
      guard remainingWidth > 0 else { break }

      let childBounds = BoxBounds(
        row    : context.bounds.row,
        column : cursorColumn,
        width  : remainingWidth,
        height : context.bounds.height
      )

      var childContext = context
      childContext.bounds = childBounds

      let layout = child.layout(in: childContext)
      layouts.append(layout)

      let consumedWidth = layout.bounds.width
      let nextColumn    = layout.bounds.maxCol + 1

      if consumedWidth <= 0 {
        cursorColumn = min(maxColumn + 1, cursorColumn + 1)
      } else {
        let proposed = max(cursorColumn + consumedWidth, nextColumn)
        cursorColumn = min(maxColumn + 1, proposed)
      }

      if index < children.count - 1 {
        cursorColumn = min(maxColumn + 1, cursorColumn + spacing)
      }
    }

    return WidgetLayoutResult(bounds: context.bounds, children: layouts)
  }
}
