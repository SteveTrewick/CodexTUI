import Foundation

public final class TextBuffer : FocusableWidget {
  public var focusIdentifier : FocusIdentifier
  public var lines           : [String]
  public var scrollOffset    : Int
  public var style           : ColorPair
  public var highlightStyle  : ColorPair
  public var isInteractive   : Bool

  public init ( identifier: FocusIdentifier, lines: [String] = [], scrollOffset: Int = 0, style: ColorPair = ColorPair(), highlightStyle: ColorPair = ColorPair(), isInteractive: Bool = false ) {
    self.focusIdentifier = identifier
    self.lines           = lines
    self.scrollOffset    = scrollOffset
    self.style           = style
    self.highlightStyle  = highlightStyle
    self.isInteractive   = isInteractive
  }

  public func focusNode () -> FocusNode {
    return FocusNode(identifier: focusIdentifier, isEnabled: isInteractive, acceptsTab: true)
  }

  public func append ( line: String ) {
    lines.append(line)
  }

  public func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    let bounds    = context.bounds.inset(by: context.environment.contentInsets)
    let maxLines  = max(0, bounds.height)
    let startLine = max(0, min(lines.count - maxLines, scrollOffset))
    var commands  = [RenderCommand]()

    for visibleIndex in 0..<maxLines {
      let lineIndex = startLine + visibleIndex
      guard lineIndex < lines.count else { break }
      let line = lines[lineIndex]
      let row  = bounds.row + visibleIndex

      for (columnOffset, character) in line.enumerated() where columnOffset < bounds.width {
        let column = bounds.column + columnOffset
        commands.append(
          RenderCommand(
            row   : row,
            column: column,
            tile  : SurfaceTile(
              character : character,
              attributes: style
            )
          )
        )
      }
    }

    return WidgetLayoutResult(bounds: bounds, commands: commands)
  }
}
