import Foundation

/// Represents an axis-aligned rectangle expressed using 1-based terminal coordinates.
/// The type centralises the geometry primitives used throughout the layout system so that
/// widgets reason about rows and columns in a consistent fashion irrespective of where
/// they appear in the hierarchy.
public struct BoxBounds : Equatable {
  public var row    : Int
  public var column : Int
  public var width  : Int
  public var height : Int

  /// Creates a new region anchored at the provided origin. Width and height are stored as-is
  /// which keeps bounds arithmetic extremely cheap; callers are responsible for clamping to
  /// non-negative sizes when required.
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

  /// Returns a new box that has been contracted by the supplied edge insets. The routine
  /// mirrors SwiftUI's behaviour by subtracting the horizontal/vertical padding from the
  /// width and height while ensuring negative dimensions are never emitted, which keeps
  /// downstream layout code simple and defensive.
  public func inset ( by insets: EdgeInsets ) -> BoxBounds {
    let insetRow    = row + insets.top
    let insetColumn = column + insets.leading
    let insetWidth  = max(0, width - insets.horizontal)
    let insetHeight = max(0, height - insets.vertical)

    return BoxBounds(row: insetRow, column: insetColumn, width: insetWidth, height: insetHeight)
  }

  /// Positions the receiver within another box using classic alignment semantics. The
  /// calculation derives a new origin by combining the container's edges with the desired
  /// alignment mode. Because the size is preserved we can reuse the value when repeatedly
  /// centering or pinning widgets without recomputing widths and heights.
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

/// Integer variant of SwiftUI's `EdgeInsets` tailored for terminal rows and columns. Widgets
/// use the structure to describe padding around content without needing to perform manual
/// coordinate arithmetic themselves.
public struct EdgeInsets : Equatable {
  public var top      : Int
  public var leading  : Int
  public var bottom   : Int
  public var trailing : Int

  /// Creates a set of insets that can expand or contract bounds. Default arguments make it
  /// cheap to specify only the edges that matter for a particular calculation.
  public init ( top: Int = 0, leading: Int = 0, bottom: Int = 0, trailing: Int = 0 ) {
    self.top      = top
    self.leading  = leading
    self.bottom   = bottom
    self.trailing = trailing
  }

  public var horizontal : Int { leading + trailing }
  public var vertical   : Int { top + bottom }
}

/// Alignment options for anchoring content horizontally within a container. The values are
/// interpreted by `BoxBounds.aligned(horizontal:vertical:inside:)` to compute the necessary
/// origin adjustments.
public enum HorizontalAlignment {
  case leading
  case center
  case trailing
}

/// Alignment options for anchoring content vertically inside a container box.
public enum VerticalAlignment {
  case top
  case center
  case bottom
}
