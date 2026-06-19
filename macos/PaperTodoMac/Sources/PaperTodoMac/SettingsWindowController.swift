import AppKit

@MainActor
protocol SettingsWindowControllerDelegate: AnyObject {
    func settingsWindowController(_ controller: SettingsWindowController, didUpdate state: AppState)
    func settingsWindowController(_ controller: SettingsWindowController, didRequestSetLaunchAtLogin enabled: Bool)
    func settingsWindowControllerDidRequestOpenLoginItems(_ controller: SettingsWindowController)
}

@MainActor
final class SettingsWindowController: NSWindowController {
    weak var delegate: SettingsWindowControllerDelegate?

    private var state: AppState
    private let themePopup = NSPopUpButton()
    private let colorPopup = NSPopUpButton()
    private let markdownPopup = NSPopUpButton()
    private let extensionField = NSTextField()
    private let titleLengthStepper = NSStepper()
    private let titleLengthLabel = NSTextField(labelWithString: "")
    private let capsuleModeButton = NSButton(checkboxWithTitle: L10n.text(.capsuleMode), target: nil, action: nil)
    private let deepCapsuleModeButton = NSButton(checkboxWithTitle: L10n.text(.deepCapsuleMode), target: nil, action: nil)
    private let useCapsuleCollapseAllButton = NSButton(checkboxWithTitle: L10n.text(.capsuleCollapseAll), target: nil, action: nil)
    private let showTopBarTodoButton = NSButton(checkboxWithTitle: L10n.text(.topBarTodo), target: nil, action: nil)
    private let showTopBarNoteButton = NSButton(checkboxWithTitle: L10n.text(.topBarNote), target: nil, action: nil)
    private let showTopBarExternalButton = NSButton(checkboxWithTitle: L10n.text(.topBarExternal), target: nil, action: nil)
    private let enableTodoLinksButton = NSButton(checkboxWithTitle: L10n.text(.enableTodoLinks), target: nil, action: nil)
    private let showLinkedNoteNameButton = NSButton(checkboxWithTitle: L10n.text(.showLinkedNoteName), target: nil, action: nil)
    private let hideLinkedNotesButton = NSButton(checkboxWithTitle: L10n.text(.hideLinkedNotes), target: nil, action: nil)
    private let enableAnimationsButton = NSButton(checkboxWithTitle: L10n.text(.enableAnimations), target: nil, action: nil)
    private let enableToolTipsButton = NSButton(checkboxWithTitle: L10n.text(.enableToolTips), target: nil, action: nil)
    private let showPapersOnAllSpacesButton = NSButton(checkboxWithTitle: L10n.text(.showOnAllSpaces), target: nil, action: nil)
    private let launchAtLoginButton = NSButton(checkboxWithTitle: L10n.text(.launchAtLogin), target: nil, action: nil)
    private let loginItemStatusLabel = NSTextField(labelWithString: "")
    private let openLoginItemsButton = NSButton(title: L10n.text(.openSystemSettings), target: nil, action: nil)

    init(state: AppState) {
        self.state = state
        let contentRect = NSRect(x: 0, y: 0, width: 500, height: 560)
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.text(.settingsTitle)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        build()
        syncControls()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateState(_ state: AppState) {
        self.state = state
        syncControls()
    }

    private func build() {
        guard let window else { return }

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 20, bottom: 18, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false

        configurePopups()

        stack.addArrangedSubview(sectionTitle(L10n.text(.appearance)))
        stack.addArrangedSubview(row(label: L10n.text(.theme), control: themePopup, help: L10n.text(.helpTheme)))
        stack.addArrangedSubview(row(label: L10n.text(.colorScheme), control: colorPopup, help: L10n.text(.helpColorScheme)))
        stack.addArrangedSubview(titleLengthRow())

        stack.addArrangedSubview(sectionTitle(L10n.text(.todoAndNotes)))
        stack.addArrangedSubview(row(label: "Markdown", control: markdownPopup, help: L10n.text(.helpMarkdownMode)))
        stack.addArrangedSubview(row(label: L10n.text(.externalExtension), control: extensionField, help: L10n.text(.helpExternalExtension)))
        stack.addArrangedSubview(checkboxRow(enableTodoLinksButton, help: L10n.text(.helpEnableTodoLinks)))
        stack.addArrangedSubview(checkboxRow(showLinkedNoteNameButton, help: L10n.text(.helpShowLinkedNoteName)))
        stack.addArrangedSubview(checkboxRow(hideLinkedNotesButton, help: L10n.text(.helpHideLinkedNotes)))

        stack.addArrangedSubview(sectionTitle(L10n.text(.topBarButtons)))
        stack.addArrangedSubview(checkboxRow(showTopBarTodoButton, help: L10n.text(.helpTopBarButtons)))
        stack.addArrangedSubview(checkboxRow(showTopBarNoteButton, help: L10n.text(.helpTopBarButtons)))
        stack.addArrangedSubview(checkboxRow(showTopBarExternalButton, help: L10n.text(.helpTopBarButtons)))

        stack.addArrangedSubview(sectionTitle(L10n.text(.capsule)))
        stack.addArrangedSubview(checkboxRow(capsuleModeButton, help: L10n.text(.helpCapsuleMode)))
        stack.addArrangedSubview(checkboxRow(deepCapsuleModeButton, help: L10n.text(.helpDeepCapsuleMode)))
        stack.addArrangedSubview(checkboxRow(useCapsuleCollapseAllButton, help: L10n.text(.helpCapsuleCollapseAll)))

        stack.addArrangedSubview(sectionTitle(L10n.text(.experience)))
        stack.addArrangedSubview(checkboxRow(enableAnimationsButton, help: L10n.text(.helpEnableAnimations)))
        stack.addArrangedSubview(checkboxRow(enableToolTipsButton, help: L10n.text(.helpEnableToolTips)))
        stack.addArrangedSubview(checkboxRow(showPapersOnAllSpacesButton, help: L10n.text(.helpShowOnAllSpaces)))

        stack.addArrangedSubview(sectionTitle(L10n.text(.startup)))
        stack.addArrangedSubview(loginItemRow())

        for control in allControls() {
            control.target = self
            control.action = #selector(controlChanged(_:))
        }
        launchAtLoginButton.target = self
        launchAtLoginButton.action = #selector(launchAtLoginChanged(_:))
        openLoginItemsButton.target = self
        openLoginItemsButton.action = #selector(openLoginItemsAction)
        extensionField.target = self
        extensionField.action = #selector(controlChanged(_:))
        extensionField.delegate = self

        scroll.documentView = stack
        window.contentView = scroll

        NSLayoutConstraint.activate([
            stack.widthAnchor.constraint(equalToConstant: 460),
            scroll.contentView.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            scroll.contentView.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
            scroll.contentView.topAnchor.constraint(equalTo: stack.topAnchor)
        ])
    }

    private func configurePopups() {
        themePopup.addItems(withTitles: [L10n.text(.themeSystem), L10n.text(.themeLight), L10n.text(.themeDark)])
        colorPopup.addItems(withTitles: [L10n.text(.colorWarm), L10n.text(.colorInk), L10n.text(.colorForest), L10n.text(.colorSunset)])
        markdownPopup.addItems(withTitles: [L10n.text(.markdownEnhanced), L10n.text(.markdownBasic), L10n.text(.markdownOff)])
        extensionField.placeholderString = ".md"
        titleLengthStepper.minValue = 8
        titleLengthStepper.maxValue = 40
        titleLengthStepper.increment = 1
        loginItemStatusLabel.textColor = .secondaryLabelColor
    }

    private func sectionTitle(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func row(label: String, control: NSView, help: String? = nil) -> NSStackView {
        let title = NSTextField(labelWithString: label)
        title.alignment = .right
        title.widthAnchor.constraint(equalToConstant: 108).isActive = true

        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.addArrangedSubview(title)
        row.addArrangedSubview(control)
        control.widthAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true
        if let help {
            row.addArrangedSubview(helpButton(help))
        }
        return row
    }

    private func checkboxRow(_ button: NSButton, help: String) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 6
        row.addArrangedSubview(button)
        row.addArrangedSubview(helpButton(help))
        return row
    }

    private func helpButton(_ text: String) -> NSButton {
        let image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: text)
        let button = NSButton(image: image ?? NSImage(), target: nil, action: nil)
        button.isBordered = false
        button.contentTintColor = .secondaryLabelColor
        button.imagePosition = .imageOnly
        button.toolTip = text
        button.setAccessibilityLabel(text)
        button.setButtonType(.momentaryChange)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 18).isActive = true
        button.heightAnchor.constraint(equalToConstant: 18).isActive = true
        return button
    }

    private func titleLengthRow() -> NSStackView {
        let group = NSStackView()
        group.orientation = .horizontal
        group.alignment = .centerY
        group.spacing = 8
        group.addArrangedSubview(titleLengthStepper)
        group.addArrangedSubview(titleLengthLabel)
        return row(label: L10n.text(.maxTitleLength), control: group, help: L10n.text(.helpMaxTitleLength))
    }

    private func loginItemRow() -> NSStackView {
        let group = NSStackView()
        group.orientation = .horizontal
        group.alignment = .centerY
        group.spacing = 8
        group.addArrangedSubview(launchAtLoginButton)
        group.addArrangedSubview(loginItemStatusLabel)
        group.addArrangedSubview(openLoginItemsButton)
        group.addArrangedSubview(helpButton(L10n.text(.helpLaunchAtLogin)))
        return group
    }

    func updateLoginItemStatus(_ status: LoginItemServiceStatus) {
        launchAtLoginButton.state = status.isEnabledInSettings ? .on : .off
        loginItemStatusLabel.stringValue = status.description
        openLoginItemsButton.isHidden = status != .requiresApproval
    }

    private func syncControls() {
        themePopup.selectItem(at: ["system", "light", "dark"].firstIndex(of: state.theme) ?? 0)
        colorPopup.selectItem(at: ["warm", "ink", "forest", "sunset"].firstIndex(of: state.colorScheme) ?? 0)
        markdownPopup.selectItem(at: ["enhanced", "basic", "off"].firstIndex(of: state.markdownRenderMode) ?? 0)
        extensionField.stringValue = state.externalMarkdownExtension
        titleLengthStepper.integerValue = state.maxTitleLength
        titleLengthLabel.stringValue = "\(state.maxTitleLength)"

        capsuleModeButton.state = state.useCapsuleMode ? .on : .off
        deepCapsuleModeButton.state = state.useDeepCapsuleMode ? .on : .off
        useCapsuleCollapseAllButton.state = state.useCapsuleCollapseAll ? .on : .off
        showTopBarTodoButton.state = state.showTopBarNewTodoButton ? .on : .off
        showTopBarNoteButton.state = state.showTopBarNewNoteButton ? .on : .off
        showTopBarExternalButton.state = state.showTopBarExternalOpenButton ? .on : .off
        enableTodoLinksButton.state = state.enableTodoNoteLinks ? .on : .off
        showLinkedNoteNameButton.state = state.showLinkedNoteName ? .on : .off
        hideLinkedNotesButton.state = state.hideLinkedNotesFromCapsules ? .on : .off
        enableAnimationsButton.state = state.enableAnimations ? .on : .off
        enableToolTipsButton.state = state.enableToolTips ? .on : .off
        showPapersOnAllSpacesButton.state = state.showPapersOnAllSpaces ? .on : .off
        updateLoginItemStatus(LoginItemService.status)

        deepCapsuleModeButton.isEnabled = state.useCapsuleMode
        useCapsuleCollapseAllButton.isEnabled = state.useCapsuleMode && state.useDeepCapsuleMode
    }

    @objc private func controlChanged(_ sender: Any?) {
        state.theme = ["system", "light", "dark"][max(0, themePopup.indexOfSelectedItem)]
        state.colorScheme = ["warm", "ink", "forest", "sunset"][max(0, colorPopup.indexOfSelectedItem)]
        state.markdownRenderMode = ["enhanced", "basic", "off"][max(0, markdownPopup.indexOfSelectedItem)]
        state.externalMarkdownExtension = normalizeExtension(extensionField.stringValue)
        state.maxTitleLength = titleLengthStepper.integerValue
        state.useCapsuleMode = capsuleModeButton.state == .on
        state.useDeepCapsuleMode = state.useCapsuleMode && deepCapsuleModeButton.state == .on
        state.useCapsuleCollapseAll = state.useCapsuleMode && state.useDeepCapsuleMode && useCapsuleCollapseAllButton.state == .on
        if !state.useCapsuleCollapseAll {
            state.capsuleCollapseAllActive = false
        }
        state.showTopBarNewTodoButton = showTopBarTodoButton.state == .on
        state.showTopBarNewNoteButton = showTopBarNoteButton.state == .on
        state.showTopBarExternalOpenButton = showTopBarExternalButton.state == .on
        state.enableTodoNoteLinks = enableTodoLinksButton.state == .on
        state.showLinkedNoteName = showLinkedNoteNameButton.state == .on
        state.hideLinkedNotesFromCapsules = hideLinkedNotesButton.state == .on
        state.showDeepCapsuleWhileExpanded = false
        state.enableAnimations = enableAnimationsButton.state == .on
        state.enableToolTips = enableToolTipsButton.state == .on
        state.showPapersOnAllSpaces = showPapersOnAllSpacesButton.state == .on
        syncControls()
        delegate?.settingsWindowController(self, didUpdate: state)
    }

    @objc private func launchAtLoginChanged(_ sender: NSButton) {
        delegate?.settingsWindowController(self, didRequestSetLaunchAtLogin: sender.state == .on)
    }

    @objc private func openLoginItemsAction() {
        delegate?.settingsWindowControllerDidRequestOpenLoginItems(self)
    }

    private func allControls() -> [NSControl] {
        [
            themePopup,
            colorPopup,
            markdownPopup,
            titleLengthStepper,
            capsuleModeButton,
            deepCapsuleModeButton,
            useCapsuleCollapseAllButton,
            showTopBarTodoButton,
            showTopBarNoteButton,
            showTopBarExternalButton,
            enableTodoLinksButton,
            showLinkedNoteNameButton,
            hideLinkedNotesButton,
            enableAnimationsButton,
            enableToolTipsButton,
            showPapersOnAllSpacesButton
        ]
    }

    private func normalizeExtension(_ value: String) -> String {
        var text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            return ".md"
        }
        if text.hasPrefix("*.") {
            text.removeFirst()
        }
        if !text.hasPrefix(".") {
            text = "." + text
        }
        if text.count < 2 || text.count > 32 || text.contains("/") || text.contains(":") || text.contains("..") {
            return ".md"
        }
        return text.lowercased()
    }
}

extension SettingsWindowController: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        controlChanged(obj.object)
    }
}
