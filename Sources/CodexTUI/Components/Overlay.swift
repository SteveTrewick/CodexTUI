import Foundation

public struct Overlay : Widget {
  public var content : AnyWidget
  public var bounds  : BoxBounds

  public init ( bounds: BoxBounds, content: AnyWidget ) {
    self.bounds  = bounds
    self.content = content
  }

  public func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    let childContext = LayoutContext(bounds: bounds, theme: context.theme, focus: context.focus, environment: context.environment)
    let childLayout  = content.layout(in: childContext)
    return WidgetLayoutResult(bounds: bounds, commands: childLayout.commands, children: childLayout.children)
  }
}
