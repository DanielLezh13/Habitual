import Foundation
import SwiftUI

enum AddSleepLogError: Error {
	case invalidRange
	case overlapsExisting
}

@MainActor
final class ZynSleepStore: ObservableObject {
	@Published private(set) var sleepEvents: [SleepEvent] = []
	@Published private(set) var zynEvents: [ZynEvent] = []
	@Published private(set) var isZynTrackerActive: Bool = false
	@Published private(set) var activeCustomTrackers: [TrackerKind] = []
	@Published private(set) var habitEvents: [HabitEvent] = []
	@Published private(set) var lastAction: LastAction? = nil

	private let calendar: Calendar
	private let nowProvider: () -> Date
	let maxAddableTrackerPages: Int = 5

	var activeAddableTrackerCount: Int {
		activeCustomTrackers.count + (isZynTrackerActive ? 1 : 0)
	}

	init(calendar: Calendar = .current, nowProvider: @escaping () -> Date = { Date() }) {
		self.calendar = calendar
		self.nowProvider = nowProvider
		load()
	}

	var isSleeping: Bool {
		currentSleepEvent != nil
	}

	var canUndo: Bool {
		lastAction != nil
	}

	var currentSleepEvent: SleepEvent? {
		sleepEvents
			.filter { $0.end == nil }
			.sorted(by: { $0.start > $1.start })
			.first
	}

	func toggleSleepWake() {
		let now = nowProvider()
		if let ongoing = currentSleepEvent, let index = sleepEvents.firstIndex(where: { $0.id == ongoing.id }) {
			let safeEnd = max(now, sleepEvents[index].start)
			sleepEvents[index].end = safeEnd
			lastAction = .endedSleep(sleepId: ongoing.id)
		} else {
			let event = SleepEvent(start: now, end: nil)
			sleepEvents.append(event)
			lastAction = .startedSleep(sleepId: event.id)
		}
		normalize()
		save()
	}

	func logZyn(strength: String, note: String? = nil) {
		addZynLog(at: nowProvider(), strength: strength, note: note)
	}

	func addZynLog(at timestamp: Date, strength: String? = nil, note: String? = nil) {
		let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
		let normalizedNote = (trimmed?.isEmpty == true) ? nil : trimmed
		let rawStrength = strength?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
		let normalizedStrength = rawStrength.isEmpty ? nil : rawStrength
		let event = ZynEvent(timestamp: timestamp, strength: normalizedStrength, note: normalizedNote)
		zynEvents.append(event)
		lastAction = .loggedZyn(zynId: event.id)
		normalize()
		save()
	}

	func canActivateCustomTracker(_ tracker: TrackerKind) -> Bool {
		guard !tracker.isBuiltInDisabled else { return false }
		guard !tracker.isRetiredFromUI else { return false }
		guard !activeCustomTrackers.contains(tracker) else { return false }
		return activeAddableTrackerCount < maxAddableTrackerPages
	}

	func canActivateZynTrackerPage() -> Bool {
		guard !isZynTrackerActive else { return false }
		return activeAddableTrackerCount < maxAddableTrackerPages
	}

	func activateZynTrackerPage() {
		guard canActivateZynTrackerPage() else { return }
		isZynTrackerActive = true
		normalize()
		save()
	}

	func deactivateZynTrackerPage() {
		guard isZynTrackerActive else { return }
		isZynTrackerActive = false
		save()
	}

	func activateCustomTracker(_ tracker: TrackerKind) {
		guard canActivateCustomTracker(tracker) else { return }
		activeCustomTrackers.append(tracker)
		normalize()
		save()
	}

	func deactivateCustomTracker(_ tracker: TrackerKind) {
		guard let index = activeCustomTrackers.firstIndex(of: tracker) else { return }
		activeCustomTrackers.remove(at: index)
		normalize()
		save()
	}

	func logHabit(_ tracker: TrackerKind, note: String? = nil) {
		addHabitLog(tracker, at: nowProvider(), note: note)
	}

	func addHabitLog(_ tracker: TrackerKind, at timestamp: Date, note: String? = nil) {
		guard !tracker.isBuiltInDisabled else { return }
		guard !tracker.isRetiredFromUI else { return }
		let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
		let normalizedNote = (trimmed?.isEmpty == true) ? nil : trimmed
		let event = HabitEvent(timestamp: timestamp, tracker: tracker, note: normalizedNote)
		habitEvents.append(event)
		lastAction = .loggedHabit(eventId: event.id)
		normalize()
		save()
	}

	func undoLastAction() {
		guard let action = lastAction else { return }
		switch action {
		case .startedSleep(let sleepId):
			sleepEvents.removeAll { $0.id == sleepId }
		case .endedSleep(let sleepId):
			if let index = sleepEvents.firstIndex(where: { $0.id == sleepId }) {
				sleepEvents[index].end = nil
			}
		case .loggedZyn(let zynId):
			zynEvents.removeAll { $0.id == zynId }
		case .loggedHabit(let eventId):
			habitEvents.removeAll { $0.id == eventId }
		}
		lastAction = nil
		normalize()
		save()
	}

	func updateZynNote(zynId: UUID, note: String?) {
		guard let index = zynEvents.firstIndex(where: { $0.id == zynId }) else { return }
		let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
		zynEvents[index].note = (trimmed?.isEmpty == true) ? nil : trimmed
		normalize()
		save()
	}

	func deleteZynEvent(zynId: UUID) {
		guard zynEvents.contains(where: { $0.id == zynId }) else { return }
		zynEvents.removeAll { $0.id == zynId }
		if case .loggedZyn(let lastZynId) = lastAction, lastZynId == zynId {
			lastAction = nil
		}
		normalize()
		save()
	}

	func deleteHabitEvent(_ eventId: UUID) {
		guard habitEvents.contains(where: { $0.id == eventId }) else { return }
		habitEvents.removeAll { $0.id == eventId }
		if case .loggedHabit(let lastHabitID) = lastAction, lastHabitID == eventId {
			lastAction = nil
		}
		normalize()
		save()
	}

	func deleteSleepEvent(sleepId: UUID) {
		guard sleepEvents.contains(where: { $0.id == sleepId }) else { return }
		sleepEvents.removeAll { $0.id == sleepId }
		if case .startedSleep(let lastSleepId) = lastAction, lastSleepId == sleepId {
			lastAction = nil
		}
		if case .endedSleep(let lastSleepId) = lastAction, lastSleepId == sleepId {
			lastAction = nil
		}
		normalize()
		save()
	}

	func addSleepLog(start: Date, end: Date) throws {
		guard end > start else {
			throw AddSleepLogError.invalidRange
		}

		let overlaps = sleepEvents.contains { event in
			let existingStart = event.start
			let existingEnd = event.end ?? nowProvider()
			return existingStart < end && start < existingEnd
		}
		guard !overlaps else {
			throw AddSleepLogError.overlapsExisting
		}

		let event = SleepEvent(start: start, end: end)
		sleepEvents.append(event)
		lastAction = .startedSleep(sleepId: event.id)
		normalize()
		save()
	}

	func isAsleep(at timestamp: Date) -> Bool {
		for event in sleepEvents {
			let start = event.start
			let end = event.end ?? nowProvider()
			if start <= timestamp && timestamp < end {
				return true
			}
		}
		return false
	}

	func sleepIntervalsOverlapping(dayStart: Date) -> [(start: Date, end: Date)] {
		guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
		var results: [(start: Date, end: Date)] = []
		for event in sleepEvents {
			let intervalStart = event.start
			let intervalEnd = event.end ?? nowProvider()
			if intervalEnd <= dayStart || intervalStart >= dayEnd { continue }
			let clippedStart = max(intervalStart, dayStart)
			let clippedEnd = min(intervalEnd, dayEnd)
			if clippedEnd > clippedStart {
				results.append((clippedStart, clippedEnd))
			}
		}
		return results.sorted(by: { $0.start < $1.start })
	}

	func zynEvents(inDayStarting dayStart: Date) -> [ZynEvent] {
		guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
		return zynEvents
			.filter { $0.timestamp >= dayStart && $0.timestamp < dayEnd }
			.sorted(by: { $0.timestamp < $1.timestamp })
	}

	func habitEvents(for tracker: TrackerKind) -> [HabitEvent] {
		habitEvents
			.filter { $0.tracker == tracker }
			.sorted(by: { $0.timestamp > $1.timestamp })
	}

	func habitEvents(inDayStarting dayStart: Date, tracker: TrackerKind) -> [HabitEvent] {
		guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
		return habitEvents
			.filter { $0.tracker == tracker && $0.timestamp >= dayStart && $0.timestamp < dayEnd }
			.sorted(by: { $0.timestamp < $1.timestamp })
	}

	func habitCount(inDayStarting dayStart: Date, tracker: TrackerKind) -> Int {
		habitEvents(inDayStarting: dayStart, tracker: tracker).count
	}

	private func normalize() {
		sleepEvents.sort(by: { $0.start < $1.start })
		zynEvents.sort(by: { $0.timestamp < $1.timestamp })
		habitEvents.sort(by: { $0.timestamp < $1.timestamp })

		var seen = Set<TrackerKind>()
		activeCustomTrackers = activeCustomTrackers.filter { tracker in
			guard !tracker.isBuiltInDisabled else { return false }
			guard !tracker.isRetiredFromUI else { return false }
			guard !seen.contains(tracker) else { return false }
			seen.insert(tracker)
			return true
		}
		let allowedCustomCount = max(0, maxAddableTrackerPages - (isZynTrackerActive ? 1 : 0))
		if activeCustomTrackers.count > allowedCustomCount {
			activeCustomTrackers = Array(activeCustomTrackers.prefix(allowedCustomCount))
		}
	}

	private func load() {
		do {
			let data = try Data(contentsOf: persistenceURL)
				let decoder = JSONDecoder()
				decoder.dateDecodingStrategy = .iso8601
				let state = try decoder.decode(ZynSleepState.self, from: data)
				self.sleepEvents = state.sleepEvents
				self.zynEvents = state.zynEvents
				self.isZynTrackerActive = state.isZynTrackerActive
				self.activeCustomTrackers = state.activeCustomTrackers
				self.habitEvents = state.habitEvents
				self.lastAction = state.lastAction
				normalize()
			} catch {
				self.sleepEvents = []
				self.zynEvents = []
				self.isZynTrackerActive = false
				self.activeCustomTrackers = []
				self.habitEvents = []
				self.lastAction = nil
			}
	}

	private func save() {
		do {
			let state = ZynSleepState(
				sleepEvents: sleepEvents,
				zynEvents: zynEvents,
				isZynTrackerActive: isZynTrackerActive,
				activeCustomTrackers: activeCustomTrackers,
				habitEvents: habitEvents,
				lastAction: lastAction
			)
			let encoder = JSONEncoder()
			encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
			encoder.dateEncodingStrategy = .iso8601
			let data = try encoder.encode(state)
			try FileManager.default.createDirectory(at: persistenceURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
			try data.write(to: persistenceURL, options: [.atomic])
		} catch {
			// Best-effort local persistence; ignore errors.
		}
	}

	private var persistenceURL: URL {
		let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
		return base.appendingPathComponent("ZynSleep", isDirectory: true).appendingPathComponent("state.json", isDirectory: false)
	}
}
