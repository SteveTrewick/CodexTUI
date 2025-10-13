import Foundation

@resultBuilder
public enum WidgetBuilder {
  public static func buildBlock ( _ components: [AnyWidget]... ) -> [AnyWidget] {
    var flattened = [AnyWidget]()
    flattened.reserveCapacity(components.reduce(0) { $0 + $1.count })

    for component in components {
      flattened.append(contentsOf: component)
    }

    return flattened
  }

  public static func buildExpression <Wrapped: Widget> ( _ expression: Wrapped ) -> [AnyWidget] {
    return [AnyWidget(expression)]
  }

  public static func buildExpression ( _ expression: AnyWidget ) -> [AnyWidget] {
    return [expression]
  }

  public static func buildExpression ( _ expression: [AnyWidget] ) -> [AnyWidget] {
    return expression
  }

  public static func buildOptional ( _ component: [AnyWidget]? ) -> [AnyWidget] {
    return component ?? []
  }

  public static func buildEither ( first component: [AnyWidget] ) -> [AnyWidget] {
    return component
  }

  public static func buildEither ( second component: [AnyWidget] ) -> [AnyWidget] {
    return component
  }

  public static func buildArray ( _ components: [[AnyWidget]] ) -> [AnyWidget] {
    var flattened = [AnyWidget]()
    flattened.reserveCapacity(components.reduce(0) { $0 + $1.count })

    for component in components {
      flattened.append(contentsOf: component)
    }

    return flattened
  }

  public static func buildLimitedAvailability ( _ component: [AnyWidget] ) -> [AnyWidget] {
    return component
  }

  public static func buildFinalResult ( _ component: [AnyWidget] ) -> [AnyWidget] {
    return component
  }
}

public func assembleWidget ( from children: [AnyWidget] ) -> AnyWidget {
  guard children.count > 1 else { return children.first ?? AnyWidget(EmptyWidget()) }
  return AnyWidget(OverlayStack(children: children))
}

private struct EmptyWidget : Widget {
  func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    return WidgetLayoutResult(bounds: context.bounds)
  }
}
