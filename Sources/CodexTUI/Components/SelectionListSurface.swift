import Foundation

public struct SelectionListEntry {
  public var title           : String
  public var acceleratorHint : String?
  public var action          : (() -> Void)?

  public init ( title: String, acceleratorHint: String? = nil, action: (() -> Void)? = nil ) {
    self.title           = title
    self.acceleratorHint = acceleratorHint
    self.action          = action
  }
}

public struct SelectionListSurfaceLayout {
  public var result   : WidgetLayoutResult
  public var interior : BoxBounds

  public init ( result: WidgetLayoutResult, interior: BoxBounds ) {
    self.result   = result
    self.interior = interior
  }
}

public enum SelectionListSurface {
  public static func layout (
    entries        : [SelectionListEntry],
    selectionIndex : Int,
    style          : ColorPair,
    highlightStyle : ColorPair,
    borderStyle    : ColorPair,
    contentOffset  : Int = 0,
    in context     : LayoutContext
  ) -> SelectionListSurfaceLayout {
    let bounds    = context.bounds
    let box       = Box(bounds: bounds, style: borderStyle)
    let boxLayout = box.layout(in: context)
    var commands  = boxLayout.commands
    let children  = boxLayout.children
    let interior  = bounds.inset(by: EdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1))

    guard interior.width > 0 && interior.height > 0 else {
      let result = WidgetLayoutResult(bounds: bounds, commands: commands, children: children)
      return SelectionListSurfaceLayout(result: result, interior: interior)
    }

    let offset           = max(0, contentOffset)
    let availableRows    = max(0, interior.height - offset)
    let maxIndex         = max(0, entries.count - 1)
    let selectedIndex    = entries.isEmpty ? nil : max(0, min(selectionIndex, maxIndex))
    let entryStartRow    = interior.row + offset
    let interiorColumn   = interior.column
    let maxColumn        = interior.maxCol

    if offset > 0 {
      let headerLimit = min(interior.height, offset)
      for headerIndex in 0..<headerLimit {
        let row = interior.row + headerIndex
        for column in interiorColumn...maxColumn {
          commands.append(
            RenderCommand(
              row   : row,
              column: column,
              tile  : SurfaceTile(
                character : " ",
                attributes: style
              )
            )
          )
        }
      }
    }

    guard availableRows > 0 else {
      let result = WidgetLayoutResult(bounds: bounds, commands: commands, children: children)
      return SelectionListSurfaceLayout(result: result, interior: interior)
    }

    for (index, entry) in entries.enumerated() {
      guard index < availableRows else { break }
      let row        = entryStartRow + index
      let attributes = (index == selectedIndex) ? highlightStyle : style

      for column in interiorColumn...maxColumn {
        commands.append(
          RenderCommand(
            row   : row,
            column: column,
            tile  : SurfaceTile(
              character : " ",
              attributes: attributes
            )
          )
        )
      }

      var textColumn = interiorColumn
      for character in entry.title {
        guard textColumn <= maxColumn else { break }
        commands.append(
          RenderCommand(
            row   : row,
            column: textColumn,
            tile  : SurfaceTile(
              character : character,
              attributes: attributes
            )
          )
        )
        textColumn += 1
      }

      if let hint = entry.acceleratorHint, hint.isEmpty == false {
        let usableHint = hint.suffix(interior.width)
        let hintWidth  = usableHint.count
        let start      = max(interiorColumn, maxColumn - hintWidth + 1)
        for (offset, character) in usableHint.enumerated() {
          let column = start + offset
          guard column >= interiorColumn && column <= maxColumn else { continue }
          commands.append(
            RenderCommand(
              row   : row,
              column: column,
              tile  : SurfaceTile(
                character : character,
                attributes: attributes
              )
            )
          )
        }
      }
    }

    let result = WidgetLayoutResult(bounds: bounds, commands: commands, children: children)
    return SelectionListSurfaceLayout(result: result, interior: interior)
  }

  public static func preferredSize (
    for entries   : [SelectionListEntry],
    preferredContentWidth : Int? = nil,
    headerRows    : Int = 0,
    minimumWidth  : Int = 4,
    minimumHeight : Int = 2
  ) -> (width: Int, height: Int) {
    let measuredContent = max(preferredContentWidth ?? 0, contentWidth(for: entries))
    let width           = max(minimumWidth, measuredContent + 2)
    let height          = max(minimumHeight, entries.count + headerRows + 2)
    return (width, height)
  }

  public static func contentWidth ( for entries: [SelectionListEntry] ) -> Int {
    let maxTitle = entries.map { $0.title.count }.max() ?? 0
    let maxHint  = entries.map { $0.acceleratorHint?.count ?? 0 }.max() ?? 0
    let hintGap  : Int
    if maxHint > 0 && maxTitle > 0 { hintGap = 2 }
    else if maxHint > 0 { hintGap = 1 }
    else { hintGap = 0 }
    return maxTitle + maxHint + hintGap
  }

  public static func anchoredBounds (
    for entries : [SelectionListEntry],
    anchoredTo itemBounds: BoxBounds,
    in container: BoxBounds,
    headerRows  : Int = 0
  ) -> BoxBounds {
    let size   = preferredSize(for: entries, headerRows: headerRows)
    let width  = min(size.width, container.width)
    let height = min(size.height, container.height)
    var row    = itemBounds.maxRow + 1
    var column = itemBounds.column

    if row + height - 1 > container.maxRow {
      row = itemBounds.row - height + 1
    }

    if row < container.row {
      row = container.row
    }

    if column + width - 1 > container.maxCol {
      column = container.maxCol - width + 1
    }

    if column < container.column {
      column = container.column
    }

    return BoxBounds(row: row, column: column, width: width, height: height)
  }
}

public extension SelectionListEntry {
  init ( menuEntry: MenuItem.Entry ) {
    self.init(title: menuEntry.title, acceleratorHint: menuEntry.acceleratorHint, action: menuEntry.action)
  }
}
