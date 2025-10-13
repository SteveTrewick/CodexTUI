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

    let border   = Box(style: theme.windowChrome)
    var titleStyle = theme.contentDefault
    titleStyle.style.insert(.bold)
    let bodyStyle   = theme.contentDefault
    let interior    = bounds.inset(by: EdgeInsets(top: 1, leading: 2, bottom: 1, trailing: 2))
    let usableWidth = max(0, interior.width)
    let available   = max(0, interior.height)

    var descriptors = [(String, ColorPair)]()
    var remaining   = available

    if remaining > 0 {
      descriptors.append((title, titleStyle))
      remaining -= 1
    }

    if remaining > 0 {
      descriptors.append(("", bodyStyle))
      remaining -= 1
    }

    if remaining > 0 && usableWidth > 0 {
      outer: for line in bodyLines {
        let fragments = wrapLine(line, width: usableWidth)

        if fragments.isEmpty {
          guard remaining > 0 else { break }
          descriptors.append(("", bodyStyle))
          remaining -= 1
          continue
        }

        for fragment in fragments {
          guard remaining > 0 else { break outer }
          descriptors.append((fragment, bodyStyle))
          remaining -= 1
        }
      }
    }

    let overlay = OverlayStack {
      border
      if descriptors.isEmpty == false {
        Padding(top: 1, leading: 2, bottom: 1, trailing: 2) {
          VStack(spacing: 0) {
            for descriptor in descriptors {
              Label(descriptor.0, style: descriptor.1)
            }
          }
        }
      }
    }

    return overlay.layout(in: context)
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
