import Foundation

/// Composite widget that renders a bordered panel with a bold title and wrapped body text. The panel
/// mirrors the styling previously used in the showcase workspace, encapsulating the window chrome
/// border, title emphasis and word wrapping so callers only provide the textual content.
public struct Panel : Widget {
  public var title     : String
  public var bodyLines : [String]
  public var theme     : Theme

  public init ( title: String, bodyLines: [String], theme: Theme ) {
    self.title     = title
    self.bodyLines = bodyLines
    self.theme     = theme
  }

  public func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    let bounds = context.bounds

    guard bounds.width > 0 && bounds.height > 0 else {
      return WidgetLayoutResult(bounds: bounds)
    }

    var children = [WidgetLayoutResult]()

    let border = Box(bounds: bounds, style: theme.windowChrome)
    children.append(border.layout(in: context))

    var titleStyle = theme.contentDefault
    titleStyle.style.insert(.bold)

    let bodyStyle   = theme.contentDefault
    let insetRow    = bounds.row + 1
    let insetColumn = bounds.column + 2
    let maxRow      = bounds.maxRow - 1
    let usableWidth = max(0, bounds.width - 4)

    if insetRow <= maxRow {
      let titleText = Text(title, origin: (row: insetRow, column: insetColumn), style: titleStyle)
      children.append(titleText.layout(in: context))
    }

    var currentRow = insetRow + 2

    for line in bodyLines {
      guard currentRow <= maxRow else { break }

      let fragments = wrapLine(line, width: usableWidth)

      if fragments.isEmpty {
        guard usableWidth > 0 && currentRow <= maxRow else { continue }

        let emptyLine = Text("", origin: (row: currentRow, column: insetColumn), style: bodyStyle)
        children.append(emptyLine.layout(in: context))
        currentRow += 1

        continue
      }

      for fragment in fragments {
        guard currentRow <= maxRow else { break }

        let bodyText = Text(fragment, origin: (row: currentRow, column: insetColumn), style: bodyStyle)
        children.append(bodyText.layout(in: context))
        currentRow += 1
      }
    }

    return WidgetLayoutResult(bounds: bounds, children: children)
  }

  private func wrapLine ( _ line: String, width: Int ) -> [String] {
    guard width > 0 else { return [] }

    var fragments = [String]()
    var start     = line.startIndex

    while start < line.endIndex {
      while start < line.endIndex && line[start].isWhitespace {
        start = line.index(after: start)
      }

      guard start < line.endIndex else { break }

      let limit = line.index(start, offsetBy: width, limitedBy: line.endIndex) ?? line.endIndex
      var end   = limit

      if limit < line.endIndex {
        var search = limit
        var found  = false

        while search > start {
          search = line.index(before: search)

          if line[search].isWhitespace {
            end   = search
            found = true
            break
          }
        }

        if found {
          let fragment = line[start..<end]

          if fragment.isEmpty == false {
            fragments.append(String(fragment))
          }

          start = line.index(after: end)

          while start < line.endIndex && line[start].isWhitespace {
            start = line.index(after: start)
          }

          continue
        }
      }

      let fragment = line[start..<end]

      if fragment.isEmpty == false {
        fragments.append(String(fragment))
      }

      start = end
    }

    return fragments
  }
}
