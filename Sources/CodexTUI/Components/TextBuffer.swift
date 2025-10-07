import Foundation

/// Scrollable text view that optionally participates in focus traversal. The buffer stores rendered
/// lines and exposes a layout routine that clips and offsets the visible region to simulate scrolling
/// without mutating the underlying content.
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

  // Exposes the focus metadata the focus chain uses to manage traversal.
  public func focusNode () -> FocusNode {
    return FocusNode(identifier: focusIdentifier, isEnabled: isInteractive, acceptsTab: true)
  }

  public func append ( line: String ) {
    lines.append(line)
    scrollOffset  = max(0, lines.count - 1)
  }

  /// Renders the text buffer into the supplied bounds. The layout routine first applies any content
  /// insets from the environment to determine the drawable interior, then clamps the scroll offset so
  /// we never read past the buffer. It walks the visible slice of lines, emitting commands for each
  /// character until the horizontal limit is reached, which mirrors how a terminal would clip output
  /// in hardware.
  public func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    let bounds    = context.bounds.inset(by: context.environment.contentInsets)
    let maxLines  = max(0, bounds.height)
    let maxOffset = max(0, lines.count - maxLines)
    scrollOffset  = min(maxOffset, max(0, scrollOffset))
    let startLine = scrollOffset
    var commands  = [RenderCommand]()

    // Calculate the visible slice of lines then copy characters until we hit the horizontal limit.
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
