import AppKit
import PaperTodoCore

private extension NSPasteboard.PasteboardType {
    static let paperTodoNoteID = NSPasteboard.PasteboardType("app.papertodo.mac.note-id")
}

private enum PaperUI {
    static let radiusSmall: CGFloat = 4
    static let radiusControl: CGFloat = 8
    static let radiusShell: CGFloat = 14
    static let headerHeight: CGFloat = 28
    static let contentTopGap: CGFloat = 8
}

@MainActor
protocol PaperViewDelegate: AnyObject {
    func paperViewDidRequestNewTodo(_ view: PaperView)
    func paperViewDidRequestNewNote(_ view: PaperView)
    func paperViewDidRequestToggleCollapse(_ view: PaperView)
    func paperViewDidRequestToggleTopmost(_ view: PaperView)
    func paperViewDidRequestExternalOpen(_ view: PaperView)
    func paperViewDidRequestClose(_ view: PaperView)
    func paperView(_ view: PaperView, didUpdate paper: PaperData)
    func paperView(_ view: PaperView, didRequestOpenLinkedNote noteID: String)
    func paperView(_ view: PaperView, mouseDown event: NSEvent)
    func paperView(_ view: PaperView, mouseDragged event: NSEvent)
    func paperView(_ view: PaperView, mouseUp event: NSEvent)
}

final class PaperView: NSView, NSTextFieldDelegate, NSTextViewDelegate {
    weak var delegate: PaperViewDelegate?

    private var paper: PaperData
    private var appState: AppState
    private var linkedNotes: [LinkedNoteSummary]
    private let titleLabel = NSTextField(labelWithString: "")
    private let kindLabel = NSTextField(labelWithString: "")
    private let pinButton = NSButton(title: "⌖", target: nil, action: nil)
    private let collapseButton = NSButton(title: "−", target: nil, action: nil)
    private let closeButton = NSButton(title: "×", target: nil, action: nil)
    private let newTodoButton = NSButton(title: "+✓", target: nil, action: nil)
    private let newNoteButton = NSButton(title: "+✎", target: nil, action: nil)
    private let externalOpenButton = NSButton(title: "MD", target: nil, action: nil)
    private let header = NSStackView()
    private let headerSeparator = PaperSeparatorView()
    private let stack = NSStackView()
    private let contentContainer = NSView()
    private var palette: PaperPalette
    private var contentMinHeightConstraint: NSLayoutConstraint?
    private var capsulePlaceholderConstraints: [NSLayoutConstraint] = []

    private var todoFields: [NSTextField] = []
    private var pendingTodoFocusIndex: Int?
    private var todoRowFrames: [Int: NSRect] = [:]
    private var todoDeleteDropFrame: NSRect = .zero
    private var contextTodoIndex: Int?
    private var todoDragState: TodoDragState?
    private var todoAppendView: TodoAppendView?
    private var noteDragStartPoint: NSPoint?
    private var linkedNoteDropTargetIndex: Int?
    private var todoUndoStack: [TodoHistoryEntry] = []
    private var todoRedoStack: [TodoHistoryEntry] = []
    private var todoEditingStartSnapshot: TodoHistoryEntry?
    private var isRestoringTodoHistory = false
    private var titleEditor: TitleTextField?
    private var titleBeforeEditing = ""
    private var isFinishingTitleEditing = false
    private var noteScrollView: NSScrollView?
    private var noteTextView: NSTextView?
    private var isApplyingMarkdownStyle = false
    private let maxTodoHistoryDepth = 100

    init(paper: PaperData, appState: AppState, linkedNotes: [LinkedNoteSummary], palette: PaperPalette) {
        self.paper = paper
        self.appState = appState
        self.linkedNotes = linkedNotes
        self.palette = palette
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = PaperUI.radiusShell
        layer?.borderWidth = 1
        registerForDraggedTypes([.paperTodoNoteID])
        build()
        applyPalette()
        render()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        if hit != nil, paper.isCollapsed, appState.useCapsuleMode, appState.useDeepCapsuleMode {
            return self
        }
        return hit
    }

    func updatePaper(_ paper: PaperData) {
        let shouldResetTodoHistory = self.paper.id != paper.id || self.paper.type != paper.type
        self.paper = paper
        if shouldResetTodoHistory {
            todoUndoStack.removeAll()
            todoRedoStack.removeAll()
            todoEditingStartSnapshot = nil
        }
        if isEditingCurrentNote {
            return
        }
        render()
    }

    func updateAppState(_ state: AppState) {
        appState = state
        if isEditingCurrentNote {
            return
        }
        render()
    }

    func updateLinkedNotes(_ linkedNotes: [LinkedNoteSummary]) {
        self.linkedNotes = linkedNotes
        if isEditingCurrentNote {
            return
        }
        render()
    }

    func updatePalette(_ palette: PaperPalette) {
        self.palette = palette
        applyPalette()
        if isEditingCurrentNote {
            return
        }
        render()
    }

    private func build() {
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 3
        header.translatesAutoresizingMaskIntoConstraints = false
        header.heightAnchor.constraint(equalToConstant: PaperUI.headerHeight).isActive = true

        configureChromeButton(pinButton, width: 22)
        configureChromeButton(collapseButton, width: 22)
        configureChromeButton(closeButton, width: 22)
        configureChromeButton(newTodoButton, width: 22)
        configureChromeButton(newNoteButton, width: 22)
        configureChromeButton(externalOpenButton, width: 30)

        pinButton.target = self
        pinButton.action = #selector(toggleTopmost)
        collapseButton.target = self
        collapseButton.action = #selector(toggleCollapse)
        closeButton.target = self
        closeButton.action = #selector(close)
        newTodoButton.target = self
        newTodoButton.action = #selector(newTodo)
        newNoteButton.target = self
        newNoteButton.action = #selector(newNote)
        externalOpenButton.target = self
        externalOpenButton.action = #selector(externalOpen)

        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let titleDoubleClick = NSClickGestureRecognizer(target: self, action: #selector(beginTitleEditing(_:)))
        titleDoubleClick.numberOfClicksRequired = 2
        titleLabel.addGestureRecognizer(titleDoubleClick)

        kindLabel.alignment = .center
        kindLabel.font = .systemFont(ofSize: 13, weight: .regular)
        kindLabel.setContentHuggingPriority(.required, for: .horizontal)
        kindLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        kindLabel.translatesAutoresizingMaskIntoConstraints = false
        kindLabel.widthAnchor.constraint(equalToConstant: 18).isActive = true

        header.addArrangedSubview(kindLabel)
        header.addArrangedSubview(titleLabel)
        header.addArrangedSubview(pinButton)
        header.addArrangedSubview(newTodoButton)
        header.addArrangedSubview(newNoteButton)
        header.addArrangedSubview(externalOpenButton)
        header.addArrangedSubview(collapseButton)
        header.addArrangedSubview(closeButton)

        headerSeparator.translatesAutoresizingMaskIntoConstraints = false
        headerSeparator.heightAnchor.constraint(equalToConstant: 1).isActive = true

        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = PaperUI.contentTopGap
        stack.edgeInsets = NSEdgeInsets(top: 3, left: 10, bottom: 12, right: 10)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(header)
        stack.addArrangedSubview(headerSeparator)
        stack.addArrangedSubview(contentContainer)
        addSubview(stack)

        let contentMinHeight = contentContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 80)
        contentMinHeightConstraint = contentMinHeight
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            contentMinHeight
        ])
    }

    private func configureChromeButton(_ button: NSButton, width: CGFloat = 28, height: CGFloat = 24) {
        button.isBordered = false
        button.font = .systemFont(ofSize: 12, weight: .regular)
        button.setButtonType(.momentaryChange)
        button.bezelStyle = .regularSquare
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: width).isActive = true
        button.heightAnchor.constraint(equalToConstant: height).isActive = true
    }

    private func applyPalette() {
        layer?.borderColor = palette.border.cgColor
        layer?.backgroundColor = palette.paper.cgColor
        titleLabel.textColor = palette.text
        kindLabel.textColor = palette.weakText
        headerSeparator.color = palette.border.withAlphaComponent(0.55)
        [pinButton, collapseButton, closeButton, newTodoButton, newNoteButton, externalOpenButton].forEach {
            $0.contentTintColor = palette.weakText
        }
    }

    private func render() {
        layer?.cornerRadius = paper.isCollapsed ? capsuleCornerRadius() : PaperUI.radiusShell
        stack.spacing = paper.isCollapsed ? 0 : PaperUI.contentTopGap
        stack.edgeInsets = paper.isCollapsed
            ? NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            : NSEdgeInsets(top: 3, left: 10, bottom: 12, right: 10)
        header.isHidden = paper.isCollapsed
        headerSeparator.isHidden = paper.isCollapsed
        contentMinHeightConstraint?.constant = paper.isCollapsed ? 0 : 80
        kindLabel.stringValue = paper.type == PaperKind.note.rawValue ? "✎" : "☑"
        kindLabel.font = .systemFont(ofSize: paper.type == PaperKind.note.rawValue ? 14 : 12, weight: .regular)
        pinButton.alphaValue = paper.alwaysOnTop ? 1.0 : 0.58
        pinButton.contentTintColor = paper.alwaysOnTop ? palette.text : palette.weakText
        titleLabel.stringValue = paper.title.isEmpty
            ? (paper.type == PaperKind.note.rawValue ? L10n.text(.notePaperTitle) : L10n.text(.todoPaperTitle))
            : paper.title
        titleEditor?.stringValue = paper.title
        collapseButton.title = "+"
        closeButton.title = appState.useCapsuleMode ? "─" : "×"
        externalOpenButton.title = externalOpenButtonLabel()
        newTodoButton.isHidden = !appState.showTopBarNewTodoButton
        newNoteButton.isHidden = !appState.showTopBarNewNoteButton
        externalOpenButton.isHidden = paper.type != PaperKind.note.rawValue || !appState.showTopBarExternalOpenButton

        clearContentContainer()
        todoFields.removeAll()
        todoRowFrames.removeAll()
        todoDeleteDropFrame = .zero
        todoAppendView = nil
        noteScrollView = nil
        noteTextView = nil
        if paper.type != PaperKind.todo.rawValue || paper.isCollapsed {
            linkedNoteDropTargetIndex = nil
        }

        if paper.isCollapsed {
            newTodoButton.isHidden = true
            newNoteButton.isHidden = true
            externalOpenButton.isHidden = true
            closeButton.isHidden = true
            collapseButton.isHidden = false
            kindLabel.isHidden = true
            pinButton.isHidden = true
            titleLabel.isHidden = true
        } else {
            closeButton.isHidden = false
            collapseButton.isHidden = true
            kindLabel.isHidden = false
            pinButton.isHidden = false
            titleLabel.isHidden = false
        }

        if paper.isCollapsed {
            renderCapsulePlaceholder()
        } else if paper.type == PaperKind.note.rawValue {
            renderNote()
        } else {
            renderTodo()
        }
    }

    private func renderCapsulePlaceholder() {
        let content = NSStackView()
        content.orientation = .horizontal
        content.alignment = .centerY
        content.spacing = 4
        content.distribution = .fill
        content.edgeInsets = NSEdgeInsets(top: 0, left: 9, bottom: 0, right: 7)
        content.translatesAutoresizingMaskIntoConstraints = false

        let icon = NSTextField(labelWithString: paper.type == PaperKind.note.rawValue ? "✎" : "☑")
        icon.alignment = .center
        icon.font = .systemFont(ofSize: paper.type == PaperKind.note.rawValue ? 13 : 11, weight: .regular)
        icon.textColor = palette.weakText
        icon.setContentHuggingPriority(.required, for: .horizontal)
        icon.setContentCompressionResistancePriority(.required, for: .horizontal)
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 16).isActive = true

        let title = NSTextField(labelWithString: titleLabel.stringValue)
        title.font = .systemFont(ofSize: 12, weight: .medium)
        title.textColor = palette.text
        title.lineBreakMode = .byTruncatingTail
        title.setContentHuggingPriority(.defaultLow, for: .horizontal)
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        title.translatesAutoresizingMaskIntoConstraints = false
        title.widthAnchor.constraint(greaterThanOrEqualToConstant: 0).isActive = true

        let close = NSTextField(labelWithString: "×")
        close.alignment = .center
        close.font = .systemFont(ofSize: 12, weight: .regular)
        close.textColor = palette.weakText
        close.setContentHuggingPriority(.required, for: .horizontal)
        close.setContentCompressionResistancePriority(.required, for: .horizontal)
        close.translatesAutoresizingMaskIntoConstraints = false
        close.widthAnchor.constraint(equalToConstant: 14).isActive = true

        content.addArrangedSubview(icon)
        content.addArrangedSubview(title)
        content.addArrangedSubview(close)
        contentContainer.addSubview(content)
        capsulePlaceholderConstraints = [
            content.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            content.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            content.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
            content.widthAnchor.constraint(equalToConstant: capsuleContentSize().width),
            content.heightAnchor.constraint(equalToConstant: capsuleContentSize().height)
        ]
        NSLayoutConstraint.activate(capsulePlaceholderConstraints)
    }

    private func clearContentContainer() {
        NSLayoutConstraint.deactivate(capsulePlaceholderConstraints)
        capsulePlaceholderConstraints.removeAll()
        contentContainer.subviews.forEach { $0.removeFromSuperview() }
    }

    private func capsuleContentSize() -> NSSize {
        appState.useCapsuleMode && appState.useDeepCapsuleMode
            ? CapsuleLayout.compactSize
            : CapsuleLayout.fullSize
    }

    private func capsuleCornerRadius() -> CGFloat {
        let height = appState.useCapsuleMode && appState.useDeepCapsuleMode
            ? CapsuleLayout.compactSize.height
            : CapsuleLayout.fullSize.height
        return height / 2
    }

    private func renderTodo() {
        let vertical = NSStackView()
        vertical.orientation = .vertical
        vertical.alignment = .width
        vertical.distribution = .fill
        vertical.spacing = 0
        vertical.translatesAutoresizingMaskIntoConstraints = false

        let items = paper.items.isEmpty ? [PaperItem(text: "", done: false, order: 0)] : paper.items.sorted { $0.order < $1.order }
        for (index, item) in items.enumerated() {
            let row = TodoRowView(index: index)
            row.orientation = .horizontal
            row.alignment = .centerY
            row.distribution = .fill
            row.spacing = 3
            row.translatesAutoresizingMaskIntoConstraints = false
            row.configureHighlight(active: linkedNoteDropTargetIndex == index, palette: palette)

            let dragHandle = TodoDragHandleView(index: index)
            dragHandle.delegate = self

            let checkbox = TodoCheckboxView(checked: item.done, palette: palette, target: self, action: #selector(todoCheckboxChanged(_:)))
            checkbox.tag = index
            checkbox.setContentHuggingPriority(.required, for: .horizontal)
            checkbox.setContentCompressionResistancePriority(.required, for: .horizontal)

            let field = TodoTextField(todoString: item.text)
            field.placeholderString = index == items.count - 1 ? L10n.text(.todoPlaceholder) : ""
            field.textColor = item.done ? palette.weakText : palette.text
            field.tag = index
            field.todoDelegate = self
            field.setContentHuggingPriority(.defaultLow - 1, for: .horizontal)
            field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            field.setContentHuggingPriority(.defaultHigh, for: .vertical)
            field.setContentCompressionResistancePriority(.required, for: .vertical)
            field.widthAnchor.constraint(greaterThanOrEqualToConstant: 80).isActive = true
            field.heightAnchor.constraint(greaterThanOrEqualToConstant: TodoTextField.minimumHeight).isActive = true
            todoFields.append(field)

            row.addArrangedSubview(checkbox)
            row.addArrangedSubview(field)
            if appState.enableTodoNoteLinks, item.linkedNoteId != nil {
                row.addArrangedSubview(linkButton(for: item, at: index))
            }
            row.addArrangedSubview(dragHandle)
            vertical.addArrangedSubview(row)
        }

        if let lastRow = vertical.arrangedSubviews.last {
            vertical.setCustomSpacing(8, after: lastRow)
        }

        let footer = TodoAppendView(palette: palette)
        todoAppendView = footer
        let click = NSClickGestureRecognizer(target: self, action: #selector(addTodoItem))
        footer.addGestureRecognizer(click)
        vertical.addArrangedSubview(footer)

        contentContainer.addSubview(vertical)
        NSLayoutConstraint.activate([
            vertical.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            vertical.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            vertical.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            vertical.bottomAnchor.constraint(lessThanOrEqualTo: contentContainer.bottomAnchor)
        ])

        if let focusIndex = pendingTodoFocusIndex {
            pendingTodoFocusIndex = nil
            focusTodoField(at: focusIndex)
        }
        DispatchQueue.main.async { [weak self, weak vertical, weak footer] in
            guard let self, let vertical, let footer else { return }
            self.cacheTodoRowFrames(in: vertical, deleteView: footer)
        }
    }

    private func renderNote() {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let textView = MarkdownTextView()
        textView.font = .systemFont(ofSize: 14 * paper.textZoom)
        textView.textColor = palette.text
        textView.backgroundColor = .clear
        textView.insertionPointColor = palette.text
        textView.isRichText = false
        textView.allowsUndo = true
        textView.delegate = self
        textView.commandDelegate = self
        textView.textContainerInset = NSSize(width: 1, height: 2)
        textView.isAutomaticLinkDetectionEnabled = false
        textView.linkTextAttributes = [
            .foregroundColor: palette.active,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]

        scroll.documentView = textView
        noteScrollView = scroll
        noteTextView = textView
        applyMarkdownStyle(to: textView, preservingSelection: false)

        contentContainer.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])
    }

    override func mouseDown(with event: NSEvent) {
        if paper.isCollapsed && appState.useCapsuleMode && appState.useDeepCapsuleMode {
            delegate?.paperView(self, mouseDown: event)
            return
        }
        if canDragAsLinkedNote(at: convert(event.locationInWindow, from: nil)) {
            noteDragStartPoint = convert(event.locationInWindow, from: nil)
            return
        }
        noteDragStartPoint = nil
        window?.performDrag(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        if paper.isCollapsed && appState.useCapsuleMode && appState.useDeepCapsuleMode {
            delegate?.paperView(self, mouseDragged: event)
            return
        }
        if canDragAsLinkedNote, let start = noteDragStartPoint {
            let current = convert(event.locationInWindow, from: nil)
            let deltaX = abs(current.x - start.x)
            let deltaY = abs(current.y - start.y)
            if deltaX >= 4 || deltaY >= 4 {
                noteDragStartPoint = nil
                beginLinkedNoteDrag(with: event)
            }
            return
        }
        super.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        if paper.isCollapsed && appState.useCapsuleMode && appState.useDeepCapsuleMode {
            delegate?.paperView(self, mouseUp: event)
            return
        }
        noteDragStartPoint = nil
        super.mouseUp(with: event)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        guard !paper.isCollapsed else { return nil }
        let point = convert(event.locationInWindow, from: nil)
        if paper.type == PaperKind.todo.rawValue, let index = todoIndex(at: point) {
            contextTodoIndex = index
            return todoContextMenu(for: index)
        }
        contextTodoIndex = nil
        return paperContextMenu()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        linkedNoteDragOperation(for: sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        linkedNoteDragOperation(for: sender)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        updateLinkedNoteDropTarget(nil)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        linkedNoteID(from: sender) != nil && linkedNoteDropIndex(at: convert(sender.draggingLocation, from: nil)) != nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer { updateLinkedNoteDropTarget(nil) }
        guard let noteID = linkedNoteID(from: sender),
              let index = linkedNoteDropIndex(at: convert(sender.draggingLocation, from: nil)) else {
            return false
        }
        return linkDroppedNote(noteID, toTodoAt: index)
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        updateLinkedNoteDropTarget(nil)
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        persistTodoFields()
    }

    func textDidChange(_ notification: Notification) {
        guard !isApplyingMarkdownStyle else { return }
        guard let noteTextView else { return }
        guard !noteTextView.hasMarkedText() else { return }
        paper.content = noteTextView.string
        delegate?.paperView(self, didUpdate: paper)
    }

    func textDidEndEditing(_ notification: Notification) {
        if let noteTextView {
            paper.content = noteTextView.string
            applyMarkdownStyle(to: noteTextView, preservingSelection: true)
        }
    }

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        guard let url = link as? URL else { return false }
        NSWorkspace.shared.open(url)
        return true
    }

    @objc private func todoCheckboxChanged(_ sender: NSControl) {
        performTodoMutation(focusIndex: sender.tag) {
            guard sender.tag >= 0 && sender.tag < paper.items.count else { return }
            if let checkbox = sender as? TodoCheckboxView {
                paper.items[sender.tag].done = checkbox.isChecked
            } else if let button = sender as? NSButton {
                paper.items[sender.tag].done = button.state == .on
            }
        }
    }

    @objc private func linkButtonClicked(_ sender: NSButton) {
        persistTodoFields()
        let itemIndex = sender.tag
        guard itemIndex >= 0, itemIndex < paper.items.count else { return }

        let menu = NSMenu()
        if linkedNotes.isEmpty {
            let empty = NSMenuItem(title: L10n.text(.noLinkableNotes), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for note in linkedNotes {
                let item = NSMenuItem(title: note.title, action: #selector(selectLinkedNote(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = LinkMenuSelection(itemIndex: itemIndex, noteID: note.id)
                if paper.items[itemIndex].linkedNoteId == note.id {
                    item.state = .on
                }
                menu.addItem(item)
            }
        }

        if paper.items[itemIndex].linkedNoteId != nil {
            menu.addItem(.separator())
            let open = NSMenuItem(title: L10n.text(.openLinkedNote), action: #selector(openLinkedNote(_:)), keyEquivalent: "")
            open.target = self
            open.representedObject = itemIndex
            menu.addItem(open)

            let clear = NSMenuItem(title: L10n.text(.clearLinkedNote), action: #selector(clearLinkedNote(_:)), keyEquivalent: "")
            clear.target = self
            clear.representedObject = itemIndex
            menu.addItem(clear)
        }

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 2), in: sender)
    }

    @objc private func addTodoItem() {
        performTodoMutation {
            let newIndex = paper.items.count
            paper.items.append(PaperItem(text: "", done: false, order: newIndex))
            pendingTodoFocusIndex = newIndex
        }
    }

    @objc private func deleteTodoItem(_ sender: NSButton) {
        removeTodoItem(at: sender.tag, focusPrevious: true)
    }

    @objc private func clearCompletedTodos() {
        performTodoMutation {
            let remaining = paper.items.filter { !$0.done }
            paper.items = remaining.isEmpty ? [PaperItem(text: "", done: false, order: 0)] : remaining
            pendingTodoFocusIndex = min(paper.items.count - 1, 0)
        }
    }

    @objc private func contextInsertTodoBelow(_ sender: NSMenuItem) {
        guard let index = contextTodoIndex else { return }
        insertTodoItem(after: index)
    }

    @objc private func contextDeleteTodo(_ sender: NSMenuItem) {
        guard let index = contextTodoIndex else { return }
        removeTodoItem(at: index, focusPrevious: true)
    }

    @objc private func contextClearCompletedTodos(_ sender: NSMenuItem) {
        clearCompletedTodos()
    }

    @objc private func contextToggleTodoDone(_ sender: NSMenuItem) {
        guard let index = contextTodoIndex, index >= 0, index < paper.items.count else { return }
        performTodoMutation(focusIndex: index) {
            paper.items[index].done.toggle()
        }
    }

    @objc private func contextOpenLinkedNote(_ sender: NSMenuItem) {
        guard let index = contextTodoIndex,
              index >= 0,
              index < paper.items.count,
              let noteID = paper.items[index].linkedNoteId else {
            return
        }
        delegate?.paperView(self, didRequestOpenLinkedNote: noteID)
    }

    @objc private func contextClearLinkedNote(_ sender: NSMenuItem) {
        guard let index = contextTodoIndex, index >= 0, index < paper.items.count else { return }
        performTodoMutation(focusIndex: index) {
            paper.items[index].linkedNoteId = nil
        }
    }

    @objc private func contextSelectLinkedNote(_ sender: NSMenuItem) {
        guard let noteID = sender.representedObject as? String,
              let index = contextTodoIndex,
              index >= 0,
              index < paper.items.count else {
            return
        }
        performTodoMutation(focusIndex: index) {
            paper.items[index].linkedNoteId = noteID
        }
    }

    @objc private func contextBeginTitleEditing(_ sender: NSMenuItem) {
        beginTitleEditing(sender)
    }

    @objc private func beginTitleEditing(_ sender: Any?) {
        guard !paper.isCollapsed, titleEditor == nil else { return }
        titleBeforeEditing = paper.title
        let editor = TitleTextField(titleString: paper.title.isEmpty ? titleLabel.stringValue : paper.title)
        editor.titleDelegate = self
        editor.textColor = palette.text
        editor.translatesAutoresizingMaskIntoConstraints = false
        titleEditor = editor

        let titleIndex = header.arrangedSubviews.firstIndex(of: titleLabel) ?? 1
        header.removeArrangedSubview(titleLabel)
        titleLabel.removeFromSuperview()
        header.insertArrangedSubview(editor, at: titleIndex)
        titleLabel.isHidden = true
        editor.setContentHuggingPriority(.defaultLow, for: .horizontal)
        editor.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        window?.makeFirstResponder(editor)
        editor.currentEditor()?.selectAll(nil)
    }

    private func commitTitleEditing() {
        guard !isFinishingTitleEditing else { return }
        guard let editor = titleEditor else { return }
        let newTitle = editor.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        finishTitleEditing()
        guard paper.title != newTitle else { return }
        paper.title = newTitle
        titleLabel.stringValue = newTitle.isEmpty
            ? (paper.type == PaperKind.note.rawValue ? L10n.text(.notePaperTitle) : L10n.text(.todoPaperTitle))
            : newTitle
        delegate?.paperView(self, didUpdate: paper)
    }

    private func cancelTitleEditing() {
        guard !isFinishingTitleEditing else { return }
        guard titleEditor != nil else { return }
        finishTitleEditing()
        titleLabel.stringValue = titleBeforeEditing.isEmpty
            ? (paper.type == PaperKind.note.rawValue ? L10n.text(.notePaperTitle) : L10n.text(.todoPaperTitle))
            : titleBeforeEditing
    }

    private func finishTitleEditing() {
        guard let editor = titleEditor else { return }
        isFinishingTitleEditing = true
        window?.makeFirstResponder(nil)
        let titleIndex = header.arrangedSubviews.firstIndex(of: editor) ?? 1
        header.removeArrangedSubview(editor)
        editor.removeFromSuperview()
        header.insertArrangedSubview(titleLabel, at: titleIndex)
        titleLabel.isHidden = paper.isCollapsed
        titleEditor = nil
        isFinishingTitleEditing = false
    }

    @objc private func toggleCollapse() {
        delegate?.paperViewDidRequestToggleCollapse(self)
    }

    @objc private func toggleTopmost() {
        delegate?.paperViewDidRequestToggleTopmost(self)
    }

    @objc private func close() {
        if appState.useCapsuleMode {
            delegate?.paperViewDidRequestToggleCollapse(self)
        } else {
            delegate?.paperViewDidRequestClose(self)
        }
    }

    @objc private func externalOpen() {
        delegate?.paperViewDidRequestExternalOpen(self)
    }

    @objc private func newTodo() {
        delegate?.paperViewDidRequestNewTodo(self)
    }

    @objc private func newNote() {
        delegate?.paperViewDidRequestNewNote(self)
    }

    @discardableResult
    private func persistTodoFields(notify: Bool = true) -> Bool {
        ensureTodoItems()
        let originalItems = paper.items
        for field in todoFields {
            guard field.tag >= 0 && field.tag < paper.items.count else { continue }
            paper.items[field.tag].text = field.stringValue
        }
        paper.items = paper.items.enumerated().map { index, item in
            var updated = item
            updated.order = index
            return updated
        }
        let changed = !todoItemsEqual(originalItems, paper.items)
        if changed && notify {
            delegate?.paperView(self, didUpdate: paper)
        }
        return changed
    }

    private func removeTodoItem(at index: Int, focusPrevious: Bool) {
        performTodoMutation(focusIndex: index) {
            guard index >= 0, index < paper.items.count else { return }
            if paper.items.count == 1 {
                paper.items[0].text = ""
                paper.items[0].done = false
                paper.items[0].linkedNoteId = nil
                pendingTodoFocusIndex = 0
            } else {
                paper.items.remove(at: index)
                pendingTodoFocusIndex = focusPrevious ? max(0, index - 1) : min(index, paper.items.count - 1)
            }
        }
    }

    private func insertTodoItem(after index: Int) {
        performTodoMutation(focusIndex: index) {
            let insertionIndex = min(max(index + 1, 0), paper.items.count)
            paper.items.insert(PaperItem(text: "", done: false, order: insertionIndex), at: insertionIndex)
            pendingTodoFocusIndex = insertionIndex
        }
    }

    private func insertTodoLines(_ lines: [String], at index: Int) {
        performTodoMutation(focusIndex: index) {
            guard index >= 0, index < paper.items.count else { return }
            let normalizedLines = Array(lines.map(normalizePastedTodoLine).filter { !$0.isEmpty }.prefix(200))
            guard !normalizedLines.isEmpty else { return }

            paper.items[index].text = normalizedLines[0]
            if normalizedLines.count > 1 {
                let inserted = normalizedLines.dropFirst().enumerated().map { offset, text in
                    PaperItem(text: text, done: false, order: index + offset + 1)
                }
                paper.items.insert(contentsOf: inserted, at: min(index + 1, paper.items.count))
            }
            pendingTodoFocusIndex = min(index + normalizedLines.count - 1, paper.items.count - 1)
        }
    }

    private func renumber(_ items: [PaperItem]) -> [PaperItem] {
        items.enumerated().map { index, item in
            var updated = item
            updated.order = index
            return updated
        }
    }

    private func cacheTodoRowFrames(in stack: NSStackView, deleteView: NSView) {
        todoRowFrames.removeAll()
        for view in stack.arrangedSubviews {
            guard let row = view as? TodoRowView else { continue }
            todoRowFrames[row.index] = convert(row.bounds, from: row)
        }
        todoDeleteDropFrame = convert(deleteView.bounds, from: deleteView)
    }

    private func moveTodoItem(from sourceIndex: Int, to proposedIndex: Int) {
        performTodoMutation(focusIndex: sourceIndex) {
            guard sourceIndex >= 0, sourceIndex < paper.items.count else { return }
            let targetIndex = min(max(proposedIndex, 0), paper.items.count - 1)
            guard sourceIndex != targetIndex else { return }
            let item = paper.items.remove(at: sourceIndex)
            paper.items.insert(item, at: targetIndex)
            pendingTodoFocusIndex = targetIndex
        }
    }

    private func performTodoMutation(focusIndex: Int? = nil, _ mutate: () -> Void) {
        let before = todoHistoryEntry(focusIndex: focusIndex)
        todoEditingStartSnapshot = nil
        persistTodoFields(notify: false)
        mutate()
        paper.items = renumber(paper.items)
        ensureTodoItems()
        let after = todoHistoryEntry(focusIndex: pendingTodoFocusIndex ?? focusIndex)
        guard before != after else {
            render()
            return
        }
        pushTodoUndo(before)
        todoRedoStack.removeAll()
        delegate?.paperView(self, didUpdate: paper)
        render()
    }

    private func todoHistoryEntry(focusIndex: Int? = nil) -> TodoHistoryEntry {
        TodoHistoryEntry(items: renumber(paper.items), focusIndex: focusIndex)
    }

    private func pushTodoUndo(_ entry: TodoHistoryEntry) {
        guard !isRestoringTodoHistory else { return }
        if todoUndoStack.last != entry {
            todoUndoStack.append(entry)
        }
        if todoUndoStack.count > maxTodoHistoryDepth {
            todoUndoStack.removeFirst(todoUndoStack.count - maxTodoHistoryDepth)
        }
    }

    private func pushTodoRedo(_ entry: TodoHistoryEntry) {
        if todoRedoStack.last != entry {
            todoRedoStack.append(entry)
        }
        if todoRedoStack.count > maxTodoHistoryDepth {
            todoRedoStack.removeFirst(todoRedoStack.count - maxTodoHistoryDepth)
        }
    }

    private func restoreTodoHistory(_ entry: TodoHistoryEntry) {
        isRestoringTodoHistory = true
        paper.items = entry.items.isEmpty ? [PaperItem(text: "", done: false, order: 0)] : renumber(entry.items)
        pendingTodoFocusIndex = entry.focusIndex
        delegate?.paperView(self, didUpdate: paper)
        render()
        isRestoringTodoHistory = false
    }

    private func undoTodoHistory() {
        persistTodoFields(notify: false)
        guard let previous = todoUndoStack.popLast() else { return }
        pushTodoRedo(todoHistoryEntry(focusIndex: currentTodoFocusIndex()))
        restoreTodoHistory(previous)
    }

    private func redoTodoHistory() {
        persistTodoFields(notify: false)
        guard let next = todoRedoStack.popLast() else { return }
        pushTodoUndo(todoHistoryEntry(focusIndex: currentTodoFocusIndex()))
        restoreTodoHistory(next)
    }

    private func beginTodoTextEditing(at index: Int) {
        todoEditingStartSnapshot = todoHistoryEntry(focusIndex: index)
    }

    private func commitTodoTextEditing(focusIndex: Int?) {
        guard let before = todoEditingStartSnapshot else {
            _ = persistTodoFields()
            return
        }
        todoEditingStartSnapshot = nil
        persistTodoFields(notify: false)
        let after = todoHistoryEntry(focusIndex: focusIndex)
        guard before != after else { return }
        pushTodoUndo(before)
        todoRedoStack.removeAll()
        delegate?.paperView(self, didUpdate: paper)
    }

    private func currentTodoFocusIndex() -> Int? {
        guard let responder = window?.firstResponder else { return nil }
        if let field = responder as? TodoTextField {
            return field.tag
        }
        if let editor = responder as? NSTextView,
           let field = todoFields.first(where: { window?.fieldEditor(false, for: $0) === editor }) {
            return field.tag
        }
        return nil
    }

    private var isEditingCurrentNote: Bool {
        guard paper.type == PaperKind.note.rawValue,
              let noteTextView,
              let responder = window?.firstResponder else {
            return false
        }
        return responder === noteTextView
    }

    private func todoItemsEqual(_ lhs: [PaperItem], _ rhs: [PaperItem]) -> Bool {
        TodoHistoryEntry(items: renumber(lhs), focusIndex: nil).items == TodoHistoryEntry(items: renumber(rhs), focusIndex: nil).items
    }

    private func todoDropIndex(for point: NSPoint) -> Int {
        guard !todoRowFrames.isEmpty else { return 0 }
        let ordered = todoRowFrames.sorted { $0.key < $1.key }
        for (index, frame) in ordered {
            if point.y > frame.midY {
                return index
            }
        }
        return ordered.last?.key ?? 0
    }

    private func isTodoDeleteDrop(at point: NSPoint) -> Bool {
        todoDeleteDropFrame.insetBy(dx: -8, dy: -8).contains(point)
    }

    private func todoIndex(at point: NSPoint) -> Int? {
        todoRowFrames
            .sorted { $0.key < $1.key }
            .first { $0.value.insetBy(dx: -8, dy: -4).contains(point) }?
            .key
    }

    private func todoContextMenu(for index: Int) -> NSMenu {
        let menu = NSMenu(title: L10n.text(.todoPaperTitle))
        let item = index >= 0 && index < paper.items.count ? paper.items[index] : nil

        let toggle = NSMenuItem(title: item?.done == true ? L10n.text(.markTodoUndone) : L10n.text(.markTodoDone), action: #selector(contextToggleTodoDone(_:)), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)

        let insert = NSMenuItem(title: L10n.text(.insertTodoBelow), action: #selector(contextInsertTodoBelow(_:)), keyEquivalent: "")
        insert.target = self
        menu.addItem(insert)

        let delete = NSMenuItem(title: L10n.text(.deleteTodoTooltip), action: #selector(contextDeleteTodo(_:)), keyEquivalent: "")
        delete.target = self
        menu.addItem(delete)

        let clearCompleted = NSMenuItem(title: L10n.text(.clearCompleted), action: #selector(contextClearCompletedTodos(_:)), keyEquivalent: "")
        clearCompleted.target = self
        clearCompleted.isEnabled = paper.items.contains(where: \.done)
        menu.addItem(clearCompleted)

        if appState.enableTodoNoteLinks {
            menu.addItem(.separator())
            let linkRoot = NSMenuItem(title: L10n.text(.linkNoteTooltip), action: nil, keyEquivalent: "")
            let linkMenu = NSMenu(title: L10n.text(.linkNoteTooltip))
            if linkedNotes.isEmpty {
                let empty = NSMenuItem(title: L10n.text(.noLinkableNotes), action: nil, keyEquivalent: "")
                empty.isEnabled = false
                linkMenu.addItem(empty)
            } else {
                for note in linkedNotes {
                    let noteItem = NSMenuItem(title: note.title, action: #selector(contextSelectLinkedNote(_:)), keyEquivalent: "")
                    noteItem.target = self
                    noteItem.representedObject = note.id
                    noteItem.state = item?.linkedNoteId == note.id ? .on : .off
                    linkMenu.addItem(noteItem)
                }
            }
            menu.setSubmenu(linkMenu, for: linkRoot)
            menu.addItem(linkRoot)

            if item?.linkedNoteId != nil {
                let open = NSMenuItem(title: L10n.text(.openLinkedNote), action: #selector(contextOpenLinkedNote(_:)), keyEquivalent: "")
                open.target = self
                menu.addItem(open)

                let clear = NSMenuItem(title: L10n.text(.clearLinkedNote), action: #selector(contextClearLinkedNote(_:)), keyEquivalent: "")
                clear.target = self
                menu.addItem(clear)
            }
        }
        return menu
    }

    private func paperContextMenu() -> NSMenu {
        let menu = NSMenu(title: titleLabel.stringValue)

        let rename = NSMenuItem(title: L10n.text(.renamePaper), action: #selector(contextBeginTitleEditing(_:)), keyEquivalent: "")
        rename.target = self
        menu.addItem(rename)

        let topmost = NSMenuItem(title: L10n.text(.toggleTopmost), action: #selector(toggleTopmost), keyEquivalent: "")
        topmost.target = self
        topmost.state = paper.alwaysOnTop ? .on : .off
        menu.addItem(topmost)

        let collapse = NSMenuItem(title: L10n.text(.collapsePaper), action: #selector(toggleCollapse), keyEquivalent: "")
        collapse.target = self
        menu.addItem(collapse)

        menu.addItem(.separator())
        let newTodoItem = NSMenuItem(title: L10n.text(.newTodo), action: #selector(newTodo), keyEquivalent: "")
        newTodoItem.target = self
        menu.addItem(newTodoItem)

        let newNoteItem = NSMenuItem(title: L10n.text(.newNote), action: #selector(newNote), keyEquivalent: "")
        newNoteItem.target = self
        menu.addItem(newNoteItem)

        if paper.type == PaperKind.note.rawValue {
            menu.addItem(.separator())
            let external = NSMenuItem(title: L10n.text(.externalOpen), action: #selector(externalOpen), keyEquivalent: "")
            external.target = self
            menu.addItem(external)
        }
        return menu
    }

    private func deleteButton(for index: Int) -> NSButton {
        let button = NSButton(title: "×", target: self, action: #selector(deleteTodoItem(_:)))
        button.isBordered = false
        button.font = .systemFont(ofSize: 13, weight: .medium)
        button.contentTintColor = palette.weakText
        button.toolTip = L10n.text(.deleteTodoTooltip)
        button.tag = index
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 22).isActive = true
        button.heightAnchor.constraint(equalToConstant: 22).isActive = true
        return button
    }

    private func focusTodoField(at index: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let targetIndex = min(max(index, 0), self.todoFields.count - 1)
            guard targetIndex >= 0, targetIndex < self.todoFields.count else { return }
            self.window?.makeFirstResponder(self.todoFields[targetIndex])
            if let editor = self.window?.fieldEditor(true, for: self.todoFields[targetIndex]) as? NSTextView {
                editor.setSelectedRange(NSRange(location: editor.string.count, length: 0))
            }
        }
    }

    private func normalizePastedTodoLine(_ line: String) -> String {
        var text = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let patterns = [
            #"^\s*[-*+]\s+\[[ xX]\]\s+"#,
            #"^\s*\d+[.)]\s+\[[ xX]\]\s+"#,
            #"^\s*[-*+]\s+"#,
            #"^\s*\d+[.)]\s+"#
        ]
        for pattern in patterns {
            if let range = text.range(of: pattern, options: .regularExpression) {
                text.removeSubrange(range)
                break
            }
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func applyMarkdownStyle(to textView: NSTextView, preservingSelection: Bool) {
        guard paper.type == PaperKind.note.rawValue else { return }
        guard !textView.hasMarkedText() else { return }
        let selection = textView.selectedRange()
        isApplyingMarkdownStyle = true
        let styled = MarkdownStyler.attributedString(
            from: paper.content,
            mode: appState.markdownRenderMode,
            baseFontSize: 14 * paper.textZoom,
            palette: palette
        )
        textView.textStorage?.setAttributedString(styled)
        textView.typingAttributes = [
            .font: NSFont.systemFont(ofSize: 14 * paper.textZoom),
            .foregroundColor: palette.text
        ]
        if preservingSelection {
            let maxLocation = min(selection.location, styled.length)
            let maxLength = min(selection.length, styled.length - maxLocation)
            textView.setSelectedRange(NSRange(location: maxLocation, length: maxLength))
        }
        isApplyingMarkdownStyle = false
    }

    private func applyMarkdownWrap(prefix: String, suffix: String, placeholder: String) {
        guard let textView = noteTextView else { return }
        let selected = textView.selectedRange()
        let current = textView.string as NSString
        let selectedText = selected.length > 0 ? current.substring(with: selected) : placeholder
        let replacement = prefix + selectedText + suffix
        textView.replaceCharacters(in: selected, with: replacement)
        let innerLocation = selected.location + (prefix as NSString).length
        textView.setSelectedRange(NSRange(location: innerLocation, length: (selectedText as NSString).length))
        paper.content = textView.string
        delegate?.paperView(self, didUpdate: paper)
        applyMarkdownStyle(to: textView, preservingSelection: true)
    }

    private func insertMarkdownLinePrefix(_ prefix: String) {
        guard let textView = noteTextView else { return }
        let selected = textView.selectedRange()
        let current = textView.string as NSString
        let lineRange = current.lineRange(for: NSRange(location: min(selected.location, current.length), length: 0))
        textView.replaceCharacters(in: NSRange(location: lineRange.location, length: 0), with: prefix)
        textView.setSelectedRange(NSRange(location: selected.location + (prefix as NSString).length, length: selected.length))
        paper.content = textView.string
        delegate?.paperView(self, didUpdate: paper)
        applyMarkdownStyle(to: textView, preservingSelection: true)
    }

    private func insertMarkdownRule() {
        guard let textView = noteTextView else { return }
        let selected = textView.selectedRange()
        let current = textView.string as NSString
        let insertion = selected.location > 0 && !current.substring(to: selected.location).hasSuffix("\n")
            ? "\n---\n"
            : "---\n"
        textView.replaceCharacters(in: selected, with: insertion)
        textView.setSelectedRange(NSRange(location: selected.location + (insertion as NSString).length, length: 0))
        paper.content = textView.string
        delegate?.paperView(self, didUpdate: paper)
        applyMarkdownStyle(to: textView, preservingSelection: true)
    }

    private func applyMarkdownLink() {
        guard let textView = noteTextView else { return }
        let selected = textView.selectedRange()
        let current = textView.string as NSString
        let selectedText = selected.length > 0 ? current.substring(with: selected) : L10n.text(.markdownLinkPlaceholder)
        let replacement = "[\(selectedText)](https://)"
        textView.replaceCharacters(in: selected, with: replacement)
        let urlLocation = selected.location + (selectedText as NSString).length + 3
        textView.setSelectedRange(NSRange(location: urlLocation, length: "https://".count))
        paper.content = textView.string
        delegate?.paperView(self, didUpdate: paper)
        applyMarkdownStyle(to: textView, preservingSelection: true)
    }

    private func adjustNoteZoom(by delta: Double) {
        guard let textView = noteTextView else { return }
        paper.textZoom = min(max((paper.textZoom + delta).rounded(toPlaces: 2), 0.5), 1.5)
        delegate?.paperView(self, didUpdate: paper)
        applyMarkdownStyle(to: textView, preservingSelection: true)
    }

    private func resetNoteZoom() {
        guard let textView = noteTextView else { return }
        paper.textZoom = 1.0
        delegate?.paperView(self, didUpdate: paper)
        applyMarkdownStyle(to: textView, preservingSelection: true)
    }

    private func linkButton(for item: PaperItem, at index: Int) -> NSButton {
        let noteTitle = item.linkedNoteId.flatMap(titleForLinkedNote)
        let title: String
        if appState.showLinkedNoteName, let noteTitle {
            title = noteTitle
        } else {
            title = item.linkedNoteId == nil ? "↗" : L10n.text(.linkedNoteLabel)
        }

        let button = NSButton(title: title, target: self, action: #selector(linkButtonClicked(_:)))
        button.isBordered = false
        button.font = .systemFont(ofSize: appState.showLinkedNoteName && noteTitle != nil ? 12 : 13, weight: .medium)
        button.contentTintColor = item.linkedNoteId == nil ? palette.weakText : palette.active
        button.lineBreakMode = .byTruncatingTail
        button.toolTip = item.linkedNoteId == nil ? L10n.text(.linkNoteTooltip) : L10n.text(.linkedNoteTooltip)
        button.tag = index
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(lessThanOrEqualToConstant: 96).isActive = true
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }

    private func externalOpenButtonLabel() -> String {
        let normalized = appState.externalMarkdownExtension.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let fallback = normalized.isEmpty ? "md" : normalized
        return String(fallback.prefix(2)).uppercased()
    }

    private func titleForLinkedNote(_ noteID: String) -> String? {
        linkedNotes.first(where: { $0.id == noteID })?.title
    }

    @objc private func selectLinkedNote(_ sender: NSMenuItem) {
        guard let selection = sender.representedObject as? LinkMenuSelection,
              selection.itemIndex >= 0,
              selection.itemIndex < paper.items.count else {
            return
        }
        performTodoMutation(focusIndex: selection.itemIndex) {
            paper.items[selection.itemIndex].linkedNoteId = selection.noteID
        }
    }

    @objc private func openLinkedNote(_ sender: NSMenuItem) {
        guard let itemIndex = sender.representedObject as? Int,
              itemIndex >= 0,
              itemIndex < paper.items.count,
              let noteID = paper.items[itemIndex].linkedNoteId else {
            return
        }
        delegate?.paperView(self, didRequestOpenLinkedNote: noteID)
    }

    @objc private func clearLinkedNote(_ sender: NSMenuItem) {
        guard let itemIndex = sender.representedObject as? Int,
              itemIndex >= 0,
              itemIndex < paper.items.count else {
            return
        }
        performTodoMutation(focusIndex: itemIndex) {
            paper.items[itemIndex].linkedNoteId = nil
        }
    }

    private var canDragAsLinkedNote: Bool {
        appState.enableTodoNoteLinks && !paper.isCollapsed && paper.type == PaperKind.note.rawValue
    }

    private func canDragAsLinkedNote(at point: NSPoint) -> Bool {
        guard canDragAsLinkedNote else { return false }
        return convert(titleLabel.bounds, from: titleLabel).insetBy(dx: -8, dy: -6).contains(point)
    }

    private var canReceiveLinkedNoteDrop: Bool {
        appState.enableTodoNoteLinks && !paper.isCollapsed && paper.type == PaperKind.todo.rawValue
    }

    private func beginLinkedNoteDrag(with event: NSEvent) {
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(paper.id, forType: .paperTodoNoteID)

        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        let title = titleLabel.stringValue.isEmpty ? L10n.text(.notePaperTitle) : titleLabel.stringValue
        let image = linkedNoteDragImage(title: title)
        let origin = convert(event.locationInWindow, from: nil)
        draggingItem.setDraggingFrame(
            NSRect(x: origin.x - image.size.width / 2, y: origin.y - image.size.height / 2, width: image.size.width, height: image.size.height),
            contents: image
        )
        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    private func linkedNoteDragImage(title: String) -> NSImage {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: palette.text
        ]
        let text = "↗ " + title
        let textSize = (text as NSString).size(withAttributes: attributes)
        let size = NSSize(width: min(max(textSize.width + 24, 72), 180), height: 30)
        let image = NSImage(size: size)
        image.lockFocus()
        let rect = NSRect(origin: .zero, size: size)
        palette.paper.withAlphaComponent(0.94).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()
        palette.border.setStroke()
        NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 8, yRadius: 8).stroke()
        (text as NSString).draw(in: rect.insetBy(dx: 10, dy: 7), withAttributes: attributes)
        image.unlockFocus()
        return image
    }

    private func linkedNoteDropIndex(at point: NSPoint) -> Int? {
        guard canReceiveLinkedNoteDrop, !todoRowFrames.isEmpty else { return nil }
        return todoRowFrames
            .sorted { $0.key < $1.key }
            .first { $0.value.insetBy(dx: -8, dy: -4).contains(point) }?
            .key
    }

    private func updateLinkedNoteDropTarget(_ index: Int?) {
        guard linkedNoteDropTargetIndex != index else { return }
        linkedNoteDropTargetIndex = index
        render()
    }

    private func linkDroppedNote(_ noteID: String, toTodoAt index: Int) -> Bool {
        guard canReceiveLinkedNoteDrop,
              linkedNotes.contains(where: { $0.id == noteID }),
              index >= 0,
              index < paper.items.count else {
            return false
        }
        performTodoMutation(focusIndex: index) {
            paper.items[index].linkedNoteId = noteID
        }
        return true
    }

    private func ensureTodoItems() {
        if paper.items.isEmpty {
            paper.items = [PaperItem(text: "", done: false, order: 0)]
        }
    }
}

extension PaperView: TodoTextFieldDelegate {
    fileprivate func todoTextFieldDidBeginEditing(_ field: TodoTextField) {
        beginTodoTextEditing(at: field.tag)
    }

    fileprivate func todoTextFieldDidEndEditing(_ field: TodoTextField) {
        commitTodoTextEditing(focusIndex: field.tag)
    }

    fileprivate func todoTextFieldDidPressReturn(_ field: TodoTextField) {
        insertTodoItem(after: field.tag)
    }

    fileprivate func todoTextFieldDidPressBackspaceOnEmpty(_ field: TodoTextField) {
        removeTodoItem(at: field.tag, focusPrevious: true)
    }

    fileprivate func todoTextField(_ field: TodoTextField, didPasteLines lines: [String]) {
        insertTodoLines(lines, at: field.tag)
    }

    fileprivate func todoTextFieldDidRequestUndo(_ field: TodoTextField) {
        undoTodoHistory()
    }

    fileprivate func todoTextFieldDidRequestRedo(_ field: TodoTextField) {
        redoTodoHistory()
    }
}

extension PaperView: TitleTextFieldDelegate {
    fileprivate func titleTextFieldDidCommit(_ field: TitleTextField) {
        commitTitleEditing()
    }

    fileprivate func titleTextFieldDidCancel(_ field: TitleTextField) {
        cancelTitleEditing()
    }
}

extension PaperView: NSDraggingSource {
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }

    private func linkedNoteDragOperation(for sender: NSDraggingInfo) -> NSDragOperation {
        guard linkedNoteID(from: sender) != nil else {
            updateLinkedNoteDropTarget(nil)
            return []
        }
        let index = linkedNoteDropIndex(at: convert(sender.draggingLocation, from: nil))
        updateLinkedNoteDropTarget(index)
        return index == nil ? [] : .copy
    }

    private func linkedNoteID(from sender: NSDraggingInfo) -> String? {
        guard canReceiveLinkedNoteDrop else { return nil }
        guard let noteID = sender.draggingPasteboard.string(forType: .paperTodoNoteID),
              linkedNotes.contains(where: { $0.id == noteID }) else {
            return nil
        }
        return noteID
    }
}

extension PaperView: TodoDragHandleViewDelegate {
    fileprivate func todoDragHandleDidBegin(_ handle: TodoDragHandleView, event: NSEvent) {
        persistTodoFields()
        todoDragState = TodoDragState(sourceIndex: handle.index)
        NSCursor.closedHand.set()
    }

    fileprivate func todoDragHandle(_ handle: TodoDragHandleView, didDrag event: NSEvent) {
        guard let state = todoDragState else { return }
        let point = convert(event.locationInWindow, from: nil)
        let targetIndex = todoDropIndex(for: point)
        let deleting = isTodoDeleteDrop(at: point)
        todoDragState = TodoDragState(sourceIndex: state.sourceIndex, currentIndex: targetIndex, isOverDelete: deleting)
        todoAppendView?.setTrashMode(active: true, hovered: deleting)
        window?.invalidateCursorRects(for: self)
    }

    fileprivate func todoDragHandle(_ handle: TodoDragHandleView, didEnd event: NSEvent) {
        defer {
            todoDragState = nil
            todoAppendView?.setTrashMode(active: false)
            NSCursor.arrow.set()
        }
        guard let state = todoDragState else { return }
        let point = convert(event.locationInWindow, from: nil)
        if isTodoDeleteDrop(at: point) {
            removeTodoItem(at: state.sourceIndex, focusPrevious: true)
        } else {
            moveTodoItem(from: state.sourceIndex, to: todoDropIndex(for: point))
        }
    }
}

extension PaperView: MarkdownTextViewCommandDelegate {
    fileprivate func markdownTextViewDidRequestBold(_ textView: MarkdownTextView) {
        applyMarkdownWrap(prefix: "**", suffix: "**", placeholder: L10n.text(.markdownBoldPlaceholder))
    }

    fileprivate func markdownTextViewDidRequestItalic(_ textView: MarkdownTextView) {
        applyMarkdownWrap(prefix: "*", suffix: "*", placeholder: L10n.text(.markdownItalicPlaceholder))
    }

    fileprivate func markdownTextViewDidRequestStrikethrough(_ textView: MarkdownTextView) {
        applyMarkdownWrap(prefix: "~~", suffix: "~~", placeholder: L10n.text(.markdownStrikethrough))
    }

    fileprivate func markdownTextViewDidRequestHeading(_ textView: MarkdownTextView) {
        insertMarkdownLinePrefix("# ")
    }

    fileprivate func markdownTextViewDidRequestQuote(_ textView: MarkdownTextView) {
        insertMarkdownLinePrefix("> ")
    }

    fileprivate func markdownTextViewDidRequestList(_ textView: MarkdownTextView) {
        insertMarkdownLinePrefix("- ")
    }

    fileprivate func markdownTextViewDidRequestOrderedList(_ textView: MarkdownTextView) {
        insertMarkdownLinePrefix("1. ")
    }

    fileprivate func markdownTextViewDidRequestRule(_ textView: MarkdownTextView) {
        insertMarkdownRule()
    }

    fileprivate func markdownTextViewDidRequestCodeBlock(_ textView: MarkdownTextView) {
        applyMarkdownWrap(prefix: "```\n", suffix: "\n```", placeholder: "code")
    }

    fileprivate func markdownTextViewDidRequestLink(_ textView: MarkdownTextView) {
        applyMarkdownLink()
    }

    fileprivate func markdownTextView(_ textView: MarkdownTextView, didRequestZoom delta: Double) {
        adjustNoteZoom(by: delta)
    }

    fileprivate func markdownTextViewDidRequestResetZoom(_ textView: MarkdownTextView) {
        resetNoteZoom()
    }
}

private struct LinkMenuSelection {
    let itemIndex: Int
    let noteID: String
}

private struct TodoDragState {
    let sourceIndex: Int
    var currentIndex: Int
    var isOverDelete: Bool

    init(sourceIndex: Int, currentIndex: Int? = nil, isOverDelete: Bool = false) {
        self.sourceIndex = sourceIndex
        self.currentIndex = currentIndex ?? sourceIndex
        self.isOverDelete = isOverDelete
    }
}

private struct TodoHistoryEntry: Equatable {
    let items: [PaperItem]
    let focusIndex: Int?
}

@MainActor
private protocol TodoTextFieldDelegate: AnyObject {
    func todoTextFieldDidBeginEditing(_ field: TodoTextField)
    func todoTextFieldDidEndEditing(_ field: TodoTextField)
    func todoTextFieldDidPressReturn(_ field: TodoTextField)
    func todoTextFieldDidPressBackspaceOnEmpty(_ field: TodoTextField)
    func todoTextField(_ field: TodoTextField, didPasteLines lines: [String])
    func todoTextFieldDidRequestUndo(_ field: TodoTextField)
    func todoTextFieldDidRequestRedo(_ field: TodoTextField)
}

@MainActor
private protocol TitleTextFieldDelegate: AnyObject {
    func titleTextFieldDidCommit(_ field: TitleTextField)
    func titleTextFieldDidCancel(_ field: TitleTextField)
}

@MainActor
private protocol TodoDragHandleViewDelegate: AnyObject {
    func todoDragHandleDidBegin(_ handle: TodoDragHandleView, event: NSEvent)
    func todoDragHandle(_ handle: TodoDragHandleView, didDrag event: NSEvent)
    func todoDragHandle(_ handle: TodoDragHandleView, didEnd event: NSEvent)
}

@MainActor
private protocol MarkdownTextViewCommandDelegate: AnyObject {
    func markdownTextViewDidRequestBold(_ textView: MarkdownTextView)
    func markdownTextViewDidRequestItalic(_ textView: MarkdownTextView)
    func markdownTextViewDidRequestStrikethrough(_ textView: MarkdownTextView)
    func markdownTextViewDidRequestHeading(_ textView: MarkdownTextView)
    func markdownTextViewDidRequestQuote(_ textView: MarkdownTextView)
    func markdownTextViewDidRequestList(_ textView: MarkdownTextView)
    func markdownTextViewDidRequestOrderedList(_ textView: MarkdownTextView)
    func markdownTextViewDidRequestRule(_ textView: MarkdownTextView)
    func markdownTextViewDidRequestCodeBlock(_ textView: MarkdownTextView)
    func markdownTextViewDidRequestLink(_ textView: MarkdownTextView)
    func markdownTextView(_ textView: MarkdownTextView, didRequestZoom delta: Double)
    func markdownTextViewDidRequestResetZoom(_ textView: MarkdownTextView)
}

private final class MarkdownTextView: NSTextView {
    weak var commandDelegate: MarkdownTextViewCommandDelegate?
    private var contextMenuLinkURL: URL?

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu(title: L10n.text(.edit))
        contextMenuLinkURL = markdownLinkURL(at: event.locationInWindow)
        if contextMenuLinkURL != nil {
            let openLink = NSMenuItem(title: L10n.text(.openMarkdownLink), action: #selector(openMarkdownLinkFromMenu(_:)), keyEquivalent: "")
            openLink.target = self
            menu.addItem(openLink)
            menu.addItem(.separator())
        }
        menu.addItem(NSMenuItem(title: L10n.text(.undo), action: Selector(("undo:")), keyEquivalent: "z"))
        menu.addItem(NSMenuItem(title: L10n.text(.redo), action: Selector(("redo:")), keyEquivalent: "Z"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: L10n.text(.cut), action: #selector(cut(_:)), keyEquivalent: "x"))
        menu.addItem(NSMenuItem(title: L10n.text(.copy), action: #selector(copy(_:)), keyEquivalent: "c"))
        menu.addItem(NSMenuItem(title: L10n.text(.paste), action: #selector(paste(_:)), keyEquivalent: "v"))
        menu.addItem(NSMenuItem(title: L10n.text(.selectAll), action: #selector(selectAll(_:)), keyEquivalent: "a"))
        menu.addItem(.separator())

        let markdownItem = NSMenuItem(title: L10n.text(.markdownFormat), action: nil, keyEquivalent: "")
        let markdownMenu = NSMenu(title: L10n.text(.markdownFormat))
        markdownMenu.addItem(NSMenuItem(title: L10n.text(.markdownBold), action: #selector(applyMarkdownBold(_:)), keyEquivalent: "b"))
        markdownMenu.addItem(NSMenuItem(title: L10n.text(.markdownItalic), action: #selector(applyMarkdownItalic(_:)), keyEquivalent: "i"))
        markdownMenu.addItem(NSMenuItem(title: L10n.text(.markdownStrikethrough), action: #selector(applyMarkdownStrikethrough(_:)), keyEquivalent: ""))
        markdownMenu.addItem(.separator())
        markdownMenu.addItem(NSMenuItem(title: L10n.text(.markdownHeading), action: #selector(applyMarkdownHeading(_:)), keyEquivalent: ""))
        markdownMenu.addItem(NSMenuItem(title: L10n.text(.markdownQuote), action: #selector(applyMarkdownQuote(_:)), keyEquivalent: ""))
        markdownMenu.addItem(NSMenuItem(title: L10n.text(.markdownList), action: #selector(applyMarkdownList(_:)), keyEquivalent: ""))
        markdownMenu.addItem(NSMenuItem(title: L10n.text(.markdownOrderedList), action: #selector(applyMarkdownOrderedList(_:)), keyEquivalent: ""))
        markdownMenu.addItem(NSMenuItem(title: L10n.text(.markdownRule), action: #selector(applyMarkdownRule(_:)), keyEquivalent: ""))
        markdownMenu.addItem(NSMenuItem(title: L10n.text(.markdownCodeBlock), action: #selector(applyMarkdownCodeBlock(_:)), keyEquivalent: ""))
        markdownMenu.addItem(.separator())
        markdownMenu.addItem(NSMenuItem(title: L10n.text(.markdownLink), action: #selector(applyMarkdownLink(_:)), keyEquivalent: "k"))
        menu.setSubmenu(markdownMenu, for: markdownItem)
        menu.addItem(markdownItem)

        let zoomItem = NSMenuItem(title: L10n.text(.resetZoom), action: nil, keyEquivalent: "")
        let zoomMenu = NSMenu(title: L10n.text(.resetZoom))
        zoomMenu.addItem(NSMenuItem(title: L10n.text(.zoomIn), action: #selector(zoomIn(_:)), keyEquivalent: "+"))
        zoomMenu.addItem(NSMenuItem(title: L10n.text(.zoomOut), action: #selector(zoomOut(_:)), keyEquivalent: "-"))
        zoomMenu.addItem(NSMenuItem(title: L10n.text(.resetZoom), action: #selector(resetMarkdownZoom(_:)), keyEquivalent: "0"))
        menu.setSubmenu(zoomMenu, for: zoomItem)
        menu.addItem(zoomItem)
        return menu
    }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command),
           let url = markdownLinkURL(at: event.locationInWindow) {
            NSWorkspace.shared.open(url)
            return
        }
        super.mouseDown(with: event)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        guard window?.firstResponder == self else { return }
        if NSEvent.modifierFlags.contains(.command) {
            for rect in markdownLinkRects() {
                addCursorRect(rect, cursor: .pointingHand)
            }
        }
    }

    override func flagsChanged(with event: NSEvent) {
        window?.invalidateCursorRects(for: self)
        super.flagsChanged(with: event)
    }

    override func keyDown(with event: NSEvent) {
        guard event.modifierFlags.contains(.command),
              let characters = event.charactersIgnoringModifiers?.lowercased() else {
            super.keyDown(with: event)
            return
        }

        switch characters {
        case "b":
            commandDelegate?.markdownTextViewDidRequestBold(self)
        case "i":
            commandDelegate?.markdownTextViewDidRequestItalic(self)
        case "x" where event.modifierFlags.contains(.shift):
            commandDelegate?.markdownTextViewDidRequestStrikethrough(self)
        case "k":
            commandDelegate?.markdownTextViewDidRequestLink(self)
        case "+", "=":
            commandDelegate?.markdownTextView(self, didRequestZoom: 0.1)
        case "-":
            commandDelegate?.markdownTextView(self, didRequestZoom: -0.1)
        case "0":
            commandDelegate?.markdownTextViewDidRequestResetZoom(self)
        default:
            super.keyDown(with: event)
        }
    }

    override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            commandDelegate?.markdownTextView(self, didRequestZoom: event.scrollingDeltaY > 0 ? 0.1 : -0.1)
            return
        }
        super.scrollWheel(with: event)
    }

    @objc private func applyMarkdownBold(_ sender: Any?) {
        commandDelegate?.markdownTextViewDidRequestBold(self)
    }

    @objc private func applyMarkdownItalic(_ sender: Any?) {
        commandDelegate?.markdownTextViewDidRequestItalic(self)
    }

    @objc private func applyMarkdownStrikethrough(_ sender: Any?) {
        commandDelegate?.markdownTextViewDidRequestStrikethrough(self)
    }

    @objc private func applyMarkdownHeading(_ sender: Any?) {
        commandDelegate?.markdownTextViewDidRequestHeading(self)
    }

    @objc private func applyMarkdownQuote(_ sender: Any?) {
        commandDelegate?.markdownTextViewDidRequestQuote(self)
    }

    @objc private func applyMarkdownList(_ sender: Any?) {
        commandDelegate?.markdownTextViewDidRequestList(self)
    }

    @objc private func applyMarkdownOrderedList(_ sender: Any?) {
        commandDelegate?.markdownTextViewDidRequestOrderedList(self)
    }

    @objc private func applyMarkdownRule(_ sender: Any?) {
        commandDelegate?.markdownTextViewDidRequestRule(self)
    }

    @objc private func applyMarkdownCodeBlock(_ sender: Any?) {
        commandDelegate?.markdownTextViewDidRequestCodeBlock(self)
    }

    @objc private func applyMarkdownLink(_ sender: Any?) {
        commandDelegate?.markdownTextViewDidRequestLink(self)
    }

    @objc private func openMarkdownLinkFromMenu(_ sender: Any?) {
        guard let contextMenuLinkURL else { return }
        NSWorkspace.shared.open(contextMenuLinkURL)
    }

    @objc private func zoomIn(_ sender: Any?) {
        commandDelegate?.markdownTextView(self, didRequestZoom: 0.1)
    }

    @objc private func zoomOut(_ sender: Any?) {
        commandDelegate?.markdownTextView(self, didRequestZoom: -0.1)
    }

    @objc private func resetMarkdownZoom(_ sender: Any?) {
        commandDelegate?.markdownTextViewDidRequestResetZoom(self)
    }

    private func markdownLinkURL(at windowPoint: NSPoint) -> URL? {
        let point = convert(windowPoint, from: nil)
        guard let offset = characterOffset(at: point),
              let rawURL = MarkdownInlineParser.linkURL(in: string, at: offset) else {
            return nil
        }
        return URL(string: rawURL)
    }

    private func characterOffset(at point: NSPoint) -> Int? {
        guard let layoutManager,
              let textContainer else {
            return nil
        }

        var containerPoint = point
        let origin = textContainerOrigin
        containerPoint.x -= origin.x
        containerPoint.y -= origin.y
        guard containerPoint.x >= 0,
              containerPoint.y >= 0,
              containerPoint.x <= textContainer.containerSize.width else {
            return nil
        }

        let glyphIndex = layoutManager.glyphIndex(
            for: containerPoint,
            in: textContainer,
            fractionOfDistanceThroughGlyph: nil
        )
        guard glyphIndex < layoutManager.numberOfGlyphs else {
            return nil
        }

        let glyphRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: textContainer)
        guard glyphRect.insetBy(dx: -3, dy: -3).contains(containerPoint) else {
            return nil
        }

        return layoutManager.characterIndexForGlyph(at: glyphIndex)
    }

    private func markdownLinkRects() -> [NSRect] {
        guard let layoutManager,
              let textContainer else {
            return []
        }

        layoutManager.ensureLayout(for: textContainer)
        let origin = textContainerOrigin
        return MarkdownInlineParser.inlineSpans(in: string)
            .filter { $0.kind == .link }
            .compactMap { span in
                let glyphRange = layoutManager.glyphRange(
                    forCharacterRange: span.range,
                    actualCharacterRange: nil
                )
                guard glyphRange.length > 0 else { return nil }

                var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
                rect.origin.x += origin.x
                rect.origin.y += origin.y
                return rect.intersection(visibleRect)
            }
            .filter { !$0.isNull && !$0.isEmpty }
    }
}

private final class TodoRowView: NSStackView {
    let index: Int

    init(index: Int) {
        self.index = index
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(greaterThanOrEqualToConstant: 26).isActive = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configureHighlight(active: Bool, palette: PaperPalette) {
        wantsLayer = true
        layer?.cornerRadius = 5
        layer?.backgroundColor = active ? palette.hover.withAlphaComponent(0.9).cgColor : NSColor.clear.cgColor
    }
}

private final class PaperSeparatorView: NSView {
    var color: NSColor = .separatorColor {
        didSet {
            layer?.backgroundColor = color.cgColor
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = color.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class TodoCheckboxView: NSControl {
    var isChecked: Bool {
        didSet {
            needsDisplay = true
        }
    }

    private let palette: PaperPalette
    private var isHovering = false

    init(checked: Bool, palette: PaperPalette, target: AnyObject?, action: Selector?) {
        self.isChecked = checked
        self.palette = palette
        super.init(frame: NSRect(x: 0, y: 0, width: 22, height: 24))
        self.target = target
        self.action = action
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 20).isActive = true
        heightAnchor.constraint(greaterThanOrEqualToConstant: 24).isActive = true
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func updateTrackingAreas() {
        trackingAreas.forEach(removeTrackingArea)
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        isChecked.toggle()
        sendAction(action, to: target)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let box = NSRect(x: floor((bounds.width - 15) / 2), y: floor((bounds.height - 15) / 2), width: 15, height: 15)
        let path = NSBezierPath(roundedRect: box, xRadius: PaperUI.radiusSmall, yRadius: PaperUI.radiusSmall)
        if isChecked {
            palette.active.setFill()
            path.fill()
        } else {
            (isHovering ? palette.hover.withAlphaComponent(0.72) : .clear).setFill()
            path.fill()
            (isHovering ? palette.active.withAlphaComponent(0.72) : palette.weakText.withAlphaComponent(0.52)).setStroke()
            path.lineWidth = 1.3
            path.stroke()
        }

        guard isChecked else { return }
        let mark = NSBezierPath()
        mark.move(to: NSPoint(x: box.minX + 3.0, y: box.minY + 7.2))
        mark.line(to: NSPoint(x: box.minX + 6.2, y: box.minY + 4.4))
        mark.line(to: NSPoint(x: box.minX + 12.0, y: box.minY + 10.6))
        mark.lineCapStyle = .round
        mark.lineJoinStyle = .round
        mark.lineWidth = 1.9
        palette.paper.setStroke()
        mark.stroke()
    }
}

private final class TodoAppendView: NSView {
    private let label = NSTextField(labelWithString: "＋")
    private let palette: PaperPalette
    private var isTrashMode = false
    private var isHovered = false

    init(palette: PaperPalette) {
        self.palette = palette
        super.init(frame: .zero)
        build()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .iBeam)
    }

    override func updateTrackingAreas() {
        trackingAreas.forEach(removeTrackingArea)
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        updateAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        updateAppearance()
    }

    func setTrashMode(active: Bool, hovered: Bool = false) {
        isTrashMode = active
        isHovered = hovered
        updateAppearance()
    }

    private func build() {
        wantsLayer = true
        layer?.cornerRadius = PaperUI.radiusControl
        layer?.borderWidth = 1
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(greaterThanOrEqualToConstant: 29).isActive = true

        label.alignment = .center
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        updateAppearance()
    }

    private func updateAppearance() {
        if isTrashMode {
            label.stringValue = "⌫"
            label.font = .systemFont(ofSize: 13, weight: .medium)
            label.textColor = NSColor.systemRed.withAlphaComponent(isHovered ? 0.95 : 0.7)
            layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(isHovered ? 0.16 : 0.08).cgColor
            layer?.borderColor = NSColor.systemRed.withAlphaComponent(isHovered ? 0.72 : 0.38).cgColor
            layer?.borderWidth = isHovered ? 1.5 : 1
            return
        }

        label.stringValue = "＋"
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = palette.weakText.withAlphaComponent(isHovered ? 0.72 : 0.42)
        layer?.backgroundColor = palette.hover.withAlphaComponent(isHovered ? 0.24 : 0.1).cgColor
        layer?.borderColor = palette.border.withAlphaComponent(isHovered ? 0.72 : 0.42).cgColor
        layer?.borderWidth = 1
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

private final class TodoDragHandleView: NSView {
    weak var delegate: TodoDragHandleViewDelegate?
    let index: Int
    private let label = NSTextField(labelWithString: "≡")

    init(index: Int) {
        self.index = index
        super.init(frame: NSRect(x: 0, y: 0, width: 16, height: 22))
        build()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override func mouseDown(with event: NSEvent) {
        delegate?.todoDragHandleDidBegin(self, event: event)
    }

    override func mouseDragged(with event: NSEvent) {
        delegate?.todoDragHandle(self, didDrag: event)
    }

    override func mouseUp(with event: NSEvent) {
        delegate?.todoDragHandle(self, didEnd: event)
    }

    private func build() {
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 16).isActive = true
        heightAnchor.constraint(equalToConstant: 22).isActive = true

        label.alignment = .center
        label.font = .systemFont(ofSize: 11, weight: .regular)
        label.textColor = .secondaryLabelColor.withAlphaComponent(0.62)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}

private final class TitleTextField: NSTextField {
    weak var titleDelegate: TitleTextFieldDelegate?

    convenience init(titleString stringValue: String) {
        self.init(frame: .zero)
        self.stringValue = stringValue
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        controlSize = .small
        font = .systemFont(ofSize: 12, weight: .semibold)
        isBordered = false
        drawsBackground = false
        focusRingType = .none
        lineBreakMode = .byTruncatingTail
        cell?.usesSingleLineMode = true
        cell?.isScrollable = true
        cell?.wraps = false
        delegate = self
    }
}

extension TitleTextField: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        titleDelegate?.titleTextFieldDidCommit(self)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.insertNewline(_:)):
            titleDelegate?.titleTextFieldDidCommit(self)
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            titleDelegate?.titleTextFieldDidCancel(self)
            return true
        default:
            return false
        }
    }
}

private final class TodoTextField: NSTextField {
    static let minimumHeight: CGFloat = 22
    weak var todoDelegate: TodoTextFieldDelegate?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
        delegate = self
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
        delegate = self
    }

    convenience init(todoString stringValue: String) {
        self.init(frame: .zero)
        self.stringValue = stringValue
    }

    override var intrinsicContentSize: NSSize {
        let size = super.intrinsicContentSize
        return NSSize(width: size.width, height: max(size.height, Self.minimumHeight))
    }

    private func configure() {
        controlSize = .regular
        font = .systemFont(ofSize: 13.5)
        isBordered = false
        drawsBackground = false
        focusRingType = .none
        alignment = .left
        lineBreakMode = .byTruncatingTail
        cell?.usesSingleLineMode = true
        cell?.isScrollable = true
        cell?.wraps = false
        translatesAutoresizingMaskIntoConstraints = false
    }

    private func configureFieldEditor(_ editor: NSTextView) {
        editor.font = font ?? .systemFont(ofSize: 13.5)
        editor.textColor = textColor
        editor.insertionPointColor = textColor ?? .labelColor
        editor.backgroundColor = .clear
        editor.textContainerInset = NSSize(width: 0, height: 2)
    }
}

extension TodoTextField: NSTextFieldDelegate {
    func controlTextDidBeginEditing(_ obj: Notification) {
        if let editor = window?.fieldEditor(false, for: self) as? NSTextView {
            configureFieldEditor(editor)
        }
        todoDelegate?.todoTextFieldDidBeginEditing(self)
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        todoDelegate?.todoTextFieldDidEndEditing(self)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if textView.hasMarkedText() {
            return false
        }

        switch commandSelector {
        case Selector(("undo:")):
            if textView.undoManager?.canUndo == true {
                return false
            }
            todoDelegate?.todoTextFieldDidRequestUndo(self)
            return true
        case Selector(("redo:")):
            if textView.undoManager?.canRedo == true {
                return false
            }
            todoDelegate?.todoTextFieldDidRequestRedo(self)
            return true
        case #selector(NSResponder.insertNewline(_:)):
            todoDelegate?.todoTextFieldDidPressReturn(self)
            return true
        case #selector(NSResponder.deleteBackward(_:)):
            if textView.string.isEmpty {
                todoDelegate?.todoTextFieldDidPressBackspaceOnEmpty(self)
                return true
            }
            return false
        case #selector(NSText.paste(_:)):
            if let pasted = NSPasteboard.general.string(forType: .string), pasted.contains(where: \.isNewline) {
                let lines = pasted.components(separatedBy: .newlines)
                todoDelegate?.todoTextField(self, didPasteLines: lines)
                return true
            }
            return false
        default:
            return false
        }
    }
}
