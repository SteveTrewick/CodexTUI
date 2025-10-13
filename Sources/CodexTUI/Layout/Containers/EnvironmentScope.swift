import Foundation

public struct EnvironmentScope : Widget {
  public var modifier : (inout EnvironmentValues) -> Void
  public var content  : AnyWidget

  public init ( applying modifier: @escaping (inout EnvironmentValues) -> Void, @WidgetBuilder content: () -> [AnyWidget] ) {
    self.modifier = modifier
    self.content  = assembleWidget(from: content())
  }

  public func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    var childContext = context
    modifier(&childContext.environment)
    let layout = content.layout(in: childContext)
    return WidgetLayoutResult(bounds: layout.bounds, commands: layout.commands, children: layout.children)
  }
}
