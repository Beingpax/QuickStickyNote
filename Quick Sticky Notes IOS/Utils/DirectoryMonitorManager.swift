import Foundation

class DirectoryMonitorManager {
    private let url: URL
    private var directoryHandle: FileHandle?
    private let queue = DispatchQueue(label: "com.qsnotes.directorymonitor", qos: .utility)
    private var source: DispatchSourceFileSystemObject?
    
    var onDirectoryChange: (() -> Void)?
    
    init(url: URL) {
        self.url = url
    }
    
    func startMonitoring() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let directoryFD = open(self.url.path, O_EVTONLY)
                guard directoryFD >= 0 else {
                    print("DirectoryMonitorManager: Failed to open directory")
                    return
                }
                
                self.directoryHandle = FileHandle(fileDescriptor: directoryFD, closeOnDealloc: true)
                
                let source = DispatchSource.makeFileSystemObjectSource(
                    fileDescriptor: directoryFD,
                    eventMask: [.write, .extend, .attrib, .link, .rename, .revoke],
                    queue: self.queue
                )
                
                source.setEventHandler { [weak self] in
                    // Debounce the changes using a small delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self?.onDirectoryChange?()
                    }
                }
                
                source.setCancelHandler {
                    try? self.directoryHandle?.close()
                    self.directoryHandle = nil
                }
                
                self.source = source
                source.resume()
                print("DirectoryMonitorManager: Started monitoring directory")
            } catch {
                print("DirectoryMonitorManager: Failed to start monitoring: \(error)")
            }
        }
    }
    
    func stopMonitoring() {
        source?.cancel()
        source = nil
        try? directoryHandle?.close()
        directoryHandle = nil
        print("DirectoryMonitorManager: Stopped monitoring directory")
    }
    
    deinit {
        stopMonitoring()
    }
} 