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
  public var onNeedsDisplay  : ( () -> Void )?

  public private(set) var textIOChannel : TextIOChannel?

  private var lineSeparator        : String
  private var pendingLineFragment  : String
  private var hasPendingDisplayLine: Bool

  public init ( identifier: FocusIdentifier, lines: [String] = [], scrollOffset: Int = 0, style: ColorPair = ColorPair(), highlightStyle: ColorPair = ColorPair(), isInteractive: Bool = false ) {
    self.focusIdentifier = identifier
    self.lines           = lines
    self.scrollOffset    = scrollOffset
    self.style           = style
    self.highlightStyle  = highlightStyle
    self.isInteractive   = isInteractive
    self.onNeedsDisplay  = nil
    self.textIOChannel   = nil
    self.lineSeparator        = "\n"
    self.pendingLineFragment  = ""
    self.hasPendingDisplayLine = false
  }

  // Exposes the focus metadata the focus chain uses to manage traversal.
  public func focusNode () -> FocusNode {
    return FocusNode(identifier: focusIdentifier, isEnabled: isInteractive, acceptsTab: true)
  }

  public func append ( line: String ) {
    lines.append(line)
    scrollOffset  = max(0, lines.count - 1)
  }

  public func attach ( channel: TextIOChannel, lineSeparator: String = "\n" ) {
    textIOChannel?.delegate = nil
    textIOChannel          = channel
    self.lineSeparator        = lineSeparator.isEmpty ? "\n" : lineSeparator
    pendingLineFragment       = ""
    hasPendingDisplayLine     = false
    channel.delegate          = self
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

extension TextBuffer : TextIOChannelDelegate {
  public func textIOChannel ( _ channel: TextIOChannel, didReceive fragment: String ) {
    guard channel === textIOChannel else { return }
    guard fragment.isEmpty == false else { return }

    applyIncoming(fragment: fragment)
  }

  private func applyIncoming ( fragment: String ) {
    var changed = false
    let separator = lineSeparator

    if separator.isEmpty {
      changed = updatePendingLine(with: pendingLineFragment + fragment) || changed
    } else {
      let buffer   = pendingLineFragment + fragment
      let segments = buffer.components(separatedBy: separator)

      guard segments.isEmpty == false else { return }

      for index in 0..<(segments.count - 1) {
        changed = finalizePendingLine(with: segments[index]) || changed
      }

      let trailing = segments.last ?? ""
      if trailing.isEmpty {
        changed = clearPendingLine() || changed
      } else {
        changed = updatePendingLine(with: trailing) || changed
      }
    }

    if changed {
      onNeedsDisplay?()
    }
  }

  @discardableResult
  private func finalizePendingLine ( with text: String ) -> Bool {
    if hasPendingDisplayLine, lines.isEmpty == false {
      lines[lines.count - 1] = text
    } else {
      lines.append(text)
    }
    pendingLineFragment   = ""
    hasPendingDisplayLine = false
    scrollOffset          = max(0, lines.count - 1)
    return true
  }

  @discardableResult
  private func updatePendingLine ( with text: String ) -> Bool {
    pendingLineFragment = text

    guard text.isEmpty == false else { return clearPendingLine() }

    if hasPendingDisplayLine {
      if lines.isEmpty == false {
        lines[lines.count - 1] = text
      } else {
        lines.append(text)
      }
    } else {
      lines.append(text)
      hasPendingDisplayLine = true
    }

    scrollOffset = max(0, lines.count - 1)
    return true
  }

  @discardableResult
  private func clearPendingLine () -> Bool {
    pendingLineFragment = ""
    guard hasPendingDisplayLine else { return false }
    if lines.isEmpty == false {
      lines.removeLast()
    }
    hasPendingDisplayLine = false
    scrollOffset          = max(0, lines.count - 1)
    return true
  }
}
