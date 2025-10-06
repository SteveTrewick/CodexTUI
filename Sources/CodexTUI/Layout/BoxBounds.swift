import Foundation

public struct BoxBounds : Equatable {
  public var row    : Int
  public var column : Int
  public var width  : Int
  public var height : Int

  public init ( row: Int, column: Int, width: Int, height: Int ) {
    self.row    = row
    self.column = column
    self.width  = width
    self.height = height
  }

  public var minRow : Int { row }
  public var maxRow : Int { row + height - 1 }
  public var minCol : Int { column }
  public var maxCol : Int { column + width - 1 }

  public var area : Int { max(0, width * height) }

  public func inset ( by insets: EdgeInsets ) -> BoxBounds {
    let insetRow    = row + insets.top
    let insetColumn = column + insets.leading
    let insetWidth  = max(0, width - insets.horizontal)
    let insetHeight = max(0, height - insets.vertical)

    return BoxBounds(row: insetRow, column: insetColumn, width: insetWidth, height: insetHeight)
  }

  public func aligned ( horizontal: HorizontalAlignment, vertical: VerticalAlignment, inside container: BoxBounds ) -> BoxBounds {
    let originRow : Int
    let originCol : Int

    switch vertical {
      case .top    : originRow = container.row
      case .center : originRow = container.row + (container.height - height) / 2
      case .bottom : originRow = container.maxRow - height + 1
    }

    switch horizontal {
      case .leading  : originCol = container.column
      case .center   : originCol = container.column + (container.width - width) / 2
      case .trailing : originCol = container.maxCol - width + 1
    }

    return BoxBounds(row: originRow, column: originCol, width: width, height: height)
  }
}

public struct EdgeInsets : Equatable {
  public var top      : Int
  public var leading  : Int
  public var bottom   : Int
  public var trailing : Int

  public init ( top: Int = 0, leading: Int = 0, bottom: Int = 0, trailing: Int = 0 ) {
    self.top      = top
    self.leading  = leading
    self.bottom   = bottom
    self.trailing = trailing
  }

  public var horizontal : Int { leading + trailing }
  public var vertical   : Int { top + bottom }
}

public enum HorizontalAlignment {
  case leading
  case center
  case trailing
}

public enum VerticalAlignment {
  case top
  case center
  case bottom
}
