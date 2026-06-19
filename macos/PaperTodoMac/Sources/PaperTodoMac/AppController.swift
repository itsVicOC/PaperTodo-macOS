import AppKit
import UniformTypeIdentifiers

@MainActor
final class AppController: NSObject, PaperWindowControllerDelegate, SettingsWindowControllerDelegate, MasterCapsuleWindowControllerDelegate {
    private let store: StateStore
    private var state: AppState
    private let canSaveState: Bool
    private let loadError: Error?
    private let skipsImportConfirmation: Bool
    private var windows: [String: PaperWindowController] = [:]
    private var statusItem: NSStatusItem?
    private var settingsWindowController: SettingsWindowController?
    private var masterCapsuleWindowController: MasterCapsuleWindowController?
    private var saveWorkItem: DispatchWorkItem?

    private var isDarkAppearance: Bool {
        let appearance = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
        return appearance == .darkAqua
    }

    private var palette: PaperPalette {
        PaperTheme.palette(for: state.colorScheme, dark: state.theme == "dark" || (state.theme == "system" && isDarkAppearance))
    }

    override init() {
        let initializedStore = try! StateStore()
        var initializedState = AppState()
        do {
            initializedState = try initializedStore.load()
            canSaveState = true
            loadError = nil
        } catch {
            NSLog("PaperTodo failed to load state: \(error)")
            canSaveState = false
            loadError = error
        }
        store = initializedStore
        state = initializedState
        skipsImportConfirmation = ProcessInfo.processInfo.environment["PAPERTODO_IMPORT_WITHOUT_CONFIRMATION"] == "1"
        super.init()
    }

    func start(launchCommand: AppCommand? = nil) {
        NSApp.setActivationPolicy(.accessory)
        createStatusItem()

        if let loadError {
            showStartupLoadFailureAlert(error: loadError)
            NSApp.terminate(nil)
            return
        }

        if launchCommand == .hide || launchCommand == .exit {
            for index in state.papers.indices {
                state.papers[index].isVisible = false
            }
        } else if state.papers.isEmpty {
            _ = createPaper(type: PaperKind.todo.rawValue, show: true)
        }

        if !state.papers.isEmpty {
            for paper in state.papers where paper.isVisible {
                showPaper(paper)
            }
        }

        if let launchCommand {
            handle(launchCommand)
            if case .importData = launchCommand, skipsImportConfirmation {
                NSApp.terminate(nil)
                return
            }
        }
        arrangeDeepCapsules(animated: false)
        saveNow()
    }

    func applicationWillTerminate() {
        saveWorkItem?.cancel()
        syncWindowFrames()
        saveNow()
    }

    func handle(_ command: AppCommand) {
        switch command {
        case .show:
            showAllPapers()
            NSApp.activate(ignoringOtherApps: true)
        case .hide:
            hideAllPapers()
        case .toggle:
            if state.papers.contains(where: \.isVisible) {
                hideAllPapers()
            } else {
                showAllPapers()
                NSApp.activate(ignoringOtherApps: true)
            }
        case .newTodo:
            createPaper(type: PaperKind.todo.rawValue, show: true)
            NSApp.activate(ignoringOtherApps: true)
        case .newNote:
            createPaper(type: PaperKind.note.rawValue, show: true)
            NSApp.activate(ignoringOtherApps: true)
        case .importData(let url):
            do {
                try importData(from: url, requiresConfirmation: !skipsImportConfirmation, showsResultAlert: !skipsImportConfirmation)
            } catch {
                if !skipsImportConfirmation {
                    showImportFailureAlert(error: error)
                } else {
                    NSLog("PaperTodo import failed: \(error)")
                }
            }
            NSApp.activate(ignoringOtherApps: true)
        case .exit:
            NSApp.terminate(nil)
        }
    }

    @discardableResult
    private func createPaper(type: String, show: Bool) -> PaperData {
        let normalizedType = type == PaperKind.note.rawValue ? PaperKind.note.rawValue : PaperKind.todo.rawValue
        var paper = PaperData()
        paper.type = normalizedType
        paper.title = PaperTitles.defaultTitle(type: normalizedType, number: nextTitleNumber(for: normalizedType))
        paper.width = normalizedType == PaperKind.note.rawValue ? PaperDefaults.noteDefaultWidth : PaperDefaults.todoDefaultWidth
        paper.height = normalizedType == PaperKind.note.rawValue ? PaperDefaults.noteDefaultHeight : PaperDefaults.todoDefaultHeight

        let offset = Double(state.papers.count * 24)
        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 80, y: 80, width: 900, height: 700)
        paper.x = visible.minX + 140 + offset
        paper.y = visible.maxY - paper.height - 120 - offset
        paper.isVisible = show

        if normalizedType == PaperKind.todo.rawValue {
            paper.items = [PaperItem(text: "", done: false, order: 0)]
        }

        state.papers.append(paper)
        if show {
            showPaper(paper)
        }
        rebuildStatusMenu()
        arrangeDeepCapsules(animated: state.enableAnimations)
        markDirty()
        return paper
    }

    private func showPaper(_ paper: PaperData) {
        if let controller = windows[paper.id] {
            controller.updatePaper(paper)
            controller.show()
            return
        }

        let controller = PaperWindowController(paper: paper, appState: state, linkedNotes: linkedNoteSummaries(), palette: palette)
        controller.delegate = self
        windows[paper.id] = controller
        controller.show()
    }

    private func hideAllPapers() {
        for index in state.papers.indices {
            state.papers[index].isVisible = false
            windows[state.papers[index].id]?.updatePaper(state.papers[index])
        }
        for controller in windows.values {
            controller.hide()
        }
        rebuildStatusMenu()
        arrangeDeepCapsules(animated: state.enableAnimations)
        markDirty()
    }

    private func showAllPapers() {
        for index in state.papers.indices {
            state.papers[index].isVisible = true
            showPaper(state.papers[index])
        }
        rebuildStatusMenu()
        arrangeDeepCapsules(animated: state.enableAnimations)
        markDirty()
    }

    private func nextTitleNumber(for type: String) -> Int {
        let count = state.papers.filter { $0.type == type }.count
        return count + 1
    }

    private func createStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = L10n.text(.statusItemTitle)
        item.button?.toolTip = "PaperTodo"
        statusItem = item
        rebuildStatusMenu()
    }

    private func rebuildStatusMenu() {
        let menu = NSMenu()

        let title = NSMenuItem(title: L10n.text(.appMenuTitle), action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: L10n.text(.showAllPapers), action: #selector(showAllPapersAction), keyEquivalent: "s", target: self))
        menu.addItem(NSMenuItem(title: L10n.text(.hideAllPapers), action: #selector(hideAllPapersAction), keyEquivalent: "h", target: self))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: L10n.text(.newTodo), action: #selector(newTodoAction), keyEquivalent: "t", target: self))
        menu.addItem(NSMenuItem(title: L10n.text(.newNote), action: #selector(newNoteAction), keyEquivalent: "n", target: self))

        if !state.papers.isEmpty {
            menu.addItem(.separator())
            for paper in state.papers {
                let number = state.papers.filter { $0.type == paper.type }.firstIndex { $0.id == paper.id }.map { $0 + 1 } ?? 1
                let prefix = paper.isVisible ? "✓ " : ""
                let menuItem = NSMenuItem(title: prefix + PaperTitles.effectiveTitle(for: paper, number: number), action: #selector(showPaperAction(_:)), keyEquivalent: "")
                menuItem.representedObject = paper.id
                menuItem.target = self
                menu.addItem(menuItem)
            }
            menu.addItem(.separator())
            let deleteMenu = NSMenu()
            for paper in state.papers {
                let number = state.papers.filter { $0.type == paper.type }.firstIndex { $0.id == paper.id }.map { $0 + 1 } ?? 1
                let menuItem = NSMenuItem(title: PaperTitles.effectiveTitle(for: paper, number: number), action: #selector(deletePaperAction(_:)), keyEquivalent: "")
                menuItem.representedObject = paper.id
                menuItem.target = self
                deleteMenu.addItem(menuItem)
            }
            let deleteRoot = NSMenuItem(title: L10n.text(.deletePaperMenu), action: nil, keyEquivalent: "")
            menu.setSubmenu(deleteMenu, for: deleteRoot)
            menu.addItem(deleteRoot)
        }

        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: L10n.text(.settings), action: #selector(openSettingsAction), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        let dataItem = NSMenuItem(title: L10n.text(.openDataDirectory), action: #selector(openDataDirectoryAction), keyEquivalent: "")
        dataItem.target = self
        menu.addItem(dataItem)
        let importItem = NSMenuItem(title: L10n.text(.importData), action: #selector(importDataAction), keyEquivalent: "")
        importItem.target = self
        menu.addItem(importItem)
        menu.addItem(NSMenuItem(title: L10n.text(.quit), action: #selector(quitAction), keyEquivalent: "q", target: self))

        statusItem?.menu = menu
    }

    func paperWindowController(_ controller: PaperWindowController, didUpdate paper: PaperData) {
        if let index = state.papers.firstIndex(where: { $0.id == paper.id }) {
            state.papers[index] = paper
        }
        refreshWindowLinkedNotes()
        rebuildStatusMenu()
        arrangeDeepCapsules(animated: state.enableAnimations)
        markDirty()
    }

    func paperWindowControllerDidRequestNewTodo(_ controller: PaperWindowController) {
        createPaper(type: PaperKind.todo.rawValue, show: true)
    }

    func paperWindowControllerDidRequestNewNote(_ controller: PaperWindowController) {
        createPaper(type: PaperKind.note.rawValue, show: true)
    }

    func paperWindowControllerDidRequestClose(_ controller: PaperWindowController) {
        rebuildStatusMenu()
        arrangeDeepCapsules(animated: state.enableAnimations)
    }

    func paperWindowControllerDidChangeCapsuleState(_ controller: PaperWindowController) {
        arrangeDeepCapsules(animated: state.enableAnimations)
    }

    func paperWindowController(_ controller: PaperWindowController, didRequestOpenLinkedNote noteID: String) {
        showLinkedNote(id: noteID)
    }

    func paperWindowController(_ controller: PaperWindowController, didDropDeepCapsuleAt screenY: CGFloat) {
        let slottedIDs = state.papers
            .filter { paper in
                guard paper.isVisible, let window = windows[paper.id] else { return false }
                return window.occupiesDeepCapsuleSlot
            }
            .map(\.id)
        guard slottedIDs.count > 1,
              let currentIndex = slottedIDs.firstIndex(of: controller.paper.id) else {
            arrangeDeepCapsules(animated: state.enableAnimations)
            return
        }

        var desiredIDs = slottedIDs
        desiredIDs.remove(at: currentIndex)
        let targetIndex = controller.deepCapsuleDropIndex(for: screenY, count: slottedIDs.count)
        desiredIDs.insert(controller.paper.id, at: min(targetIndex, desiredIDs.count))

        let papersByID = Dictionary(uniqueKeysWithValues: state.papers.map { ($0.id, $0) })
        var collapsedCursor = 0
        state.papers = state.papers.compactMap { paper in
            guard desiredIDs.contains(paper.id) else {
                return paper
            }
            defer { collapsedCursor += 1 }
            return papersByID[desiredIDs[collapsedCursor]]
        }

        rebuildStatusMenu()
        arrangeDeepCapsules(animated: state.enableAnimations)
        markDirty()
    }

    func settingsWindowController(_ controller: SettingsWindowController, didUpdate state: AppState) {
        self.state.theme = state.theme
        self.state.colorScheme = state.colorScheme
        self.state.markdownRenderMode = state.markdownRenderMode
        self.state.externalMarkdownExtension = state.externalMarkdownExtension
        self.state.maxTitleLength = state.maxTitleLength
        self.state.useCapsuleMode = state.useCapsuleMode
        self.state.useDeepCapsuleMode = state.useDeepCapsuleMode
        self.state.useCapsuleCollapseAll = state.useCapsuleCollapseAll
        self.state.capsuleCollapseAllActive = state.capsuleCollapseAllActive
        self.state.showTopBarNewTodoButton = state.showTopBarNewTodoButton
        self.state.showTopBarNewNoteButton = state.showTopBarNewNoteButton
        self.state.showTopBarExternalOpenButton = state.showTopBarExternalOpenButton
        self.state.enableTodoNoteLinks = state.enableTodoNoteLinks
        self.state.showLinkedNoteName = state.showLinkedNoteName
        self.state.hideLinkedNotesFromCapsules = state.hideLinkedNotesFromCapsules
        self.state.showDeepCapsuleWhileExpanded = state.showDeepCapsuleWhileExpanded
        self.state.enableAnimations = state.enableAnimations
        self.state.enableToolTips = state.enableToolTips
        self.state.showPapersOnAllSpaces = state.showPapersOnAllSpaces
        normalizeCapsuleStateAfterSettingsChange()
        refreshWindowPalettes()
        refreshWindowAppState()
        rebuildStatusMenu()
        markDirty()
    }

    func settingsWindowController(_ controller: SettingsWindowController, didRequestSetLaunchAtLogin enabled: Bool) {
        do {
            let status = try LoginItemService.setEnabled(enabled)
            controller.updateLoginItemStatus(status)
            if enabled && status == .requiresApproval {
                showLoginItemApprovalAlert()
            }
        } catch {
            controller.updateLoginItemStatus(LoginItemService.status)
            showLoginItemFailureAlert(error: error)
        }
    }

    func settingsWindowControllerDidRequestOpenLoginItems(_ controller: SettingsWindowController) {
        LoginItemService.openSystemSettings()
    }

    func masterCapsuleWindowControllerDidToggle(_ controller: MasterCapsuleWindowController) {
        state.capsuleCollapseAllActive.toggle()
        rebuildStatusMenu()
        arrangeDeepCapsules(animated: state.enableAnimations)
        settingsWindowController?.updateState(state)
        markDirty()
    }

    @objc private func showAllPapersAction() {
        showAllPapers()
    }

    @objc private func hideAllPapersAction() {
        hideAllPapers()
    }

    @objc private func newTodoAction() {
        createPaper(type: PaperKind.todo.rawValue, show: true)
    }

    @objc private func newNoteAction() {
        createPaper(type: PaperKind.note.rawValue, show: true)
    }

    @objc private func showPaperAction(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let index = state.papers.firstIndex(where: { $0.id == id }) else {
            return
        }
        state.papers[index].isVisible = true
        showPaper(state.papers[index])
        arrangeDeepCapsules(animated: state.enableAnimations)
        markDirty()
    }

    @objc private func openSettingsAction() {
        let controller: SettingsWindowController
        if let existing = settingsWindowController {
            existing.updateState(state)
            controller = existing
        } else {
            let created = SettingsWindowController(state: state)
            created.delegate = self
            settingsWindowController = created
            controller = created
        }
        controller.window?.center()
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func deletePaperAction(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let index = state.papers.firstIndex(where: { $0.id == id }) else {
            return
        }

        let alert = NSAlert()
        alert.messageText = L10n.text(.deletePaperTitle)
        alert.informativeText = L10n.text(.deletePaperMessage)
        alert.addButton(withTitle: L10n.text(.delete))
        alert.addButton(withTitle: L10n.text(.cancel))
        alert.alertStyle = .warning
        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        let deletedPaper = state.papers[index]
        if deletedPaper.type == PaperKind.note.rawValue {
            clearMissingLinkedNote(id: deletedPaper.id)
        }
        windows[id]?.close()
        windows.removeValue(forKey: id)
        state.papers.remove(at: index)
        refreshWindowLinkedNotes()
        rebuildStatusMenu()
        arrangeDeepCapsules(animated: state.enableAnimations)
        markDirty()
    }

    @objc private func openDataDirectoryAction() {
        NSWorkspace.shared.open(store.directoryURL)
    }

    @objc private func importDataAction() {
        let panel = NSOpenPanel()
        panel.title = L10n.text(.importPanelTitle)
        panel.prompt = L10n.text(.importPrompt)
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            try importData(from: url, requiresConfirmation: true, showsResultAlert: true)
        } catch {
            showImportFailureAlert(error: error)
        }
    }

    @objc private func quitAction() {
        NSApp.terminate(nil)
    }

    private func markDirty() {
        guard canSaveState else { return }
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.syncWindowFrames()
            self?.saveNow()
        }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: item)
    }

    private func saveNow() {
        guard canSaveState else { return }
        do {
            try store.save(state)
        } catch {
            NSLog("PaperTodo failed to save state: \(error)")
        }
    }

    private func syncWindowFrames() {
        for controller in windows.values {
            if let index = state.papers.firstIndex(where: { $0.id == controller.paper.id }) {
                state.papers[index] = controller.paper
            }
        }
    }

    private func replaceStateWithImportedState(_ importedState: AppState) {
        hideMasterCapsule()
        masterCapsuleWindowController = nil

        for controller in windows.values {
            controller.delegate = nil
            controller.close()
        }
        windows.removeAll()

        state = importedState
        for index in state.papers.indices where state.papers[index].isVisible {
            showPaper(state.papers[index])
        }

        settingsWindowController?.updateState(state)
        refreshWindowLinkedNotes()
        rebuildStatusMenu()
        arrangeDeepCapsules(animated: false)
    }

    private func persistImportedState(_ importedState: AppState) throws {
        saveWorkItem?.cancel()
        syncWindowFrames()
        try store.save(state)
        try store.replace(with: importedState)
    }

    private func importData(from url: URL, requiresConfirmation: Bool, showsResultAlert: Bool) throws {
        let importedState = try store.loadState(from: url)
        if requiresConfirmation, !confirmImport(from: url, importedState: importedState) {
            return
        }
        try persistImportedState(importedState)
        replaceStateWithImportedState(importedState)
        if showsResultAlert {
            showImportSuccessAlert(importedState: importedState)
        }
    }

    private func refreshWindowPalettes() {
        let palette = palette
        for controller in windows.values {
            controller.updatePalette(palette)
        }
        masterCapsuleWindowController?.updatePalette(palette)
    }

    private func refreshWindowAppState() {
        for controller in windows.values {
            controller.updateAppState(state)
        }
        masterCapsuleWindowController?.updateCollectionBehavior(PaperWindowController.collectionBehavior(for: state))
        refreshWindowLinkedNotes()
        arrangeDeepCapsules(animated: state.enableAnimations)
    }

    private func refreshWindowLinkedNotes() {
        let summaries = linkedNoteSummaries()
        for controller in windows.values {
            controller.updateLinkedNotes(summaries)
        }
    }

    private func arrangeDeepCapsules(animated: Bool) {
        var plan = CapsuleArrangementPlan.make(state: state, slottedPaperCount: 0)
        guard plan.usesDeepCapsules else {
            hideMasterCapsule()
            if plan.clearsCollapseAllActive {
                state.capsuleCollapseAllActive = false
            }
            for controller in windows.values {
                controller.clearDeepCapsule(animated: animated)
                controller.setCollapseAllFaceHidden(false)
            }
            return
        }

        let slottedControllers = state.papers.compactMap { paper -> PaperWindowController? in
            guard let controller = windows[paper.id] else {
                return nil
            }
            let shouldOccupySlot = CapsuleSlotPolicy.shouldOccupySlot(
                paper: paper,
                occupiesWindowSlot: controller.occupiesDeepCapsuleSlot,
                state: state,
                isLinkedNote: isLinkedNote(paper)
            )
            if !shouldOccupySlot {
                controller.clearDeepCapsule(animated: animated)
                controller.setCollapseAllFaceHidden(false)
                return nil
            }
            return controller
        }

        plan = CapsuleArrangementPlan.make(state: state, slottedPaperCount: slottedControllers.count)
        if plan.showsMasterCapsule {
            showMasterCapsule(animated: animated)
        } else {
            hideMasterCapsule()
            if plan.clearsCollapseAllActive {
                state.capsuleCollapseAllActive = false
            }
        }

        var slot = plan.firstPaperSlot
        for controller in slottedControllers {
            controller.applyDeepCapsule(index: slot, animated: animated)
            controller.setCollapseAllFaceHidden(plan.hidesPaperFaces)
            slot += 1
        }

        for controller in windows.values where !controller.occupiesDeepCapsuleSlot {
            controller.clearDeepCapsule(animated: animated)
            controller.setCollapseAllFaceHidden(false)
        }
    }

    private func normalizeCapsuleStateAfterSettingsChange() {
        if !state.useCapsuleMode {
            for index in state.papers.indices where state.papers[index].isCollapsed {
                state.papers[index].isCollapsed = false
                windows[state.papers[index].id]?.updatePaper(state.papers[index])
            }
        }
        if !(state.useCapsuleMode && state.useDeepCapsuleMode && state.useCapsuleCollapseAll) {
            state.capsuleCollapseAllActive = false
        }
        if !state.enableTodoNoteLinks {
            clearAllLinkedNotes()
        }
    }

    private func showMasterCapsule(animated: Bool) {
        let controller: MasterCapsuleWindowController
        if let existing = masterCapsuleWindowController {
            controller = existing
        } else {
            let created = MasterCapsuleWindowController(
                palette: palette,
                active: state.capsuleCollapseAllActive,
                collectionBehavior: PaperWindowController.collectionBehavior(for: state)
            )
            created.delegate = self
            masterCapsuleWindowController = created
            controller = created
        }
        controller.updateCollectionBehavior(PaperWindowController.collectionBehavior(for: state))
        controller.show(active: state.capsuleCollapseAllActive, animated: animated)
    }

    private func hideMasterCapsule() {
        masterCapsuleWindowController?.hide()
    }

    private func linkedNoteSummaries() -> [LinkedNoteSummary] {
        state.papers
            .filter { $0.type == PaperKind.note.rawValue }
            .enumerated()
            .map { index, paper in
                LinkedNoteSummary(id: paper.id, title: PaperTitles.effectiveTitle(for: paper, number: index + 1))
            }
    }

    private func showLinkedNote(id: String) {
        guard let index = state.papers.firstIndex(where: { $0.id == id && $0.type == PaperKind.note.rawValue }) else {
            clearMissingLinkedNote(id: id)
            return
        }

        state.papers[index].isVisible = true
        state.papers[index].isCollapsed = false
        showPaper(state.papers[index])
        windows[id]?.updatePaper(state.papers[index])
        windows[id]?.show()
        rebuildStatusMenu()
        arrangeDeepCapsules(animated: state.enableAnimations)
        markDirty()
    }

    private func clearMissingLinkedNote(id: String) {
        var changed = false
        for paperIndex in state.papers.indices {
            for itemIndex in state.papers[paperIndex].items.indices where state.papers[paperIndex].items[itemIndex].linkedNoteId == id {
                state.papers[paperIndex].items[itemIndex].linkedNoteId = nil
                changed = true
            }
            windows[state.papers[paperIndex].id]?.updatePaper(state.papers[paperIndex])
        }
        if changed {
            refreshWindowLinkedNotes()
            markDirty()
        }
    }

    private func clearAllLinkedNotes() {
        var changed = false
        for paperIndex in state.papers.indices {
            for itemIndex in state.papers[paperIndex].items.indices where state.papers[paperIndex].items[itemIndex].linkedNoteId != nil {
                state.papers[paperIndex].items[itemIndex].linkedNoteId = nil
                changed = true
            }
            windows[state.papers[paperIndex].id]?.updatePaper(state.papers[paperIndex])
        }
        if changed {
            refreshWindowLinkedNotes()
        }
    }

    private func isLinkedNote(_ paper: PaperData) -> Bool {
        guard paper.type == PaperKind.note.rawValue else { return false }
        return state.papers.contains { candidate in
            candidate.items.contains { $0.linkedNoteId == paper.id }
        }
    }

    private func showLoginItemApprovalAlert() {
        let alert = NSAlert()
        alert.messageText = L10n.text(.loginApprovalTitle)
        alert.informativeText = L10n.text(.loginApprovalMessage)
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.text(.openSystemSettings))
        alert.addButton(withTitle: L10n.text(.later))
        if alert.runModal() == .alertFirstButtonReturn {
            LoginItemService.openSystemSettings()
        }
    }

    private func showLoginItemFailureAlert(error: Error) {
        let alert = NSAlert()
        alert.messageText = L10n.text(.loginFailureTitle)
        alert.informativeText = L10n.format(.loginFailureMessage, error.localizedDescription)
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.text(.ok))
        alert.runModal()
    }

    private func showStartupLoadFailureAlert(error: Error) {
        let alert = NSAlert()
        alert.messageText = L10n.text(.startupLoadFailureTitle)
        alert.informativeText = L10n.format(.startupLoadFailureMessage, error.localizedDescription)
        alert.alertStyle = .critical
        alert.addButton(withTitle: L10n.text(.quit))
        alert.runModal()
    }

    private func confirmImport(from url: URL, importedState: AppState) -> Bool {
        let alert = NSAlert()
        alert.messageText = L10n.text(.importConfirmTitle)
        alert.informativeText = L10n.format(.importConfirmMessage, url.path, importedState.papers.count)
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.text(.importReplace))
        alert.addButton(withTitle: L10n.text(.cancel))
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func showImportSuccessAlert(importedState: AppState) {
        let alert = NSAlert()
        alert.messageText = L10n.text(.importSuccessTitle)
        alert.informativeText = L10n.format(.importSuccessMessage, importedState.papers.count)
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.text(.ok))
        alert.runModal()
    }

    private func showImportFailureAlert(error: Error) {
        let alert = NSAlert()
        alert.messageText = L10n.text(.importFailureTitle)
        alert.informativeText = L10n.format(.importFailureMessage, error.localizedDescription)
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.text(.ok))
        alert.runModal()
    }
}

private extension NSMenuItem {
    convenience init(title: String, action: Selector?, keyEquivalent: String, target: AnyObject?) {
        self.init(title: title, action: action, keyEquivalent: keyEquivalent)
        self.target = target
    }
}
