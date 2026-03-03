import Foundation

struct SleepEvent: Identifiable, Codable, Equatable {
	var id: UUID
	var start: Date
	var end: Date?

	init(id: UUID = UUID(), start: Date, end: Date? = nil) {
		self.id = id
		self.start = start
		self.end = end
	}
}

struct ZynEvent: Identifiable, Codable, Equatable {
	var id: UUID
	var timestamp: Date
	var strength: String?
	var note: String?

	init(id: UUID = UUID(), timestamp: Date, strength: String? = nil, note: String? = nil) {
		self.id = id
		self.timestamp = timestamp
		self.strength = strength
		self.note = note
	}
}

enum TrackerKind: String, Codable, CaseIterable, Identifiable {
	case coffee
	case tea
	case cigarette
	case vape
	case drink
	case supplement
	case water
	case sleepManual
	case fastFood
	case energyDrink
	case cannabis

	var id: String { rawValue }

	var displayName: String {
		switch self {
		case .coffee: return "Coffee"
		case .tea: return "Tea"
		case .cigarette: return "Cigarette"
		case .vape: return "Vape"
		case .drink: return "Drink"
		case .supplement: return "Supplement"
		case .water: return "Water"
		case .sleepManual: return "Sleep (manual)"
		case .fastFood: return "Meal"
		case .energyDrink: return "Energy drink"
		case .cannabis: return "Cannabis"
		}
	}

	var emoji: String {
		switch self {
		case .coffee: return "☕"
		case .tea: return "🫖"
		case .cigarette: return "🚬"
		case .vape: return "💨"
		case .drink: return "🍺"
		case .supplement: return "💊"
		case .water: return "💧"
		case .sleepManual: return "💤"
		case .fastFood: return "🧂"
		case .energyDrink: return "⚡"
		case .cannabis: return "🍃"
		}
	}

	var colorToken: String {
		switch self {
		case .coffee: return "amber"
		case .tea: return "tea"
		case .cigarette: return "smoke"
		case .vape: return "cyan"
		case .drink: return "orange"
		case .supplement: return "violet"
		case .water: return "teal"
		case .sleepManual: return "indigo"
		case .fastFood: return "red"
		case .energyDrink: return "yellow"
		case .cannabis: return "green"
		}
	}

	var isBuiltInDisabled: Bool {
		self == .sleepManual
	}

	var isRetiredFromUI: Bool {
		switch self {
		case .supplement, .energyDrink:
			return true
		default:
			return false
		}
	}
}

struct HabitEvent: Identifiable, Codable, Equatable {
	var id: UUID
	var timestamp: Date
	var tracker: TrackerKind
	var note: String?

	init(id: UUID = UUID(), timestamp: Date, tracker: TrackerKind, note: String? = nil) {
		self.id = id
		self.timestamp = timestamp
		self.tracker = tracker
		self.note = note
	}
}

enum LastAction: Codable, Equatable {
	case startedSleep(sleepId: UUID)
	case endedSleep(sleepId: UUID)
	case loggedZyn(zynId: UUID)
	case loggedHabit(eventId: UUID)

	private enum CodingKeys: String, CodingKey {
		case kind
		case sleepId
		case zynId
		case habitEventId
	}

	private enum Kind: String, Codable {
		case startedSleep
		case endedSleep
		case loggedZyn
		case loggedHabit
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let kind = try container.decode(Kind.self, forKey: .kind)
		switch kind {
		case .startedSleep:
			self = .startedSleep(sleepId: try container.decode(UUID.self, forKey: .sleepId))
		case .endedSleep:
			self = .endedSleep(sleepId: try container.decode(UUID.self, forKey: .sleepId))
		case .loggedZyn:
			self = .loggedZyn(zynId: try container.decode(UUID.self, forKey: .zynId))
		case .loggedHabit:
			self = .loggedHabit(eventId: try container.decode(UUID.self, forKey: .habitEventId))
		}
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		switch self {
		case .startedSleep(let sleepId):
			try container.encode(Kind.startedSleep, forKey: .kind)
			try container.encode(sleepId, forKey: .sleepId)
		case .endedSleep(let sleepId):
			try container.encode(Kind.endedSleep, forKey: .kind)
			try container.encode(sleepId, forKey: .sleepId)
		case .loggedZyn(let zynId):
			try container.encode(Kind.loggedZyn, forKey: .kind)
			try container.encode(zynId, forKey: .zynId)
		case .loggedHabit(let eventId):
			try container.encode(Kind.loggedHabit, forKey: .kind)
			try container.encode(eventId, forKey: .habitEventId)
		}
	}
}

struct ZynSleepState: Codable, Equatable {
	var sleepEvents: [SleepEvent]
	var zynEvents: [ZynEvent]
	var isZynTrackerActive: Bool
	var activeCustomTrackers: [TrackerKind]
	var habitEvents: [HabitEvent]
	var lastAction: LastAction?

	private enum CodingKeys: String, CodingKey {
		case sleepEvents
		case zynEvents
		case isZynTrackerActive
		case activeCustomTrackers
		case habitEvents
		case lastAction
	}

	init(
		sleepEvents: [SleepEvent],
		zynEvents: [ZynEvent],
		isZynTrackerActive: Bool = false,
		activeCustomTrackers: [TrackerKind] = [],
		habitEvents: [HabitEvent] = [],
		lastAction: LastAction?
	) {
		self.sleepEvents = sleepEvents
		self.zynEvents = zynEvents
		self.isZynTrackerActive = isZynTrackerActive
		self.activeCustomTrackers = activeCustomTrackers
		self.habitEvents = habitEvents
		self.lastAction = lastAction
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		sleepEvents = try container.decodeIfPresent([SleepEvent].self, forKey: .sleepEvents) ?? []
		zynEvents = try container.decodeIfPresent([ZynEvent].self, forKey: .zynEvents) ?? []
		isZynTrackerActive = try container.decodeIfPresent(Bool.self, forKey: .isZynTrackerActive) ?? false
		activeCustomTrackers = try container.decodeIfPresent([TrackerKind].self, forKey: .activeCustomTrackers) ?? []
		habitEvents = try container.decodeIfPresent([HabitEvent].self, forKey: .habitEvents) ?? []
		lastAction = try container.decodeIfPresent(LastAction.self, forKey: .lastAction)
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(sleepEvents, forKey: .sleepEvents)
		try container.encode(zynEvents, forKey: .zynEvents)
		try container.encode(isZynTrackerActive, forKey: .isZynTrackerActive)
		try container.encode(activeCustomTrackers, forKey: .activeCustomTrackers)
		try container.encode(habitEvents, forKey: .habitEvents)
		try container.encodeIfPresent(lastAction, forKey: .lastAction)
	}

	static let empty = ZynSleepState(sleepEvents: [], zynEvents: [], isZynTrackerActive: false, activeCustomTrackers: [], habitEvents: [], lastAction: nil)
}
