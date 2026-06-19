import Foundation

enum AppCommand: Equatable {
    case show
    case hide
    case toggle
    case newTodo
    case newNote
    case importData(URL)
    case exit

    static func fromLaunchArguments(_ arguments: [String]) -> AppCommand? {
        var iterator = Array(arguments.dropFirst()).makeIterator()
        while let raw = iterator.next() {
            if let command = AppCommand(rawArgument: raw, nextArgument: { iterator.next() }) {
                return command
            }
        }
        return nil
    }

    init?(rawArgument: String, nextArgument: () -> String? = { nil }) {
        let value = rawArgument
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .trimmingPrefix("--")
            .trimmingPrefix("-")

        switch value {
        case "", "launch":
            return nil
        case "show", "open", "restore":
            self = .show
        case "hide", "close":
            self = .hide
        case "toggle":
            self = .toggle
        case "new-todo", "todo", "newtodo":
            self = .newTodo
        case "new-note", "note", "newnote":
            self = .newNote
        case "import", "import-data", "import-json":
            guard let path = nextArgument()?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !path.isEmpty else {
                return nil
            }
            self = .importData(URL(fileURLWithPath: path).standardizedFileURL)
        case "exit", "quit":
            self = .exit
        default:
            return nil
        }
    }

    var isExit: Bool {
        if case .exit = self {
            return true
        }
        return false
    }
}

enum AppCommandPayload {
    static func encode(_ command: AppCommand?) -> String {
        do {
            let data = try JSONEncoder().encode(command ?? .show)
            return String(decoding: data, as: UTF8.self)
        } catch {
            return #"{"kind":"show"}"#
        }
    }

    static func decode(_ raw: String) -> AppCommand? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let command = try? JSONDecoder().decode(AppCommand.self, from: Data(trimmed.utf8)) {
            return command
        }
        return AppCommand(rawArgument: trimmed)
    }
}

extension AppCommand: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case path
    }

    private enum Kind: String, Codable {
        case show
        case hide
        case toggle
        case newTodo = "new-todo"
        case newNote = "new-note"
        case importData = "import-data"
        case exit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .show:
            self = .show
        case .hide:
            self = .hide
        case .toggle:
            self = .toggle
        case .newTodo:
            self = .newTodo
        case .newNote:
            self = .newNote
        case .importData:
            let path = try container.decode(String.self, forKey: .path)
            self = .importData(URL(fileURLWithPath: path).standardizedFileURL)
        case .exit:
            self = .exit
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .show:
            try container.encode(Kind.show, forKey: .kind)
        case .hide:
            try container.encode(Kind.hide, forKey: .kind)
        case .toggle:
            try container.encode(Kind.toggle, forKey: .kind)
        case .newTodo:
            try container.encode(Kind.newTodo, forKey: .kind)
        case .newNote:
            try container.encode(Kind.newNote, forKey: .kind)
        case .importData(let url):
            try container.encode(Kind.importData, forKey: .kind)
            try container.encode(url.path, forKey: .path)
        case .exit:
            try container.encode(Kind.exit, forKey: .kind)
        }
    }
}

private extension String {
    func trimmingPrefix(_ prefix: String) -> String {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : self
    }
}
