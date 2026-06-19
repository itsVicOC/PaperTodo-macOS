import AppKit
import QuartzCore

final class PaperPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
protocol PaperWindowControllerDelegate: AnyObject {
    func paperWindowController(_ controller: PaperWindowController, didUpdate paper: PaperData)
    func paperWindowControllerDidRequestNewTodo(_ controller: PaperWindowController)
    func paperWindowControllerDidRequestNewNote(_ controller: PaperWindowController)
    func paperWindowControllerDidRequestClose(_ controller: PaperWindowController)
    func paperWindowControllerDidChangeCapsuleState(_ controller: PaperWindowController)
    func paperWindowController(_ controller: PaperWindowController, didRequestOpenLinkedNote noteID: String)
    func paperWindowController(_ controller: PaperWindowController, didDropDeepCapsuleAt screenY: CGFloat)
}

@MainActor
final class PaperWindowController: NSWindowController, NSWindowDelegate, PaperViewDelegate {
    weak var delegate: PaperWindowControllerDelegate?

    private(set) var paper: PaperData
    private var appState: AppState
    private var linkedNotes: [LinkedNoteSummary]
    private var paperView: PaperView
    private var palette: PaperPalette
    private var deepCapsuleIndex: Int?
    private var reservedCapsuleIndex: Int?
    private var reservedCapsuleWindow: NSPanel?
    private var reservedCapsuleTrackingArea: NSTrackingArea?
    private var reservedCapsuleLastExpandedTarget = false
    private var trackingArea: NSTrackingArea?
    private var isHoveringDeepCapsule = false
    private var lastDeepCapsuleExpandedTarget = false
    private var isDraggingDeepCapsule = false
    private var isPendingDeepCapsuleClick = false
    private var pendingDeepCapsuleClickTask: Task<Void, Never>?
    private var isCollapseAllFaceHidden = false
    private var isSuppressingFramePersistence = false
    private var lastProgrammaticFrame: NSRect?
    private var usesTemporaryDeepCapsuleExpansionFrame = false
    private var externalEditURL: URL?
    private var externalEditSource: DispatchSourceFileSystemObject?
    private var externalEditFileDescriptor: CInt = -1
    private var isWritingExternalEditFile = false
    private var dragStartMouseLocation: NSPoint = .zero
    private var dragStartFrame: NSRect = .zero
    private let deepCapsuleDragThreshold: CGFloat = 8

    init(paper: PaperData, appState: AppState, linkedNotes: [LinkedNoteSummary], palette: PaperPalette) {
        self.paper = paper
        self.appState = appState
        self.linkedNotes = linkedNotes
        self.palette = palette
        paperView = PaperView(paper: paper, appState: appState, linkedNotes: linkedNotes, palette: palette)

        let rect = NSRect(x: paper.x, y: paper.y, width: max(paper.width, PaperDefaults.minWidth), height: max(paper.height, PaperDefaults.minHeight))
        let window = PaperPanel(
            contentRect: rect,
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior = PaperWindowController.collectionBehavior(for: appState)
        window.level = paper.alwaysOnTop ? .floating : .normal
        window.contentView = paperView
        if paper.isCollapsed {
            let collapsedSize = appState.useCapsuleMode && appState.useDeepCapsuleMode
                ? CapsuleLayout.compactSize
                : CapsuleLayout.fullSize
            window.minSize = collapsedSize
            window.maxSize = collapsedSize
            window.setContentSize(collapsedSize)
        } else {
            window.minSize = NSSize(width: PaperDefaults.minWidth, height: PaperDefaults.minHeight)
            window.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        }

        super.init(window: window)
        window.delegate = self
        paperView.delegate = self
        refreshTrackingArea()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        guard !(isCollapseAllFaceHidden && paper.isCollapsed) else { return }
        window?.orderFrontRegardless()
    }

    func hide() {
        if usesTemporaryDeepCapsuleExpansionFrame, !paper.isCollapsed {
            restorePaperFrame()
            usesTemporaryDeepCapsuleExpansionFrame = false
        }
        isPendingDeepCapsuleClick = false
        isDraggingDeepCapsule = false
        pendingDeepCapsuleClickTask?.cancel()
        pendingDeepCapsuleClickTask = nil
        hideReservedCapsule()
        window?.orderOut(nil)
    }

    func updatePaper(_ paper: PaperData) {
        let wasCollapsed = self.paper.isCollapsed
        self.paper = paper
        paperView.updatePaper(paper)
        window?.level = paper.alwaysOnTop ? .floating : .normal
        if wasCollapsed != paper.isCollapsed {
            if paper.isCollapsed {
                usesTemporaryDeepCapsuleExpansionFrame = false
                applyWindowSizeLimits(forCollapsed: true)
                window?.setContentSize(capsuleSize())
            } else {
                usesTemporaryDeepCapsuleExpansionFrame = false
                applyWindowSizeLimits(forCollapsed: false)
                restorePaperFrame()
            }
        }
        refreshTrackingArea()
    }

    func updateAppState(_ state: AppState) {
        appState = state
        window?.collectionBehavior = Self.collectionBehavior(for: state)
        reservedCapsuleWindow?.collectionBehavior = Self.collectionBehavior(for: state)
        paperView.updateAppState(state)
        if !usesDeepCapsuleMode {
            if usesTemporaryDeepCapsuleExpansionFrame, !paper.isCollapsed {
                restorePaperFrame()
                usesTemporaryDeepCapsuleExpansionFrame = false
            }
            deepCapsuleIndex = nil
            setCollapseAllFaceHidden(false)
            hideReservedCapsule()
        } else if reservedCapsuleWindow != nil {
            hideReservedCapsule()
        }
        refreshTrackingArea()
    }

    func updateLinkedNotes(_ linkedNotes: [LinkedNoteSummary]) {
        self.linkedNotes = linkedNotes
        paperView.updateLinkedNotes(linkedNotes)
    }

    func updatePalette(_ palette: PaperPalette) {
        self.palette = palette
        paperView.updatePalette(palette)
        updateReservedCapsulePalette()
    }

    func windowDidMove(_ notification: Notification) {
        handleWindowFrameChanged()
    }

    func windowDidResize(_ notification: Notification) {
        refreshTrackingArea()
        handleWindowFrameChanged()
    }

    func windowWillClose(_ notification: Notification) {
        paper.isVisible = false
        stopExternalEditMonitoring()
        hideReservedCapsule()
        delegate?.paperWindowController(self, didUpdate: paper)
        delegate?.paperWindowControllerDidChangeCapsuleState(self)
    }

    func paperViewDidRequestNewTodo(_ view: PaperView) {
        delegate?.paperWindowControllerDidRequestNewTodo(self)
    }

    func paperViewDidRequestNewNote(_ view: PaperView) {
        delegate?.paperWindowControllerDidRequestNewNote(self)
    }

    func paperViewDidRequestToggleCollapse(_ view: PaperView) {
        let expandedFromDeepCapsule = paper.isCollapsed && deepCapsuleIndex != nil
        let previousDeepCapsuleIndex = deepCapsuleIndex
        if !paper.isCollapsed && !usesTemporaryDeepCapsuleExpansionFrame {
            persistFrame()
        }
        paper.isCollapsed.toggle()
        if paper.isCollapsed {
            hideReservedCapsule()
            usesTemporaryDeepCapsuleExpansionFrame = false
            applyWindowSizeLimits(forCollapsed: true)
            window?.setContentSize(capsuleSize())
        } else {
            applyWindowSizeLimits(forCollapsed: false)
            if expandedFromDeepCapsule, let previousDeepCapsuleIndex {
                expandFromDeepCapsule(index: previousDeepCapsuleIndex, animated: appState.enableAnimations)
            } else {
                restorePaperFrame()
            }
            deepCapsuleIndex = nil
            hideReservedCapsule()
        }
        paperView.updatePaper(paper)
        refreshTrackingArea()
        if !usesTemporaryDeepCapsuleExpansionFrame {
            persistFrame()
        }
        delegate?.paperWindowController(self, didUpdate: paper)
        delegate?.paperWindowControllerDidChangeCapsuleState(self)
    }

    func paperViewDidRequestToggleTopmost(_ view: PaperView) {
        paper.alwaysOnTop.toggle()
        window?.level = paper.alwaysOnTop ? .floating : .normal
        delegate?.paperWindowController(self, didUpdate: paper)
    }

    func paperViewDidRequestExternalOpen(_ view: PaperView) {
        guard paper.type == PaperKind.note.rawValue else { return }
        let extensionValue = appState.externalMarkdownExtension.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let safeTitle = paper.title.isEmpty ? "PaperTodo" : paper.title
        let fileName = safeTitle
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)
            .appendingPathExtension(extensionValue)
        do {
            isWritingExternalEditFile = true
            try paper.content.write(to: url, atomically: true, encoding: .utf8)
            isWritingExternalEditFile = false
            startExternalEditMonitoring(url: url)
            NSWorkspace.shared.open(url)
        } catch {
            isWritingExternalEditFile = false
            NSAlert(error: error).runModal()
        }
    }

    func paperViewDidRequestClose(_ view: PaperView) {
        paper.isVisible = false
        hide()
        delegate?.paperWindowControllerDidRequestClose(self)
        delegate?.paperWindowController(self, didUpdate: paper)
    }

    func paperView(_ view: PaperView, didUpdate paper: PaperData) {
        self.paper = paper
        delegate?.paperWindowController(self, didUpdate: paper)
    }

    func paperView(_ view: PaperView, didRequestOpenLinkedNote noteID: String) {
        delegate?.paperWindowController(self, didRequestOpenLinkedNote: noteID)
    }

    func paperView(_ view: PaperView, mouseDown event: NSEvent) {
        beginDeepCapsuleDrag(event: event)
    }

    func paperView(_ view: PaperView, mouseDragged event: NSEvent) {
        updateDeepCapsuleDrag(event: event)
    }

    func paperView(_ view: PaperView, mouseUp event: NSEvent) {
        endDeepCapsuleDrag(event: event)
    }

    func applyDeepCapsule(index: Int, animated: Bool) {
        guard paper.isVisible, usesDeepCapsuleMode else {
            deepCapsuleIndex = nil
            hideReservedCapsule()
            return
        }
        if !paper.isCollapsed, reservedCapsuleWindow != nil {
            reservedCapsuleIndex = index
            moveReservedCapsule(index: index, animated: animated)
            return
        }
        guard paper.isCollapsed else { return }
        deepCapsuleIndex = index
        window?.level = .floating
        applyWindowSizeLimits(forCollapsed: true)
        window?.setContentSize(CapsuleLayout.compactSize)
        moveToDeepCapsuleFrame(expanded: isHoveringDeepCapsule, animated: animated)
        if !isCollapseAllFaceHidden {
            window?.orderFrontRegardless()
        }
        refreshTrackingArea()
    }

    func clearDeepCapsule(animated: Bool) {
        deepCapsuleIndex = nil
        isHoveringDeepCapsule = false
        isPendingDeepCapsuleClick = false
        isDraggingDeepCapsule = false
        setCollapseAllFaceHidden(false)
        hideReservedCapsule()
        guard paper.isCollapsed else { return }
        applyWindowSizeLimits(forCollapsed: true)
        window?.setContentSize(CapsuleLayout.fullSize)
        refreshTrackingArea()
    }

    func setCollapseAllFaceHidden(_ hidden: Bool) {
        guard isCollapseAllFaceHidden != hidden else { return }
        isCollapseAllFaceHidden = hidden
        if hidden {
            if paper.isCollapsed {
                window?.orderOut(nil)
            }
            reservedCapsuleWindow?.orderOut(nil)
        } else if paper.isVisible {
            window?.orderFrontRegardless()
            reservedCapsuleWindow?.orderFrontRegardless()
        }
    }

    var occupiesDeepCapsuleSlot: Bool {
        paper.isVisible && (paper.isCollapsed || reservedCapsuleWindow != nil)
    }

    func deepCapsuleDropIndex(for screenY: CGFloat, count: Int) -> Int {
        let baseIndex = appState.useCapsuleCollapseAll ? 1 : 0
        let layoutIndex = CapsuleLayout.index(for: screenY, count: count, on: deepCapsuleDragWindow?.screen ?? window?.screen ?? NSScreen.main, startIndex: baseIndex)
        return max(0, layoutIndex - baseIndex)
    }

    override func mouseEntered(with event: NSEvent) {
        guard !isDraggingDeepCapsule, usesDeepCapsuleMode else { return }
        let isReservedEvent = isReservedCapsuleTrackingEvent(event)
        guard (paper.isCollapsed && !isReservedEvent && deepCapsuleIndex != nil) ||
            (!paper.isCollapsed && isReservedEvent && reservedCapsuleIndex != nil) else {
            return
        }
        isHoveringDeepCapsule = true
        if paper.isCollapsed {
            moveToDeepCapsuleFrame(expanded: true, animated: appState.enableAnimations)
        } else {
            moveReservedCapsule(expanded: true, animated: appState.enableAnimations)
        }
    }

    override func mouseExited(with event: NSEvent) {
        guard !isDraggingDeepCapsule, usesDeepCapsuleMode else { return }
        let isReservedEvent = isReservedCapsuleTrackingEvent(event)
        guard (paper.isCollapsed && !isReservedEvent && deepCapsuleIndex != nil) ||
            (!paper.isCollapsed && isReservedEvent && reservedCapsuleIndex != nil) else {
            return
        }
        scheduleDeepCapsuleCollapseCheck()
    }

    override func mouseDown(with event: NSEvent) {
        guard beginDeepCapsuleDrag(event: event) else {
            super.mouseDown(with: event)
            return
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard updateDeepCapsuleDrag(event: event) else {
            super.mouseDragged(with: event)
            return
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard endDeepCapsuleDrag(event: event) else {
            super.mouseUp(with: event)
            return
        }
    }

    @discardableResult
    private func beginDeepCapsuleDrag(event: NSEvent, forReservedCapsule: Bool = false) -> Bool {
        beginDeepCapsuleDrag(at: NSEvent.mouseLocation, forReservedCapsule: forReservedCapsule)
    }

    @discardableResult
    private func beginDeepCapsuleDrag(at mouseLocation: NSPoint, forReservedCapsule: Bool = false) -> Bool {
        let canDragCollapsedCapsule = paper.isCollapsed && !forReservedCapsule && deepCapsuleIndex != nil
        let canDragReservedCapsule = !paper.isCollapsed && forReservedCapsule && reservedCapsuleIndex != nil
        guard canDragCollapsedCapsule || canDragReservedCapsule else {
            return false
        }
        guard usesDeepCapsuleMode, currentDeepCapsuleSlotIndex != nil, let dragWindow = deepCapsuleDragWindow else {
            return false
        }
        isPendingDeepCapsuleClick = true
        isDraggingDeepCapsule = false
        isHoveringDeepCapsule = true
        dragStartMouseLocation = mouseLocation
        dragStartFrame = dragWindow.frame
        if paper.isCollapsed {
            moveToDeepCapsuleFrame(expanded: true, animated: false)
            scheduleDeepCapsuleClickActivation()
        } else {
            moveReservedCapsule(expanded: true, animated: false)
        }
        return true
    }

    @discardableResult
    private func updateDeepCapsuleDrag(event: NSEvent) -> Bool {
        updateDeepCapsuleDrag(to: NSEvent.mouseLocation)
    }

    @discardableResult
    private func updateDeepCapsuleDrag(to mouseLocation: NSPoint) -> Bool {
        guard (isDraggingDeepCapsule || isPendingDeepCapsuleClick), let dragWindow = deepCapsuleDragWindow else {
            return false
        }
        if isPendingDeepCapsuleClick {
            let deltaX = abs(mouseLocation.x - dragStartMouseLocation.x)
            let deltaY = abs(mouseLocation.y - dragStartMouseLocation.y)
            guard deltaY >= deepCapsuleDragThreshold else {
                if deltaX >= deepCapsuleDragThreshold {
                    pendingDeepCapsuleClickTask?.cancel()
                    pendingDeepCapsuleClickTask = nil
                    isPendingDeepCapsuleClick = false
                }
                return true
            }
            pendingDeepCapsuleClickTask?.cancel()
            pendingDeepCapsuleClickTask = nil
            isPendingDeepCapsuleClick = false
            isDraggingDeepCapsule = true
        }
        guard isDraggingDeepCapsule else { return true }
        var frame = dragStartFrame
        frame.origin.y += mouseLocation.y - dragStartMouseLocation.y
        if let visible = dragWindow.screen?.visibleFrame {
            frame.origin.y = min(max(frame.origin.y, visible.minY + CapsuleLayout.topMargin), visible.maxY - frame.height - CapsuleLayout.topMargin)
        }
        frame.origin.x = CapsuleLayout.frame(for: currentDeepCapsuleSlotIndex ?? 0, on: dragWindow.screen, expanded: true).origin.x
        dragWindow.setFrame(frame, display: true)
        return true
    }

    @discardableResult
    private func endDeepCapsuleDrag(event: NSEvent) -> Bool {
        guard let dragWindow = deepCapsuleDragWindow else {
            return false
        }
        return endDeepCapsuleDrag(screenY: dragWindow.frame.midY)
    }

    @discardableResult
    private func endDeepCapsuleDrag(screenY: CGFloat) -> Bool {
        guard isDraggingDeepCapsule || isPendingDeepCapsuleClick else {
            return false
        }
        if isPendingDeepCapsuleClick {
            pendingDeepCapsuleClickTask?.cancel()
            pendingDeepCapsuleClickTask = nil
            isPendingDeepCapsuleClick = false
            isHoveringDeepCapsule = false
            activateFromDeepCapsule()
            return true
        }
        guard deepCapsuleDragWindow != nil else {
            isDraggingDeepCapsule = false
            isHoveringDeepCapsule = false
            return false
        }
        isDraggingDeepCapsule = false
        isHoveringDeepCapsule = false
        delegate?.paperWindowController(self, didDropDeepCapsuleAt: screenY)
        return true
    }

    private func activateFromDeepCapsule() {
        guard paper.isCollapsed, deepCapsuleIndex != nil else { return }
        isPendingDeepCapsuleClick = false
        pendingDeepCapsuleClickTask?.cancel()
        pendingDeepCapsuleClickTask = nil
        paperViewDidRequestToggleCollapse(paperView)
    }

    private func scheduleDeepCapsuleClickActivation() {
        pendingDeepCapsuleClickTask?.cancel()
        pendingDeepCapsuleClickTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(90))
            guard let self,
                  !Task.isCancelled,
                  self.isPendingDeepCapsuleClick,
                  !self.isDraggingDeepCapsule,
                  self.paper.isCollapsed,
                  self.deepCapsuleIndex != nil else {
                return
            }
            self.activateFromDeepCapsule()
        }
    }

    private func persistFrame() {
        guard let frame = window?.frame else { return }
        guard !isSuppressingFramePersistence else { return }
        if !paper.isCollapsed {
            paper.x = frame.origin.x
            paper.y = frame.origin.y
            paper.width = frame.width
            paper.height = frame.height
            delegate?.paperWindowController(self, didUpdate: paper)
        }
    }

    private func restorePaperFrame() {
        applyWindowSizeLimits(forCollapsed: false)
        let frame = NSRect(
            x: paper.x,
            y: paper.y,
            width: max(paper.width, PaperDefaults.minWidth),
            height: max(paper.height, PaperDefaults.minHeight)
        )
        moveWindowWithoutFramePersistence {
            window?.setFrame(frame, display: true)
        }
    }

    private func startExternalEditMonitoring(url: URL) {
        if externalEditURL == url, externalEditSource != nil {
            return
        }
        stopExternalEditMonitoring()
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        externalEditURL = url
        externalEditFileDescriptor = descriptor
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .attrib, .delete, .rename],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.externalEditFileDidChange()
            }
        }
        source.setCancelHandler { [descriptor] in
            Darwin.close(descriptor)
        }
        externalEditSource = source
        source.resume()
    }

    private func stopExternalEditMonitoring() {
        externalEditSource?.cancel()
        externalEditSource = nil
        externalEditURL = nil
        externalEditFileDescriptor = -1
    }

    private func externalEditFileDidChange() {
        guard !isWritingExternalEditFile,
              paper.type == PaperKind.note.rawValue,
              let url = externalEditURL else {
            return
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            stopExternalEditMonitoring()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            Task { @MainActor [weak self] in
                self?.reloadExternalEditFile()
            }
        }
    }

    private func reloadExternalEditFile() {
        guard !isWritingExternalEditFile,
              paper.type == PaperKind.note.rawValue,
              let url = externalEditURL,
              let content = try? String(contentsOf: url, encoding: .utf8),
              content != paper.content else {
            return
        }
        paper.content = content
        paperView.updatePaper(paper)
        delegate?.paperWindowController(self, didUpdate: paper)
    }

    private func handleWindowFrameChanged() {
        guard let frame = window?.frame else { return }
        if isSuppressingFramePersistence || isProgrammaticFrame(frame) {
            return
        }
        if usesTemporaryDeepCapsuleExpansionFrame, !paper.isCollapsed {
            usesTemporaryDeepCapsuleExpansionFrame = false
        }
        persistFrame()
    }

    private func moveWindowWithoutFramePersistence(_ move: () -> Void) {
        let wasSuppressing = isSuppressingFramePersistence
        isSuppressingFramePersistence = true
        move()
        lastProgrammaticFrame = window?.frame
        isSuppressingFramePersistence = wasSuppressing
    }

    private func isProgrammaticFrame(_ frame: NSRect) -> Bool {
        guard let lastProgrammaticFrame else { return false }
        let tolerance: CGFloat = 0.5
        if abs(frame.origin.x - lastProgrammaticFrame.origin.x) <= tolerance,
           abs(frame.origin.y - lastProgrammaticFrame.origin.y) <= tolerance,
           abs(frame.width - lastProgrammaticFrame.width) <= tolerance,
           abs(frame.height - lastProgrammaticFrame.height) <= tolerance {
            return true
        }
        self.lastProgrammaticFrame = nil
        return false
    }

    private func expandFromDeepCapsule(index: Int, animated: Bool) {
        guard let window else { return }
        let screen = preferredCapsuleScreen()
        let target = CapsuleLayout.expandedPaperFrame(
            currentFrame: window.frame,
            normalSize: NSSize(width: paper.width, height: paper.height),
            minSize: NSSize(width: PaperDefaults.minWidth, height: PaperDefaults.minHeight),
            on: screen,
            reservedCapsuleWidth: 0,
            reservesEdgeCapsule: false
        )
        usesTemporaryDeepCapsuleExpansionFrame = true
        if animated {
            let wasSuppressing = isSuppressingFramePersistence
            isSuppressingFramePersistence = true
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(target, display: true)
            } completionHandler: { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.lastProgrammaticFrame = target
                    self.isSuppressingFramePersistence = wasSuppressing
                }
            }
        } else {
            moveWindowWithoutFramePersistence {
                window.setFrame(target, display: true)
            }
        }
    }

    private var usesDeepCapsuleMode: Bool {
        appState.useCapsuleMode && appState.useDeepCapsuleMode
    }

    private func capsuleSize() -> NSSize {
        usesDeepCapsuleMode ? CapsuleLayout.compactSize : CapsuleLayout.fullSize
    }

    private func applyWindowSizeLimits(forCollapsed collapsed: Bool) {
        guard let window else { return }
        if collapsed {
            let size = capsuleSize()
            window.minSize = size
            window.maxSize = size
            return
        }

        window.minSize = NSSize(width: PaperDefaults.minWidth, height: PaperDefaults.minHeight)
        window.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    }

    private func moveToDeepCapsuleFrame(expanded: Bool, animated: Bool) {
        guard let window, let index = deepCapsuleIndex else { return }
        let screen = preferredCapsuleScreen()
        guard lastDeepCapsuleExpandedTarget != expanded || window.frame != CapsuleLayout.frame(for: index, on: screen, expanded: expanded) else {
            return
        }
        let target = CapsuleLayout.frame(for: index, on: screen, expanded: expanded)
        lastDeepCapsuleExpandedTarget = expanded
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = CapsuleLayout.slideDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                window.animator().setFrame(target, display: true)
            }
        } else {
            window.setFrame(target, display: true)
        }
    }

    private func shouldKeepDeepCapsuleExpanded() -> Bool {
        guard let dragWindow = deepCapsuleDragWindow, let index = currentDeepCapsuleSlotIndex else { return false }
        let expandedFrame = CapsuleLayout.frame(for: index, on: dragWindow.screen ?? preferredCapsuleScreen(), expanded: true)
        return CapsuleLayout.hoverRetainFrame(for: expandedFrame).contains(NSEvent.mouseLocation)
    }

    private func scheduleDeepCapsuleCollapseCheck() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            guard let self, !self.isDraggingDeepCapsule, self.usesDeepCapsuleMode, self.currentDeepCapsuleSlotIndex != nil else { return }
            guard !self.shouldKeepDeepCapsuleExpanded() else { return }
            self.isHoveringDeepCapsule = false
            if self.paper.isCollapsed {
                self.moveToDeepCapsuleFrame(expanded: false, animated: self.appState.enableAnimations)
            } else {
                self.moveReservedCapsule(expanded: false, animated: self.appState.enableAnimations)
            }
        }
    }

    private func moveReservedCapsule(index: Int, animated: Bool) {
        moveReservedCapsule(index: index, expanded: isHoveringDeepCapsule, animated: animated)
    }

    private func moveReservedCapsule(expanded: Bool, animated: Bool) {
        guard let reservedCapsuleIndex else { return }
        moveReservedCapsule(index: reservedCapsuleIndex, expanded: expanded, animated: animated)
    }

    private func moveReservedCapsule(index: Int, expanded: Bool, animated: Bool) {
        guard let reservedCapsuleWindow else { return }
        let target = CapsuleLayout.frame(for: index, on: reservedCapsuleWindow.screen ?? preferredCapsuleScreen(), expanded: expanded)
        guard reservedCapsuleLastExpandedTarget != expanded || reservedCapsuleWindow.frame != target else {
            return
        }
        reservedCapsuleLastExpandedTarget = expanded
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = CapsuleLayout.slideDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                reservedCapsuleWindow.animator().setFrame(target, display: true)
            }
        } else {
            reservedCapsuleWindow.setFrame(target, display: true)
        }
    }

    private func hideReservedCapsule() {
        reservedCapsuleIndex = nil
        reservedCapsuleLastExpandedTarget = false
        isHoveringDeepCapsule = false
        isPendingDeepCapsuleClick = false
        isDraggingDeepCapsule = false
        pendingDeepCapsuleClickTask?.cancel()
        pendingDeepCapsuleClickTask = nil
        if let reservedCapsuleTrackingArea, let content = reservedCapsuleWindow?.contentView {
            content.removeTrackingArea(reservedCapsuleTrackingArea)
        }
        reservedCapsuleTrackingArea = nil
        reservedCapsuleWindow?.orderOut(nil)
        reservedCapsuleWindow = nil
    }

    private func updateReservedCapsulePalette() {
        guard let content = reservedCapsuleWindow?.contentView else { return }
        content.layer?.borderColor = palette.border.cgColor
        content.layer?.backgroundColor = palette.paper.cgColor
        for subview in content.subviews {
            if let label = subview as? NSTextField {
                label.textColor = palette.text
            }
        }
    }

    static func collectionBehavior(for state: AppState) -> NSWindow.CollectionBehavior {
        var behavior: NSWindow.CollectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        if state.showPapersOnAllSpaces {
            behavior.insert(.canJoinAllSpaces)
        }
        return behavior
    }

    @objc private func reservedCapsuleClicked() {
        guard !paper.isCollapsed else { return }
        paper.isCollapsed = true
        usesTemporaryDeepCapsuleExpansionFrame = false
        isHoveringDeepCapsule = false
        hideReservedCapsule()
        applyWindowSizeLimits(forCollapsed: true)
        window?.setContentSize(capsuleSize())
        paperView.updatePaper(paper)
        refreshTrackingArea()
        delegate?.paperWindowController(self, didUpdate: paper)
        delegate?.paperWindowControllerDidChangeCapsuleState(self)
    }

    @objc private func reservedCapsulePan(_ sender: NSPanGestureRecognizer) {
        guard let capsuleWindow = reservedCapsuleWindow else { return }
        let mouseLocation = NSEvent.mouseLocation
        switch sender.state {
        case .began:
            _ = beginDeepCapsuleDrag(at: mouseLocation, forReservedCapsule: true)
        case .changed:
            _ = updateDeepCapsuleDrag(to: mouseLocation)
        case .ended, .cancelled, .failed:
            _ = endDeepCapsuleDrag(screenY: capsuleWindow.frame.midY)
        default:
            break
        }
    }

    private func refreshTrackingArea() {
        guard let contentView = window?.contentView else { return }
        if let trackingArea {
            contentView.removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: contentView.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        contentView.addTrackingArea(area)
        trackingArea = area
    }

    private var currentDeepCapsuleSlotIndex: Int? {
        paper.isCollapsed ? deepCapsuleIndex : reservedCapsuleIndex
    }

    private func preferredCapsuleScreen() -> NSScreen? {
        let normalFrame = NSRect(
            x: paper.x,
            y: paper.y,
            width: max(paper.width, PaperDefaults.minWidth),
            height: max(paper.height, PaperDefaults.minHeight)
        )
        return CapsuleLayout.screen(forPaperFrame: normalFrame) ?? window?.screen ?? NSScreen.main
    }

    private var deepCapsuleDragWindow: NSWindow? {
        paper.isCollapsed ? window : reservedCapsuleWindow
    }

    private func isReservedCapsuleTrackingEvent(_ event: NSEvent) -> Bool {
        event.trackingArea?.userInfo?["reservedCapsule"] as? Bool == true
    }

    private func refreshReservedCapsuleTrackingArea(for content: NSView) {
        if let reservedCapsuleTrackingArea {
            content.removeTrackingArea(reservedCapsuleTrackingArea)
        }
        let area = NSTrackingArea(
            rect: content.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: ["reservedCapsule": true]
        )
        content.addTrackingArea(area)
        reservedCapsuleTrackingArea = area

        let pan = NSPanGestureRecognizer(target: self, action: #selector(reservedCapsulePan(_:)))
        content.addGestureRecognizer(pan)
    }
}
