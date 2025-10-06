import Foundation
import Dispatch

#if os(Linux)
import Glibc
#else
import Darwin
#endif

public final class SignalObserver {
  public typealias Handler = () -> Void

  private let monitoredSignal : Int32
  private let queue           : DispatchQueue
  private var source          : DispatchSourceSignal?
  private var handler         : Handler?

  public init ( signal: Int32 = SIGWINCH, queue: DispatchQueue = .main ) {
    self.monitoredSignal = signal
    self.queue           = queue
  }

  public func setHandler ( _ handler: @escaping Handler ) {
    self.handler = handler
  }

  public func start () {
    guard source == nil else { return }

    signal(monitoredSignal, SIG_IGN)

    let source = DispatchSource.makeSignalSource(signal: monitoredSignal, queue: queue)
    source.setEventHandler { [weak self] in
      self?.handler?()
    }
    source.resume()

    self.source = source
    signal(monitoredSignal, SIG_IGN)
  }

  public func stop () {
    source?.cancel()
    source = nil
    handler = nil
  }

  deinit {
    stop()
  }
}
