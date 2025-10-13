import Foundation

public struct Padding : Widget {
  public var insets  : EdgeInsets
  public var content : AnyWidget

  public init ( _ insets: EdgeInsets = EdgeInsets(), @WidgetBuilder content: () -> [AnyWidget] ) {
    self.insets  = insets
    self.content = assembleWidget(from: content())
  }

  public init ( top: Int = 0, leading: Int = 0, bottom: Int = 0, trailing: Int = 0, @WidgetBuilder content: () -> [AnyWidget] ) {
    self.insets  = EdgeInsets(top: top, leading: leading, bottom: bottom, trailing: trailing)
    self.content = assembleWidget(from: content())
  }

  public func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    let insetBounds = context.bounds.inset(by: insets)
    var childContext = context
    childContext.bounds = insetBounds

    let childLayout = content.layout(in: childContext)
    return WidgetLayoutResult(bounds: context.bounds, children: [childLayout])
  }
}
