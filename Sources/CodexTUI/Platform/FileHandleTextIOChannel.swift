import Foundation
import Dispatch

/// Concrete `TextIOChannel` backed by a `FileHandle`. The channel listens for inbound data using a
/// `DispatchSourceRead`, decodes UTF-8 fragments, and writes outbound data using the paired file
/// handle so callers can bridge to serial ports or pseudo terminals.
public final class FileHandleTextIOChannel : TextIOChannel {
  public weak var delegate : TextIOChannelDelegate?

  private let readHandle  : FileHandle
  private let writeHandle : FileHandle
  private let queue       : DispatchQueue
  private var source      : DispatchSourceRead?
  private var pendingData : Data

  public init ( readHandle: FileHandle, writeHandle: FileHandle? = nil, queue: DispatchQueue = DispatchQueue(label: "CodexTUI.FileHandleTextIOChannel") ) {
    self.readHandle  = readHandle
    self.writeHandle = writeHandle ?? readHandle
    self.queue       = queue
    self.pendingData = Data()
  }

  public func start () {
    guard source == nil else { return }

    let descriptor = readHandle.fileDescriptor
    let source     = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: queue)

    source.setEventHandler { [weak self] in
      guard let self = self else { return }

      let available = Int(source.data)
      guard available > 0 else { return }

      let data = self.readHandle.readData(ofLength: available)
      guard data.isEmpty == false else { return }

      self.process(data: data)
    }

    source.setCancelHandler { [weak self] in
      self?.source = nil
    }

    self.source = source
    source.resume()
  }

  public func stop () {
    source?.cancel()
    source = nil
  }

  public func send ( _ text: String ) {
    guard text.isEmpty == false else { return }
    guard let data = text.data(using: .utf8) else { return }

    queue.async { [weak self] in
      guard let self = self else { return }
      self.writeHandle.write(data)
    }
  }

  private func process ( data: Data ) {
    pendingData.append(data)

    var buffer   = pendingData
    var trailing = Data()

    while buffer.isEmpty == false {
      if let string = String(data: buffer, encoding: .utf8) {
        pendingData = trailing
        deliver(fragment: string)
        return
      }

      trailing.insert(buffer.removeLast(), at: trailing.startIndex)
    }

    pendingData = trailing
  }

  private func deliver ( fragment: String ) {
    guard fragment.isEmpty == false else { return }

    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      self.delegate?.textIOChannel(self, didReceive: fragment)
    }
  }

  deinit {
    stop()
  }
}
