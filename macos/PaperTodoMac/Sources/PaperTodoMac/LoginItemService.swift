import Foundation
import ServiceManagement

enum LoginItemServiceStatus: Equatable {
    case disabled
    case enabled
    case requiresApproval
    case unavailable

    var isEnabledInSettings: Bool {
        self == .enabled || self == .requiresApproval
    }

    var description: String {
        switch self {
        case .disabled:
            return L10n.text(.loginDisabled)
        case .enabled:
            return L10n.text(.loginEnabled)
        case .requiresApproval:
            return L10n.text(.loginRequiresApproval)
        case .unavailable:
            return L10n.text(.loginUnavailable)
        }
    }
}

enum LoginItemService {
    static var status: LoginItemServiceStatus {
        switch SMAppService.mainApp.status {
        case .notRegistered:
            return .disabled
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .unavailable
        @unknown default:
            return .unavailable
        }
    }

    static func setEnabled(_ enabled: Bool) throws -> LoginItemServiceStatus {
        if enabled {
            if status == .enabled || status == .requiresApproval {
                return status
            }
            try SMAppService.mainApp.register()
            return status
        }

        if status == .disabled {
            return .disabled
        }
        try SMAppService.mainApp.unregister()
        return status
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
