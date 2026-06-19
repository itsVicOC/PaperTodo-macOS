import Foundation

final class SingleInstanceService {
    private let directoryURL: URL
    private let lockURL: URL
    private let socketURL: URL
    private var lockDescriptor: Int32 = -1
    private var listenDescriptor: Int32 = -1
    private var acceptSource: DispatchSourceRead?

    init() throws {
        directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent("PaperTodo", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        lockURL = directoryURL.appendingPathComponent("PaperTodoMac.lock")
        socketURL = directoryURL.appendingPathComponent("PaperTodoMac.sock")
    }

    func acquirePrimaryLock() -> Bool {
        lockDescriptor = open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard lockDescriptor >= 0 else { return false }
        if flock(lockDescriptor, LOCK_EX | LOCK_NB) == 0 {
            return true
        }
        close(lockDescriptor)
        lockDescriptor = -1
        return false
    }

    func releasePrimaryLock() {
        stopCommandServer()
        guard lockDescriptor >= 0 else { return }
        flock(lockDescriptor, LOCK_UN)
        close(lockDescriptor)
        lockDescriptor = -1
    }

    func forward(command: AppCommand?) {
        let payload = AppCommandPayload.encode(command)
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { return }
        defer { close(descriptor) }

        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let path = socketURL.path
        guard path.utf8.count < MemoryLayout.size(ofValue: address.sun_path) else { return }
        withUnsafeMutableBytes(of: &address.sun_path) { rawBuffer in
            rawBuffer.initializeMemory(as: CChar.self, repeating: 0)
            _ = path.withCString { source in
                rawBuffer.baseAddress?.copyMemory(from: source, byteCount: path.utf8.count)
            }
        }

        let addressLength = socklen_t(MemoryLayout<sa_family_t>.size + path.utf8.count + 1)
        let connected = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(descriptor, $0, addressLength)
            }
        }
        guard connected == 0 else { return }
        _ = payload.withCString { write(descriptor, $0, strlen($0)) }
    }

    func startCommandServer(_ handler: @escaping @MainActor (AppCommand) -> Void) {
        stopCommandServer()
        try? FileManager.default.removeItem(at: socketURL)

        listenDescriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard listenDescriptor >= 0 else { return }

        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let path = socketURL.path
        guard path.utf8.count < MemoryLayout.size(ofValue: address.sun_path) else { return }
        withUnsafeMutableBytes(of: &address.sun_path) { rawBuffer in
            rawBuffer.initializeMemory(as: CChar.self, repeating: 0)
            _ = path.withCString { source in
                rawBuffer.baseAddress?.copyMemory(from: source, byteCount: path.utf8.count)
            }
        }

        let addressLength = socklen_t(MemoryLayout<sa_family_t>.size + path.utf8.count + 1)
        let bound = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(listenDescriptor, $0, addressLength)
            }
        }
        guard bound == 0, listen(listenDescriptor, 8) == 0 else {
            stopCommandServer()
            return
        }

        let source = DispatchSource.makeReadSource(fileDescriptor: listenDescriptor, queue: .main)
        source.setEventHandler { [weak self] in
            self?.acceptCommand(handler)
        }
        source.setCancelHandler { [descriptor = listenDescriptor, socketURL] in
            close(descriptor)
            try? FileManager.default.removeItem(at: socketURL)
        }
        acceptSource = source
        source.resume()
    }

    private func acceptCommand(_ handler: @escaping @MainActor (AppCommand) -> Void) {
        let client = accept(listenDescriptor, nil, nil)
        guard client >= 0 else { return }
        defer { close(client) }

        var buffer = [UInt8](repeating: 0, count: 256)
        let count = read(client, &buffer, buffer.count - 1)
        guard count > 0 else { return }
        let raw = String(decoding: buffer.prefix(Int(count)), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let command = AppCommandPayload.decode(raw)
        guard let command else { return }
        Task { @MainActor in
            handler(command)
        }
    }

    private func stopCommandServer() {
        acceptSource?.cancel()
        acceptSource = nil
        if listenDescriptor >= 0 {
            close(listenDescriptor)
            listenDescriptor = -1
        }
        try? FileManager.default.removeItem(at: socketURL)
    }

    deinit {
        releasePrimaryLock()
    }
}
