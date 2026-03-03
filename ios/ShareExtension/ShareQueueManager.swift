import Foundation

struct ShareableMember: Codable, Equatable, Hashable, Sendable {
    let npub: String
    let name: String?
    let pictureUrl: String?
}

struct ShareableChatSummary: Codable, Equatable, Hashable, Sendable, Identifiable {
    let chatId: String
    let displayName: String
    let isGroup: Bool
    let subtitle: String?
    let lastMessagePreview: String
    let lastMessageAt: Int64?
    let members: [ShareableMember]

    var id: String { chatId }
}

enum ShareQueueContentType: String, Codable, Sendable {
    case text
    case url
    case image
}

struct ShareQueueItem: Codable, Equatable, Hashable, Sendable, Identifiable {
    let id: String
    let chatId: String
    let contentType: ShareQueueContentType
    let text: String
    let mediaFilename: String?
    let mediaMimeType: String?
    let mediaPath: String?
    let createdAt: Int64
}

enum ShareQueueManager {
    private static let chatListCacheFilename = "share_chat_list.json"
    private static let queueDirectoryName = "share_queue"
    private static let queueMediaDirectoryName = "media"
    private static let loginFlagKey = "pika.share.is_logged_in"
    private static let fallbackAppGroup = "group.org.pikachat.pika"

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder = JSONDecoder()

    static func writeChatListCache(_ chats: [ShareableChatSummary]) {
        guard let data = try? encoder.encode(chats) else { return }
        do {
            try ensureDirectories()
            try data.write(to: chatListCacheURL(), options: .atomic)
        } catch {
            NSLog("[ShareQueueManager] failed to write chat cache: \(error)")
        }
    }

    static func readChatListCache() -> [ShareableChatSummary] {
        let url = chatListCacheURL()
        guard let data = try? Data(contentsOf: url) else { return [] }
        guard let chats = try? decoder.decode([ShareableChatSummary].self, from: data) else {
            NSLog("[ShareQueueManager] failed to decode chat cache")
            return []
        }
        return chats
    }

    static func enqueue(_ item: ShareQueueItem) throws {
        try ensureDirectories()
        let data = try encoder.encode(item)
        try data.write(to: queueItemURL(for: item.id), options: .atomic)
    }

    static func dequeueAll() -> [ShareQueueItem] {
        let directory = queueDirectoryURL()
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let items = files
            .filter { $0.pathExtension.lowercased() == "json" }
            .compactMap { url -> ShareQueueItem? in
                guard let data = try? Data(contentsOf: url),
                      let item = try? decoder.decode(ShareQueueItem.self, from: data) else {
                    NSLog("[ShareQueueManager] failed to decode queued item: \(url.lastPathComponent)")
                    return nil
                }
                return item
            }

        return items.sorted {
            if $0.createdAt == $1.createdAt { return $0.id < $1.id }
            return $0.createdAt < $1.createdAt
        }
    }

    static func deleteQueueItem(_ item: ShareQueueItem) {
        let fm = FileManager.default
        try? fm.removeItem(at: queueItemURL(for: item.id))
        if let mediaPath = item.mediaPath {
            try? fm.removeItem(at: appSupportDirectoryURL().appendingPathComponent(mediaPath))
        }
    }

    static func saveMedia(
        _ data: Data,
        preferredFilename: String?,
        defaultExtension: String = "jpg"
    ) throws -> String {
        try ensureDirectories()
        let fileExtension = normalizedExtension(
            from: preferredFilename,
            fallback: defaultExtension
        )
        let filename = "\(UUID().uuidString).\(fileExtension)"
        let mediaURL = queueMediaDirectoryURL().appendingPathComponent(filename)
        try data.write(to: mediaURL, options: .atomic)
        return "\(queueDirectoryName)/\(queueMediaDirectoryName)/\(filename)"
    }

    static func mediaURL(for item: ShareQueueItem) -> URL? {
        guard let mediaPath = item.mediaPath else { return nil }
        return appSupportDirectoryURL().appendingPathComponent(mediaPath)
    }

    static func setLoggedIn(_ isLoggedIn: Bool) {
        sharedDefaults().set(isLoggedIn, forKey: loginFlagKey)
    }

    static func isLoggedIn() -> Bool {
        sharedDefaults().bool(forKey: loginFlagKey)
    }

    private static func ensureDirectories() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: appSupportDirectoryURL(), withIntermediateDirectories: true)
        try fm.createDirectory(at: queueDirectoryURL(), withIntermediateDirectories: true)
        try fm.createDirectory(at: queueMediaDirectoryURL(), withIntermediateDirectories: true)
    }

    private static func chatListCacheURL() -> URL {
        appSupportDirectoryURL().appendingPathComponent(chatListCacheFilename)
    }

    private static func queueItemURL(for id: String) -> URL {
        queueDirectoryURL().appendingPathComponent("\(id).json")
    }

    private static func queueDirectoryURL() -> URL {
        appSupportDirectoryURL().appendingPathComponent(queueDirectoryName, isDirectory: true)
    }

    private static func queueMediaDirectoryURL() -> URL {
        queueDirectoryURL().appendingPathComponent(queueMediaDirectoryName, isDirectory: true)
    }

    private static func appSupportDirectoryURL() -> URL {
        let fm = FileManager.default
        let appGroup = appGroupIdentifier()
        if let groupContainer = fm.containerURL(forSecurityApplicationGroupIdentifier: appGroup) {
            return groupContainer.appendingPathComponent("Library/Application Support", isDirectory: true)
        }
        return fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    }

    private static func appGroupIdentifier() -> String {
        let configured = (Bundle.main.infoDictionary?["PikaAppGroup"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return configured.isEmpty ? fallbackAppGroup : configured
    }

    private static func sharedDefaults() -> UserDefaults {
        if let defaults = UserDefaults(suiteName: appGroupIdentifier()) {
            return defaults
        }
        return .standard
    }

    private static func normalizedExtension(from filename: String?, fallback: String) -> String {
        let fallbackExt = sanitizedExtension(fallback) ?? "jpg"
        guard let filename else { return fallbackExt }
        let ext = URL(fileURLWithPath: filename).pathExtension
        return sanitizedExtension(ext) ?? fallbackExt
    }

    private static func sanitizedExtension(_ ext: String) -> String? {
        let lower = ext
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !lower.isEmpty, lower.count <= 12 else { return nil }
        let allowed = CharacterSet.alphanumerics
        guard lower.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
        return lower
    }
}
