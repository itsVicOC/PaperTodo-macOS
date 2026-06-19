import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller: AppController
    private let singleInstanceService: SingleInstanceService
    private let launchCommand: AppCommand?

    init(controller: AppController, singleInstanceService: SingleInstanceService, launchCommand: AppCommand?) {
        self.controller = controller
        self.singleInstanceService = singleInstanceService
        self.launchCommand = launchCommand
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        singleInstanceService.startCommandServer { [weak self] command in
            self?.controller.handle(command)
        }
        controller.start(launchCommand: launchCommand)
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.applicationWillTerminate()
        singleInstanceService.releasePrimaryLock()
    }
}

let launchCommand = AppCommand.fromLaunchArguments(CommandLine.arguments)
let singleInstanceService = try! SingleInstanceService()

if !singleInstanceService.acquirePrimaryLock() {
    singleInstanceService.forward(command: launchCommand)
    exit(EXIT_SUCCESS)
}

if case .importData(let url) = launchCommand,
   ProcessInfo.processInfo.environment["PAPERTODO_IMPORT_WITHOUT_CONFIRMATION"] == "1" {
    do {
        let store = try StateStore()
        let importedState = try store.loadState(from: url)
        try store.replace(with: importedState)
        singleInstanceService.releasePrimaryLock()
        exit(EXIT_SUCCESS)
    } catch {
        FileHandle.standardError.write(Data("PaperTodo import failed: \(error)\n".utf8))
        singleInstanceService.releasePrimaryLock()
        exit(EXIT_FAILURE)
    }
}

if launchCommand?.isExit == true {
    let controller = AppController()
    controller.applicationWillTerminate()
    singleInstanceService.releasePrimaryLock()
    exit(EXIT_SUCCESS)
}

let application = NSApplication.shared
let delegate = AppDelegate(controller: AppController(), singleInstanceService: singleInstanceService, launchCommand: launchCommand)
application.delegate = delegate
application.run()
