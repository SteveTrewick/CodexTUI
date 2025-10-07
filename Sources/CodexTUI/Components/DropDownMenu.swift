import Foundation

// Renders a boxed list of menu entries and highlights the focused row.
public struct DropDownMenu : Widget {
  public var entries        : [MenuItem.Entry]
  public var selectionIndex : Int
  public var style          : ColorPair
  public var highlightStyle : ColorPair
  public var borderStyle    : ColorPair

  public init ( entries: [MenuItem.Entry], selectionIndex: Int = 0, style: ColorPair, highlightStyle: ColorPair, borderStyle: ColorPair ) {
    self.entries        = entries
    self.selectionIndex = selectionIndex
    self.style          = style
    self.highlightStyle = highlightStyle
    self.borderStyle    = borderStyle
  }

  public func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    let bounds          = context.bounds
    let box             = Box(bounds: bounds, style: borderStyle)
    let boxLayout       = box.layout(in: context)
    var commands        = [RenderCommand]()
    var children        = [WidgetLayoutResult]()
    children.append(boxLayout)

    let interiorWidth   = max(0, bounds.width - 2)
    let interiorHeight  = max(0, bounds.height - 2)
    guard interiorWidth > 0 && interiorHeight > 0 else {
      return WidgetLayoutResult(bounds: bounds, commands: commands, children: children)
    }

    let interiorRow     = bounds.row + 1
    let interiorColumn  = bounds.column + 1
    let maxIndex        = max(0, entries.count - 1)
    let selectedIndex   = entries.isEmpty ? nil : max(0, min(selectionIndex, maxIndex))

    for (index, entry) in entries.enumerated() {
      guard index < interiorHeight else { break }
      let row         = interiorRow + index
      let attributes  = (index == selectedIndex) ? highlightStyle : style
      let maxColumn   = interiorColumn + interiorWidth - 1

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
        let usableHint = hint.suffix(interiorWidth)
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

    return WidgetLayoutResult(bounds: bounds, commands: commands, children: children)
  }
}

public extension DropDownMenu {
  static func preferredSize ( for entries: [MenuItem.Entry] ) -> (width: Int, height: Int) {
    let maxTitle = entries.map { $0.title.count }.max() ?? 0
    let maxHint  = entries.map { $0.acceleratorHint?.count ?? 0 }.max() ?? 0
    let hintGap  = maxHint > 0 && maxTitle > 0 ? 2 : (maxHint > 0 ? 1 : 0)
    let content  = maxTitle + maxHint + hintGap
    let width    = max(4, content + 2)
    let height   = max(2, entries.count + 2)
    return (width, height)
  }

  static func anchoredBounds ( for entries: [MenuItem.Entry], anchoredTo itemBounds: BoxBounds, in container: BoxBounds ) -> BoxBounds {
    let size      = preferredSize(for: entries)
    let width     = min(size.width, container.width)
    let height    = min(size.height, container.height)
    var row       = itemBounds.maxRow + 1
    var column    = itemBounds.column

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
