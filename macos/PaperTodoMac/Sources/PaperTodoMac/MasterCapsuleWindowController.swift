import AppKit
import QuartzCore

@MainActor
protocol MasterCapsuleWindowControllerDelegate: AnyObject {
    func masterCapsuleWindowControllerDidToggle(_ controller: MasterCapsuleWindowController)
}

@MainActor
final class MasterCapsuleWindowController: NSWindowController {
    weak var delegate: MasterCapsuleWindowControllerDelegate?

    private let capsuleView = NSView(frame: NSRect(origin: .zero, size: CapsuleLayout.compactSize))
    private let label = NSTextField(labelWithString: "")
    private var trackingArea: NSTrackingArea?
    private var palette: PaperPalette
    private var isHovering = false
    private var isActive = false
    private var lastExpandedTarget = false

    init(palette: PaperPalette, active: Bool, collectionBehavior: NSWindow.CollectionBehavior) {
        self.palette = palette
        isActive = active

        let panel = NSPanel(
            contentRect: CapsuleLayout.frame(for: 0, on: NSScreen.main, expanded: false),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = collectionBehavior
        panel.level = .floating

        super.init(window: panel)
        build()
        applyPalette()
        refreshTrackingArea()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(active: Bool, animated: Bool) {
        isActive = active
        applyPalette()
        window?.orderFrontRegardless()
        move(expanded: isHovering, animated: animated)
    }

    func hide() {
        isHovering = false
        window?.orderOut(nil)
    }

    func updatePalette(_ palette: PaperPalette) {
        self.palette = palette
        applyPalette()
    }

    func updateCollectionBehavior(_ behavior: NSWindow.CollectionBehavior) {
        window?.collectionBehavior = behavior
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        move(expanded: true, animated: true)
    }

    override func mouseExited(with event: NSEvent) {
        scheduleCollapseCheck()
    }

    private func build() {
        guard let window else { return }

        capsuleView.wantsLayer = true
        capsuleView.translatesAutoresizingMaskIntoConstraints = false
        capsuleView.toolTip = L10n.text(.collapseCapsules)

        label.alignment = .left
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false

        capsuleView.addSubview(label)
        window.contentView = capsuleView

        let click = NSClickGestureRecognizer(target: self, action: #selector(capsuleClicked))
        capsuleView.addGestureRecognizer(click)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: capsuleView.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: capsuleView.trailingAnchor, constant: -10),
            label.centerYAnchor.constraint(equalTo: capsuleView.centerYAnchor),
            capsuleView.widthAnchor.constraint(equalToConstant: CapsuleLayout.compactSize.width),
            capsuleView.heightAnchor.constraint(equalToConstant: CapsuleLayout.compactSize.height)
        ])
    }

    private func applyPalette() {
        capsuleView.layer?.cornerRadius = CapsuleLayout.compactSize.height / 2
        capsuleView.layer?.borderWidth = 1
        capsuleView.layer?.borderColor = (isActive ? palette.active : palette.border).cgColor
        capsuleView.layer?.backgroundColor = palette.paper.cgColor
        label.stringValue = isActive ? "▸ \(L10n.text(.expandCapsulesShort))" : "▾ \(L10n.text(.collapseCapsulesShort))"
        label.textColor = isActive ? palette.active : palette.text
        capsuleView.toolTip = isActive ? L10n.text(.expandCapsules) : L10n.text(.collapseCapsules)
    }

    private func move(expanded: Bool, animated: Bool) {
        guard let window else { return }
        let target = CapsuleLayout.frame(for: 0, on: window.screen ?? NSScreen.main, expanded: expanded)
        guard lastExpandedTarget != expanded || window.frame != target else {
            return
        }
        lastExpandedTarget = expanded
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

    private func shouldRemainExpanded() -> Bool {
        guard let window else { return false }
        let expandedFrame = CapsuleLayout.frame(for: 0, on: window.screen ?? NSScreen.main, expanded: true)
        return CapsuleLayout.hoverRetainFrame(for: expandedFrame).contains(NSEvent.mouseLocation)
    }

    private func scheduleCollapseCheck() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            guard let self else { return }
            guard !self.shouldRemainExpanded() else { return }
            self.isHovering = false
            self.move(expanded: false, animated: true)
        }
    }

    private func refreshTrackingArea() {
        if let trackingArea {
            capsuleView.removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: capsuleView.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        capsuleView.addTrackingArea(area)
        trackingArea = area
    }

    @objc private func capsuleClicked() {
        delegate?.masterCapsuleWindowControllerDidToggle(self)
    }
}
