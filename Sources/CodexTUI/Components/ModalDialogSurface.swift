import Foundation

/// Aggregates the results of laying out a modal dialog surface. It exposes the rendered border and
/// button commands as well as the interior bounds and computed button row to downstream widgets.
public struct ModalDialogSurfaceLayout {
  public var result    : WidgetLayoutResult
  public var interior  : BoxBounds
  public var buttonRow : Int?

  public init ( result: WidgetLayoutResult, interior: BoxBounds, buttonRow: Int? ) {
    self.result    = result
    self.interior  = interior
    self.buttonRow = buttonRow
  }
}

/// Namespace containing the shared rendering logic for modal dialog shells. Widgets such as
/// `MessageBox` and `TextEntryBox` delegate to these helpers so they remain visually consistent.
public enum ModalDialogSurface {
  /// Lays out a modal dialog surface with an optional button row. The algorithm starts by invoking
  /// the `Box` widget to draw the outer frame, captures its commands and derives the interior bounds
  /// by insetting the box. When interior space exists it fills the background, then, if buttons are
  /// present, it renders them along the bottom edge using either the default or highlight styling. The
  /// function returns both the aggregated commands and metadata (interior bounds and button row) so
  /// callers can continue layering content on top.
  public static func layout (
    in context        : LayoutContext,
    contentStyle      : ColorPair,
    borderStyle       : ColorPair,
    buttonTitles      : [String],
    activeButtonIndex : Int,
    buttonStyle       : ColorPair,
    highlightStyle    : ColorPair
  ) -> ModalDialogSurfaceLayout {
    let bounds    = context.bounds
    let box       = Box(bounds: bounds, style: borderStyle)
    let boxLayout = box.layout(in: context)
    var commands  = boxLayout.commands
    let children  = boxLayout.children
    let interior  = bounds.inset(by: EdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1))

    guard interior.width > 0 && interior.height > 0 else {
      let result = WidgetLayoutResult(bounds: bounds, commands: commands, children: children)
      return ModalDialogSurfaceLayout(result: result, interior: interior, buttonRow: nil)
    }

    for row in interior.row...interior.maxRow {
      for column in interior.column...interior.maxCol {
        commands.append(
          RenderCommand(
            row   : row,
            column: column,
            tile  : SurfaceTile(
              character : " ",
              attributes: contentStyle
            )
          )
        )
      }
    }

    let buttonRow : Int?

    if buttonTitles.isEmpty == false {
      buttonRow = interior.maxRow
      renderButtons(
        titles         : buttonTitles,
        highlightIndex : activeButtonIndex,
        row            : buttonRow!,
        bounds         : interior,
        contentStyle   : contentStyle,
        buttonStyle    : buttonStyle,
        highlightStyle : highlightStyle,
        commands       : &commands
      )
    } else {
      buttonRow = nil
    }

    let result = WidgetLayoutResult(bounds: bounds, commands: commands, children: children)
    return ModalDialogSurfaceLayout(result: result, interior: interior, buttonRow: buttonRow)
  }

  public static func preferredSize (
    contentWidth : Int,
    contentHeight: Int,
    buttonTitles : [String],
    minimumWidth : Int = 8,
    minimumHeight: Int = 4
  ) -> (width: Int, height: Int) {
    let buttonWidths  = buttonTitles.map { $0.count + 2 }
    let buttonTotal   = buttonWidths.reduce(0, +) + max(0, buttonTitles.count - 1)
    let interiorWidth = max(contentWidth, buttonTotal)

    var interiorHeight = max(0, contentHeight)
    if buttonTitles.isEmpty == false {
      if interiorHeight == 0 { interiorHeight = 1 }
      interiorHeight += 1
      interiorHeight += 1
    }

    let width  = max(minimumWidth, interiorWidth + 2)
    let height = max(minimumHeight, interiorHeight + 2)
    return (width, height)
  }

  public static func centeredBounds (
    contentWidth : Int,
    contentHeight: Int,
    buttonTitles : [String],
    in container : BoxBounds,
    minimumWidth : Int = 8,
    minimumHeight: Int = 4
  ) -> BoxBounds {
    let size   = preferredSize(contentWidth: contentWidth, contentHeight: contentHeight, buttonTitles: buttonTitles, minimumWidth: minimumWidth, minimumHeight: minimumHeight)
    let width  = min(size.width, container.width)
    let height = min(size.height, container.height)
    let bounds = BoxBounds(row: 1, column: 1, width: width, height: height)
    return bounds.aligned(horizontal: .center, vertical: .center, inside: container)
  }

  private static func renderButtons (
    titles         : [String],
    highlightIndex : Int,
    row            : Int,
    bounds         : BoxBounds,
    contentStyle   : ColorPair,
    buttonStyle    : ColorPair,
    highlightStyle : ColorPair,
    commands       : inout [RenderCommand]
  ) {
    guard bounds.width > 0 else { return }

    var buttonStrings = [String]()
    buttonStrings.reserveCapacity(titles.count)

    for title in titles {
      let padded = " \(title) "
      buttonStrings.append(String(padded.prefix(bounds.width)))
    }

    let totalWidth = buttonStrings.reduce(0) { $0 + $1.count } + max(0, buttonStrings.count - 1)
    let offset     = max(0, bounds.width - totalWidth)
    var column     = bounds.column + offset
    let maxIndex   = max(0, buttonStrings.count - 1)
    let highlight  = max(0, min(highlightIndex, maxIndex))

    for (index, string) in buttonStrings.enumerated() {
      let attributes = index == highlight ? highlightStyle : buttonStyle
      for character in string {
        guard column <= bounds.maxCol else { break }
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
        column += 1
      }

      if index < buttonStrings.count - 1 {
        if column <= bounds.maxCol {
          commands.append(
            RenderCommand(
              row   : row,
              column: column,
              tile  : SurfaceTile(
                character : " ",
                attributes: contentStyle
              )
            )
          )
        }
        column += 1
      }
    }
  }
}
