import Foundation

public enum InputEventKind: String, Codable, Equatable, Sendable {
    case keyboard
    case mouse
}

public struct InputEvent: Codable, Equatable, Sendable {
    public var kind: InputEventKind
    public var timestamp: Date
    public var count: Int
    public var keyCode: Int?
    public var keyLabel: String?

    public init(
        kind: InputEventKind,
        timestamp: Date = Date(),
        count: Int = 1,
        keyCode: Int? = nil,
        keyLabel: String? = nil
    ) {
        self.kind = kind
        self.timestamp = timestamp
        self.count = max(0, count)
        self.keyCode = keyCode
        self.keyLabel = keyLabel
    }
}

public struct CropDefinition: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var displayName: String
    public var growRequirement: Int
    public var sellPrice: Int
    public var unlockPrice: Int
    public var stageCount: Int

    public init(
        id: String,
        displayName: String,
        growRequirement: Int,
        sellPrice: Int,
        unlockPrice: Int,
        stageCount: Int = 4
    ) {
        self.id = id
        self.displayName = displayName
        self.growRequirement = max(1, growRequirement)
        self.sellPrice = max(0, sellPrice)
        self.unlockPrice = max(0, unlockPrice)
        self.stageCount = max(2, stageCount)
    }
}

public extension CropDefinition {
    static let defaults: [CropDefinition] = [
        CropDefinition(id: "wheat", displayName: "小麦", growRequirement: 24, sellPrice: 8, unlockPrice: 0),
        CropDefinition(id: "tomato", displayName: "番茄", growRequirement: 45, sellPrice: 18, unlockPrice: 50),
        CropDefinition(id: "corn", displayName: "玉米", growRequirement: 75, sellPrice: 35, unlockPrice: 140),
        CropDefinition(id: "strawberry", displayName: "草莓", growRequirement: 120, sellPrice: 65, unlockPrice: 320)
    ]
}

public enum PetSpecies: String, Codable, Equatable, Sendable {
    case dog
    case cat

    public var displayName: String {
        switch self {
        case .dog:
            return "小狗"
        case .cat:
            return "小猫"
        }
    }
}

public struct PetDefinition: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var species: PetSpecies
    public var displayName: String
    public var adoptionPrice: Int
    public var assetPrefix: String

    public init(
        id: String,
        species: PetSpecies,
        displayName: String,
        adoptionPrice: Int,
        assetPrefix: String
    ) {
        self.id = id
        self.species = species
        self.displayName = displayName
        self.adoptionPrice = max(0, adoptionPrice)
        self.assetPrefix = assetPrefix
    }
}

public extension PetDefinition {
    static let defaults: [PetDefinition] = [
        PetDefinition(id: "dog", species: .dog, displayName: "小狗", adoptionPrice: 120, assetPrefix: "pet_dog"),
        PetDefinition(id: "cat", species: .cat, displayName: "小猫", adoptionPrice: 140, assetPrefix: "pet_cat")
    ]
}

public struct PetState: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var definitionID: String
    public var adoptedAt: Date

    public init(id: UUID = UUID(), definitionID: String, adoptedAt: Date = Date()) {
        self.id = id
        self.definitionID = definitionID
        self.adoptedAt = adoptedAt
    }
}

public extension PetState {
    static func defaultDog(adoptedAt: Date = Date(timeIntervalSince1970: 0)) -> PetState {
        PetState(definitionID: "dog", adoptedAt: adoptedAt)
    }
}

public struct PlotState: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var cropID: String
    public var progress: Int

    public init(id: UUID = UUID(), cropID: String, progress: Int = 0) {
        self.id = id
        self.cropID = cropID
        self.progress = max(0, progress)
    }
}

public struct KeyPlotState: Codable, Equatable, Identifiable, Sendable {
    public var keyID: String
    public var keyCode: Int
    public var keyLabel: String
    public var widthUnits: Double
    public var cropID: String
    public var progress: Int
    public var lastHitAt: Date?

    public var id: String {
        keyID
    }

    public init(
        keyID: String,
        keyCode: Int,
        keyLabel: String,
        widthUnits: Double = 1,
        cropID: String = "wheat",
        progress: Int = 0,
        lastHitAt: Date? = nil
    ) {
        self.keyID = keyID
        self.keyCode = keyCode
        self.keyLabel = keyLabel
        self.widthUnits = max(0.75, widthUnits)
        self.cropID = cropID
        self.progress = max(0, progress)
        self.lastHitAt = lastHitAt
    }

    public func isMature(using definitions: [String: CropDefinition]) -> Bool {
        guard let crop = definitions[cropID] else {
            return false
        }
        return progress >= crop.growRequirement
    }

    public func normalizedProgress(using definitions: [String: CropDefinition]) -> Double {
        guard let crop = definitions[cropID] else {
            return 0
        }
        return min(1, Double(progress) / Double(crop.growRequirement))
    }
}

public struct HarvestResult: Codable, Equatable, Sendable {
    public var keyID: String
    public var keyCode: Int
    public var cropID: String
    public var coins: Int

    public init(keyID: String, keyCode: Int, cropID: String, coins: Int) {
        self.keyID = keyID
        self.keyCode = keyCode
        self.cropID = cropID
        self.coins = max(0, coins)
    }
}

public struct KeyboardKeyDefinition: Codable, Equatable, Identifiable, Sendable {
    public var keyID: String
    public var keyCode: Int
    public var label: String
    public var widthUnits: Double

    public var id: String {
        keyID
    }

    public init(keyCode: Int, label: String, widthUnits: Double = 1) {
        self.keyID = "kc_\(keyCode)"
        self.keyCode = keyCode
        self.label = label
        self.widthUnits = widthUnits
    }
}

public enum KeyboardLayout {
    public static let rows: [[KeyboardKeyDefinition]] = [
        [
            KeyboardKeyDefinition(keyCode: 53, label: "Esc", widthUnits: 1.1),
            KeyboardKeyDefinition(keyCode: 50, label: "`"),
            KeyboardKeyDefinition(keyCode: 18, label: "1"),
            KeyboardKeyDefinition(keyCode: 19, label: "2"),
            KeyboardKeyDefinition(keyCode: 20, label: "3"),
            KeyboardKeyDefinition(keyCode: 21, label: "4"),
            KeyboardKeyDefinition(keyCode: 23, label: "5"),
            KeyboardKeyDefinition(keyCode: 22, label: "6"),
            KeyboardKeyDefinition(keyCode: 26, label: "7"),
            KeyboardKeyDefinition(keyCode: 28, label: "8"),
            KeyboardKeyDefinition(keyCode: 25, label: "9"),
            KeyboardKeyDefinition(keyCode: 29, label: "0"),
            KeyboardKeyDefinition(keyCode: 27, label: "-"),
            KeyboardKeyDefinition(keyCode: 24, label: "="),
            KeyboardKeyDefinition(keyCode: 51, label: "Del", widthUnits: 1.35)
        ],
        [
            KeyboardKeyDefinition(keyCode: 48, label: "Tab", widthUnits: 1.45),
            KeyboardKeyDefinition(keyCode: 12, label: "Q"),
            KeyboardKeyDefinition(keyCode: 13, label: "W"),
            KeyboardKeyDefinition(keyCode: 14, label: "E"),
            KeyboardKeyDefinition(keyCode: 15, label: "R"),
            KeyboardKeyDefinition(keyCode: 17, label: "T"),
            KeyboardKeyDefinition(keyCode: 16, label: "Y"),
            KeyboardKeyDefinition(keyCode: 32, label: "U"),
            KeyboardKeyDefinition(keyCode: 34, label: "I"),
            KeyboardKeyDefinition(keyCode: 31, label: "O"),
            KeyboardKeyDefinition(keyCode: 35, label: "P"),
            KeyboardKeyDefinition(keyCode: 33, label: "["),
            KeyboardKeyDefinition(keyCode: 30, label: "]"),
            KeyboardKeyDefinition(keyCode: 42, label: "\\", widthUnits: 1.25)
        ],
        [
            KeyboardKeyDefinition(keyCode: 57, label: "Caps", widthUnits: 1.75),
            KeyboardKeyDefinition(keyCode: 0, label: "A"),
            KeyboardKeyDefinition(keyCode: 1, label: "S"),
            KeyboardKeyDefinition(keyCode: 2, label: "D"),
            KeyboardKeyDefinition(keyCode: 3, label: "F"),
            KeyboardKeyDefinition(keyCode: 5, label: "G"),
            KeyboardKeyDefinition(keyCode: 4, label: "H"),
            KeyboardKeyDefinition(keyCode: 38, label: "J"),
            KeyboardKeyDefinition(keyCode: 40, label: "K"),
            KeyboardKeyDefinition(keyCode: 37, label: "L"),
            KeyboardKeyDefinition(keyCode: 41, label: ";"),
            KeyboardKeyDefinition(keyCode: 39, label: "'"),
            KeyboardKeyDefinition(keyCode: 36, label: "Return", widthUnits: 1.9)
        ],
        [
            KeyboardKeyDefinition(keyCode: 56, label: "Shift", widthUnits: 2.2),
            KeyboardKeyDefinition(keyCode: 6, label: "Z"),
            KeyboardKeyDefinition(keyCode: 7, label: "X"),
            KeyboardKeyDefinition(keyCode: 8, label: "C"),
            KeyboardKeyDefinition(keyCode: 9, label: "V"),
            KeyboardKeyDefinition(keyCode: 11, label: "B"),
            KeyboardKeyDefinition(keyCode: 45, label: "N"),
            KeyboardKeyDefinition(keyCode: 46, label: "M"),
            KeyboardKeyDefinition(keyCode: 43, label: ","),
            KeyboardKeyDefinition(keyCode: 47, label: "."),
            KeyboardKeyDefinition(keyCode: 44, label: "/"),
            KeyboardKeyDefinition(keyCode: 60, label: "Shift", widthUnits: 2.15)
        ],
        [
            KeyboardKeyDefinition(keyCode: 59, label: "Ctrl", widthUnits: 1.25),
            KeyboardKeyDefinition(keyCode: 58, label: "Opt", widthUnits: 1.2),
            KeyboardKeyDefinition(keyCode: 55, label: "Cmd", widthUnits: 1.35),
            KeyboardKeyDefinition(keyCode: 49, label: "Space", widthUnits: 6.7),
            KeyboardKeyDefinition(keyCode: 54, label: "Cmd", widthUnits: 1.35),
            KeyboardKeyDefinition(keyCode: 61, label: "Opt", widthUnits: 1.2),
            KeyboardKeyDefinition(keyCode: 62, label: "Ctrl", widthUnits: 1.25)
        ]
    ]

    public static let allKeys: [KeyboardKeyDefinition] = rows.flatMap { $0 }
    public static let keysByCode: [Int: KeyboardKeyDefinition] = Dictionary(uniqueKeysWithValues: allKeys.map { ($0.keyCode, $0) })

    public static func key(forKeyCode keyCode: Int) -> KeyboardKeyDefinition? {
        keysByCode[keyCode]
    }

    public static func label(forKeyCode keyCode: Int) -> String? {
        key(forKeyCode: keyCode)?.label
    }

    public static func defaultKeyPlots(cropID: String = "wheat") -> [KeyPlotState] {
        allKeys.map {
            KeyPlotState(
                keyID: $0.keyID,
                keyCode: $0.keyCode,
                keyLabel: $0.label,
                widthUnits: $0.widthUnits,
                cropID: cropID
            )
        }
    }
}

public struct FarmTask: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var isDone: Bool
    public var createdAt: Date

    public init(id: UUID = UUID(), title: String, isDone: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.createdAt = createdAt
    }
}

public struct DailyStats: Codable, Equatable, Sendable {
    public var dateKey: String
    public var keyboardCount: Int
    public var mouseCount: Int
    public var focusSessions: Int

    public init(dateKey: String, keyboardCount: Int = 0, mouseCount: Int = 0, focusSessions: Int = 0) {
        self.dateKey = dateKey
        self.keyboardCount = max(0, keyboardCount)
        self.mouseCount = max(0, mouseCount)
        self.focusSessions = max(0, focusSessions)
    }

    public var totalInput: Int {
        keyboardCount + mouseCount
    }
}

public struct PomodoroSettings: Codable, Equatable, Sendable {
    public var durationMinutes: Int

    public init(durationMinutes: Int = 25) {
        self.durationMinutes = min(180, max(1, durationMinutes))
    }
}

public struct GameState: Codable, Equatable, Sendable {
    public static let currentVersion = 3

    public var version: Int
    public var coins: Int
    public var unlockedCropIDs: Set<String>
    public var keyPlots: [KeyPlotState]
    public var selectedCropID: String
    public var adoptedPets: [PetState]
    public var tasks: [FarmTask]
    public var dailyStats: [String: DailyStats]
    public var pomodoroSettings: PomodoroSettings

    public init(
        version: Int = GameState.currentVersion,
        coins: Int = 0,
        unlockedCropIDs: Set<String> = ["wheat"],
        keyPlots: [KeyPlotState] = KeyboardLayout.defaultKeyPlots(),
        selectedCropID: String = "wheat",
        adoptedPets: [PetState] = [PetState.defaultDog()],
        tasks: [FarmTask] = [],
        dailyStats: [String: DailyStats] = [:],
        pomodoroSettings: PomodoroSettings = PomodoroSettings()
    ) {
        self.version = version
        self.coins = max(0, coins)
        self.unlockedCropIDs = unlockedCropIDs.isEmpty ? ["wheat"] : unlockedCropIDs
        self.keyPlots = GameState.normalizedKeyPlots(keyPlots)
        self.selectedCropID = self.unlockedCropIDs.contains(selectedCropID) ? selectedCropID : "wheat"
        self.adoptedPets = adoptedPets.isEmpty ? [PetState.defaultDog()] : adoptedPets
        self.tasks = tasks
        self.dailyStats = dailyStats
        self.pomodoroSettings = pomodoroSettings
    }

    public static func defaultState() -> GameState {
        GameState()
    }

    public static func normalizedKeyPlots(_ plots: [KeyPlotState]) -> [KeyPlotState] {
        // Persisted plots are keyed by hardware key code so layout changes can
        // rebuild labels and widths without losing per-key crop progress.
        let existing = Dictionary(uniqueKeysWithValues: plots.map { ($0.keyCode, $0) })
        return KeyboardLayout.allKeys.map { definition in
            if var plot = existing[definition.keyCode] {
                plot.keyID = definition.keyID
                plot.keyLabel = definition.label
                plot.widthUnits = definition.widthUnits
                return plot
            }
            return KeyPlotState(
                keyID: definition.keyID,
                keyCode: definition.keyCode,
                keyLabel: definition.label,
                widthUnits: definition.widthUnits
            )
        }
    }

    enum CodingKeys: String, CodingKey {
        case version
        case coins
        case unlockedCropIDs
        case keyPlots
        case selectedCropID
        case adoptedPets
        case plots
        case tasks
        case dailyStats
        case pomodoroSettings
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedVersion = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        let decodedUnlocked = try container.decodeIfPresent(Set<String>.self, forKey: .unlockedCropIDs) ?? ["wheat"]
        let decodedSelected = try container.decodeIfPresent(String.self, forKey: .selectedCropID) ?? "wheat"
        let decodedKeyPlots = try container.decodeIfPresent([KeyPlotState].self, forKey: .keyPlots)
        let decodedPets = try container.decodeIfPresent([PetState].self, forKey: .adoptedPets)

        version = GameState.currentVersion
        coins = max(0, try container.decodeIfPresent(Int.self, forKey: .coins) ?? 0)
        unlockedCropIDs = decodedUnlocked.isEmpty ? ["wheat"] : decodedUnlocked
        selectedCropID = unlockedCropIDs.contains(decodedSelected) ? decodedSelected : "wheat"
        adoptedPets = decodedPets?.isEmpty == false ? decodedPets! : [PetState.defaultDog()]
        tasks = try container.decodeIfPresent([FarmTask].self, forKey: .tasks) ?? []
        dailyStats = try container.decodeIfPresent([String: DailyStats].self, forKey: .dailyStats) ?? [:]
        pomodoroSettings = try container.decodeIfPresent(PomodoroSettings.self, forKey: .pomodoroSettings) ?? PomodoroSettings()

        if let decodedKeyPlots, !decodedKeyPlots.isEmpty, decodedVersion >= 2 {
            keyPlots = GameState.normalizedKeyPlots(decodedKeyPlots)
        } else {
            keyPlots = KeyboardLayout.defaultKeyPlots(cropID: selectedCropID)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(coins, forKey: .coins)
        try container.encode(unlockedCropIDs, forKey: .unlockedCropIDs)
        try container.encode(keyPlots, forKey: .keyPlots)
        try container.encode(selectedCropID, forKey: .selectedCropID)
        try container.encode(adoptedPets, forKey: .adoptedPets)
        try container.encode(tasks, forKey: .tasks)
        try container.encode(dailyStats, forKey: .dailyStats)
        try container.encode(pomodoroSettings, forKey: .pomodoroSettings)
    }
}

public enum DateKey {
    public static func key(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 1970
        let month = components.month ?? 1
        let day = components.day ?? 1
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
