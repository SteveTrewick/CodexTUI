import Foundation

public struct RenderCommand : Equatable {
  public var row    : Int
  public var column : Int
  public var tile   : SurfaceTile

  public init ( row: Int, column: Int, tile: SurfaceTile ) {
    self.row    = row
    self.column = column
    self.tile   = tile
  }
}

public struct WidgetLayoutResult {
  public var bounds   : BoxBounds
  public var commands : [RenderCommand]
  public var children : [WidgetLayoutResult]

  public init ( bounds: BoxBounds, commands: [RenderCommand] = [], children: [WidgetLayoutResult] = [] ) {
    self.bounds   = bounds
    self.commands = commands
    self.children = children
  }

  public func flattenedCommands () -> [RenderCommand] {
    var combined = commands

    for child in children {
      combined.append(contentsOf: child.flattenedCommands())
    }

    return combined
  }
}

public protocol Widget {
  func layout ( in context: LayoutContext ) -> WidgetLayoutResult
}

public struct AnyWidget : Widget {
  private let layoutClosure : (LayoutContext) -> WidgetLayoutResult

  public init <Wrapped: Widget> ( _ wrapped: Wrapped ) {
    self.layoutClosure = wrapped.layout(in:)
  }

  public func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    return layoutClosure(context)
  }
}

public protocol FocusableWidget : Widget {
  var focusIdentifier : FocusIdentifier { get }
  func focusNode () -> FocusNode
}

public protocol OverlayPresentingWidget : Widget {
  var presentedOverlays : [AnyWidget] { get }
}
