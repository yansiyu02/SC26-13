import Foundation
import TypingFarmerCore

public struct WindowSettings: Codable, Equatable, Sendable {
    public var isAlwaysOnTop: Bool
    public var isVisible: Bool
    public var x: Double?
    public var y: Double?
    public var width: Double
    public var height: Double

    public init(
        isAlwaysOnTop: Bool = true,
        isVisible: Bool = true,
        x: Double? = nil,
        y: Double? = nil,
        width: Double = 1040,
        height: Double = 680
    ) {
        self.isAlwaysOnTop = isAlwaysOnTop
        self.isVisible = isVisible
        self.x = x
        self.y = y
        self.width = max(1040, width)
        self.height = max(680, height)
    }
}

public struct AppPersistedState: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var gameState: GameState
    public var windowSettings: WindowSettings

    public init(
        version: Int = AppPersistedState.currentVersion,
        gameState: GameState = .defaultState(),
        windowSettings: WindowSettings = WindowSettings()
    ) {
        self.version = version
        self.gameState = gameState
        self.windowSettings = windowSettings
    }

    public static func defaultState() -> AppPersistedState {
        AppPersistedState()
    }

    enum CodingKeys: String, CodingKey {
        case version
        case gameState
        case windowSettings
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let decodedGameState = try container.decodeIfPresent(GameState.self, forKey: .gameState) {
            version = try container.decodeIfPresent(Int.self, forKey: .version) ?? AppPersistedState.currentVersion
            gameState = decodedGameState
            windowSettings = try container.decodeIfPresent(WindowSettings.self, forKey: .windowSettings) ?? WindowSettings()
            migrate()
            return
        }

        // Older builds wrote GameState directly at the top level. Keep that
        // shape readable so existing local farms survive the wrapper migration.
        version = AppPersistedState.currentVersion
        gameState = try GameState(from: decoder)
        windowSettings = try container.decodeIfPresent(WindowSettings.self, forKey: .windowSettings) ?? WindowSettings()
        migrate()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(gameState, forKey: .gameState)
        try container.encode(windowSettings, forKey: .windowSettings)
    }

    private mutating func migrate() {
        if version < AppPersistedState.currentVersion {
            version = AppPersistedState.currentVersion
        }
    }
}

public final class PersistenceStore {
    public let fileURL: URL

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
            return
        }

        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        self.fileURL = baseURL
            .appendingPathComponent("TypingFarmerMac", isDirectory: true)
            .appendingPathComponent("state.json")
    }

    public func load() throws -> AppPersistedState {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .defaultState()
        }

        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AppPersistedState.self, from: data)
    }

    public func save(_ state: AppPersistedState) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)
        try data.write(to: fileURL, options: [.atomic])
    }
}
