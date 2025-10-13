import Foundation

public enum SplitAxis {
  case horizontal
  case vertical
}

public enum SplitSizing {
  case flexible
  case fixed(Int)
  case proportion(Double)

  var fixedLength : Int? {
    switch self {
      case .fixed(let value) : return max(0, value)
      default                 : return nil
    }
  }

  var weight : Double {
    switch self {
      case .proportion(let value) : return max(0, value)
      default                      : return 0
    }
  }

  var isFlexible : Bool {
    if case .flexible = self { return true }
    return false
  }
}

public struct Split : Widget {
  public var axis       : SplitAxis
  public var firstSize  : SplitSizing
  public var secondSize : SplitSizing
  public var first      : AnyWidget
  public var second     : AnyWidget

  public init ( axis: SplitAxis, firstSize: SplitSizing = .flexible, secondSize: SplitSizing = .flexible, @WidgetBuilder first: () -> [AnyWidget], @WidgetBuilder second: () -> [AnyWidget] ) {
    self.axis       = axis
    self.firstSize  = firstSize
    self.secondSize = secondSize
    self.first      = assembleWidget(from: first())
    self.second     = assembleWidget(from: second())
  }

  public func layout ( in context: LayoutContext ) -> WidgetLayoutResult {
    let bounds = context.bounds
    let total  = axis == .vertical ? bounds.height : bounds.width
    guard total > 0 else { return WidgetLayoutResult(bounds: bounds) }

    let lengths = resolvedLengths(total: total)
    let firstLength  = max(0, min(total, lengths.first))
    let secondLength = max(0, min(total - firstLength, lengths.second))

    var layouts = [WidgetLayoutResult]()
    layouts.reserveCapacity(2)

    switch axis {
      case .vertical :
        let firstBounds = BoxBounds(row: bounds.row, column: bounds.column, width: bounds.width, height: firstLength)
        var firstContext = context
        firstContext.bounds = firstBounds
        layouts.append(first.layout(in: firstContext))

        let secondRow    = bounds.row + firstLength
        let secondHeight = max(0, bounds.height - firstLength)
        let secondBounds = BoxBounds(row: secondRow, column: bounds.column, width: bounds.width, height: min(secondHeight, secondLength))
        var secondContext = context
        secondContext.bounds = secondBounds
        layouts.append(second.layout(in: secondContext))

      case .horizontal :
        let firstBounds = BoxBounds(row: bounds.row, column: bounds.column, width: firstLength, height: bounds.height)
        var firstContext = context
        firstContext.bounds = firstBounds
        layouts.append(first.layout(in: firstContext))

        let secondColumn = bounds.column + firstLength
        let secondWidth  = max(0, bounds.width - firstLength)
        let secondBounds = BoxBounds(row: bounds.row, column: secondColumn, width: min(secondWidth, secondLength), height: bounds.height)
        var secondContext = context
        secondContext.bounds = secondBounds
        layouts.append(second.layout(in: secondContext))
    }

    return WidgetLayoutResult(bounds: bounds, children: layouts)
  }

  private func resolvedLengths ( total: Int ) -> (first: Int, second: Int) {
    var remaining = max(0, total)
    var first     = 0
    var second    = 0

    if let fixed = firstSize.fixedLength {
      let clamped = min(fixed, remaining)
      first     += clamped
      remaining -= clamped
    }

    if let fixed = secondSize.fixedLength {
      let clamped = min(fixed, remaining)
      second    += clamped
      remaining -= clamped
    }

    let firstWeight  = firstSize.weight
    let secondWeight = secondSize.weight
    let weightTotal  = firstWeight + secondWeight

    if weightTotal > 0 && remaining > 0 {
      let firstShare  = Int(Double(remaining) * (firstWeight / weightTotal))
      let secondShare = Int(Double(remaining) * (secondWeight / weightTotal))
      first     += firstShare
      second    += secondShare
      remaining -= (firstShare + secondShare)
    }

    if remaining > 0 {
      let flexibleCount = (firstSize.isFlexible ? 1 : 0) + (secondSize.isFlexible ? 1 : 0)

      if flexibleCount > 0 {
        let base   = remaining / flexibleCount
        let extra  = remaining % flexibleCount
        var extras = extra

        if firstSize.isFlexible {
          let addition = base + (extras > 0 ? 1 : 0)
          first     += addition
          remaining -= addition
          if extras > 0 { extras -= 1 }
        }

        if secondSize.isFlexible && remaining > 0 {
          let addition = base + (extras > 0 ? 1 : 0)
          second    += addition
          remaining -= addition
        }
      }
    }

    if remaining > 0 {
      second += remaining
    }

    return (first, second)
  }
}
