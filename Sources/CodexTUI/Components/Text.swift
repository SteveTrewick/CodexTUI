import Foundation

public struct Label : Widget {
  public var content    : String
  public var style      : ColorPair
  public var alignment  : HorizontalAlignment

  public init ( _ content: String, style: ColorPair = ColorPair(), alignment: HorizontalAlignment = .leading ) {
    self.content   = content
    self.style     = style
    self.alignment = alignment
  }

  public func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    guard context.bounds.width > 0 && context.bounds.height > 0 else {
      return WidgetLayoutResult(bounds: context.bounds)
    }

    let usableWidth = max(0, context.bounds.width)
    let truncated   = String(content.prefix(usableWidth))
    let row         = context.bounds.row
    let height      = min(1, context.bounds.height)

    let originColumn : Int
    if truncated.isEmpty {
      originColumn = context.bounds.column
    } else {
      switch alignment {
        case .leading  : originColumn = context.bounds.column
        case .center   : originColumn = context.bounds.column + max(0, (usableWidth - truncated.count) / 2)
        case .trailing : originColumn = context.bounds.maxCol - truncated.count + 1
      }
    }

    var commands = [RenderCommand]()
    commands.reserveCapacity(truncated.count)

    for (index, character) in truncated.enumerated() {
      commands.append(
        RenderCommand(
          row   : row,
          column: originColumn + index,
          tile  : SurfaceTile(
            character : character,
            attributes: style
          )
        )
      )
    }

    let bounds = BoxBounds(row: row, column: originColumn, width: truncated.count, height: height)
    return WidgetLayoutResult(bounds: bounds, commands: commands)
  }
}

public typealias Text = Label
