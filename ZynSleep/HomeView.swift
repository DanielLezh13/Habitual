import SwiftUI
import UIKit

struct HomeView: View {
	@EnvironmentObject private var store: ZynSleepStore
	@State private var selectedPageID: String = HomePagerPage.sleep.id
	@State private var showingHistory: Bool = false
	@State private var showingSleepLogList: Bool = false
	@State private var showingZynLogList: Bool = false
	@State private var showingAddSleepLogSheet: Bool = false
	@State private var showingAddZynLogSheet: Bool = false
	@State private var showingManageTrackersSheet: Bool = false
	@State private var showingHabitLogTracker: TrackerKind?
	@State private var showingAddCustomLogTracker: TrackerKind?
	@State private var addablePageOrderIDs: [String] = []

	var body: some View {
		ZStack(alignment: .top) {
			LinearGradient(
				colors: [
					Color(red: 0.06, green: 0.09, blue: 0.16),
					Color(red: 0.10, green: 0.16, blue: 0.25),
					Color(red: 0.18, green: 0.24, blue: 0.34)
				],
				startPoint: .topLeading,
				endPoint: .bottomTrailing
			)
			.ignoresSafeArea()

			TabView(selection: $selectedPageID) {
				ForEach(pagerPages) { page in
					pagerPageView(for: page)
						.tag(page.id)
				}
			}
			.tabViewStyle(.page(indexDisplayMode: .never))

			pageIndicators
				.padding(.top, 14)
		}
		.safeAreaInset(edge: .bottom, spacing: 0) {
			BottomNavBar(
				pages: bottomNavPages,
				selectedPageID: selectedPageID,
				onSelectPage: { pageID in
					withAnimation(.easeOut(duration: 0.24)) {
						selectedPageID = pageID
					}
				}
			)
		}
		.sheet(isPresented: $showingHistory) {
			NavigationStack {
				InsightsFullHistorySheet(
					sleepEvents: store.sleepEvents,
					zynEvents: store.zynEvents,
					habitEvents: store.habitEvents,
					onDeleteSleep: { sleepId in
						store.deleteSleepEvent(sleepId: sleepId)
					},
					onDeleteZyn: { zynId in
						store.deleteZynEvent(zynId: zynId)
					},
					onDeleteHabit: { habitId in
						store.deleteHabitEvent(habitId)
					}
				)
			}
		}
		.sheet(isPresented: $showingAddSleepLogSheet) {
			AddSleepLogSheet(
				onSave: { start, end in
					try store.addSleepLog(start: start, end: end)
				}
			)
		}
		.sheet(isPresented: $showingSleepLogList) {
			SleepLogSheet(
				events: store.sleepEvents,
				onDelete: store.deleteSleepEvent
			)
		}
		.sheet(isPresented: $showingZynLogList) {
			ZynLogSheet(
				events: store.zynEvents,
				onDelete: store.deleteZynEvent
			)
		}
		.sheet(isPresented: $showingAddZynLogSheet) {
			AddTrackerLogSheet(
				title: "Add ZYN Log",
				onSave: { timestamp in
					store.addZynLog(at: timestamp)
				}
			)
		}
		.sheet(isPresented: $showingManageTrackersSheet) {
			ManageTrackersSheet(
				isZynTrackerActive: store.isZynTrackerActive,
				activeTrackers: store.activeCustomTrackers,
				orderedActivePageIDs: orderedAddablePages.map(\.id),
				maxActiveTrackers: store.maxAddableTrackerPages,
				canActivateZyn: store.canActivateZynTrackerPage,
				activateZyn: { activateZynTrackerPage() },
				deactivateZyn: { deactivateZynTrackerPage() },
				canActivate: { tracker in store.canActivateCustomTracker(tracker) },
				activate: { tracker in activateCustomTracker(tracker) },
				deactivate: { tracker in deactivateCustomTracker(tracker) }
			)
		}
		.sheet(item: $showingHabitLogTracker) { tracker in
			HabitLogSheet(
				tracker: tracker,
				events: store.habitEvents(for: tracker),
				onDelete: store.deleteHabitEvent
			)
		}
		.sheet(item: $showingAddCustomLogTracker) { tracker in
			AddTrackerLogSheet(
				title: "Add \(tracker.displayName) Log",
				onSave: { timestamp in
					store.addHabitLog(tracker, at: timestamp)
				}
			)
		}
		.onAppear {
			syncAddablePageOrder()
			ensureSelectedPageIsValid(preferred: .sleep)
		}
		.onChange(of: store.activeCustomTrackers) { _ in
			syncAddablePageOrder()
			ensureSelectedPageIsValid(preferred: .sleep)
		}
		.onChange(of: store.isZynTrackerActive) { _ in
			syncAddablePageOrder()
			ensureSelectedPageIsValid(preferred: .sleep)
		}
		.preferredColorScheme(.dark)
	}
}

private extension HomeView {
	var activeAddablePageIDs: [String] {
		var ids: [String] = store.activeCustomTrackers.map { HomePagerPage.custom($0).id }
		if store.isZynTrackerActive {
			ids.append(HomePagerPage.zyn.id)
		}
		return ids
	}

	var defaultOrderedAddablePageIDs: [String] {
		var ids: [String] = store.activeCustomTrackers.reversed().map { HomePagerPage.custom($0).id }
		if store.isZynTrackerActive {
			ids.append(HomePagerPage.zyn.id)
		}
		return ids
	}

	var orderedAddablePages: [HomePagerPage] {
		let activeSet = Set(activeAddablePageIDs)
		var orderedIDs = addablePageOrderIDs.filter { activeSet.contains($0) }
		for id in defaultOrderedAddablePageIDs where !orderedIDs.contains(id) {
			orderedIDs.append(id)
		}
		return orderedIDs.compactMap(homePagerPageFromAddableID)
	}

	var bottomNavPages: [HomePagerPage] {
		pagerPages.filter { page in
			if case .add = page { return false }
			return true
		}
	}

	var pagerPages: [HomePagerPage] {
		let addablePages = orderedAddablePages
		var pages: [HomePagerPage] = []
		if store.activeAddableTrackerCount < store.maxAddableTrackerPages {
			pages.append(.add)
		}
		pages.append(contentsOf: addablePages)
		pages.append(contentsOf: [.sleep, .insights])
		return pages
	}

	func homePagerPageFromAddableID(_ id: String) -> HomePagerPage? {
		if id == HomePagerPage.zyn.id {
			return .zyn
		}
		let prefix = "custom-"
		guard id.hasPrefix(prefix) else { return nil }
		let rawValue = String(id.dropFirst(prefix.count))
		guard let tracker = TrackerKind(rawValue: rawValue) else { return nil }
		return .custom(tracker)
	}

	func syncAddablePageOrder() {
		let activeSet = Set(activeAddablePageIDs)
		var normalized = addablePageOrderIDs.filter { activeSet.contains($0) }
		for id in defaultOrderedAddablePageIDs where !normalized.contains(id) {
			normalized.append(id)
		}
		addablePageOrderIDs = normalized
	}

	func promoteAddablePageToNewest(_ page: HomePagerPage) {
		let id = page.id
		guard id == HomePagerPage.zyn.id || id.hasPrefix("custom-") else { return }
		addablePageOrderIDs.removeAll { $0 == id }
		addablePageOrderIDs.insert(id, at: 0)
	}

	func activateZynTrackerPage() {
		guard store.canActivateZynTrackerPage() else { return }
		let wasOnAddPage = selectedPageID == HomePagerPage.add.id
		let fillingLastSlot = store.activeAddableTrackerCount == store.maxAddableTrackerPages - 1
		store.activateZynTrackerPage()
		promoteAddablePageToNewest(.zyn)
		if wasOnAddPage {
			withAnimation(.easeOut(duration: 0.24)) {
				selectedPageID = fillingLastSlot ? HomePagerPage.zyn.id : HomePagerPage.add.id
			}
		}
	}

	func activateCustomTracker(_ tracker: TrackerKind) {
		guard store.canActivateCustomTracker(tracker) else { return }
		let wasOnAddPage = selectedPageID == HomePagerPage.add.id
		let fillingLastSlot = store.activeAddableTrackerCount == store.maxAddableTrackerPages - 1
		store.activateCustomTracker(tracker)
		promoteAddablePageToNewest(.custom(tracker))
		if wasOnAddPage {
			withAnimation(.easeOut(duration: 0.24)) {
				selectedPageID = fillingLastSlot ? HomePagerPage.custom(tracker).id : HomePagerPage.add.id
			}
		}
	}

	func deactivateZynTrackerPage() {
		removePageAndShiftRight(.zyn)
	}

	func deactivateCustomTracker(_ tracker: TrackerKind) {
		removePageAndShiftRight(.custom(tracker))
	}

	func removePageAndShiftRight(_ page: HomePagerPage) {
		let removingSelectedPage = selectedPageID == page.id
		let wasAtAddableCap = store.activeAddableTrackerCount >= store.maxAddableTrackerPages

		if removingSelectedPage && wasAtAddableCap {
			switch page {
			case .zyn:
				store.deactivateZynTrackerPage()
			case .custom(let tracker):
				store.deactivateCustomTracker(tracker)
			default:
				break
			}
			addablePageOrderIDs.removeAll { $0 == page.id }
			syncAddablePageOrder()
			withAnimation(.easeOut(duration: 0.24)) {
				selectedPageID = HomePagerPage.add.id
			}
			return
		}

		let pagesBeforeRemoval = pagerPages
		let targetPageID: String? = {
			guard removingSelectedPage,
				  let currentIndex = pagesBeforeRemoval.firstIndex(where: { $0.id == page.id }) else { return nil }
			let rightIndex = currentIndex + 1
			if rightIndex < pagesBeforeRemoval.count {
				return pagesBeforeRemoval[rightIndex].id
			}
			if currentIndex > 0 {
				return pagesBeforeRemoval[currentIndex - 1].id
			}
			return nil
		}()

		if let targetPageID {
			withAnimation(.easeOut(duration: 0.24)) {
				selectedPageID = targetPageID
			}
		}

		switch page {
		case .zyn:
			store.deactivateZynTrackerPage()
		case .custom(let tracker):
			store.deactivateCustomTracker(tracker)
		default:
			break
		}

		addablePageOrderIDs.removeAll { $0 == page.id }
		syncAddablePageOrder()

		if targetPageID == nil {
			ensureSelectedPageIsValid(preferred: .sleep)
		}
	}

	@ViewBuilder
	func pagerPageView(for page: HomePagerPage) -> some View {
		switch page {
		case .add:
			AddTrackerPage(
				activeCount: store.activeAddableTrackerCount,
				maxCount: store.maxAddableTrackerPages,
				openManageTrackers: { showingManageTrackersSheet = true }
			)
		case .sleep:
			SleepPage(
				isSleeping: store.isSleeping,
				intervalLabel: sleepCardSnapshot.intervalText,
				canUndo: store.canUndo,
				toggleSleepWake: store.toggleSleepWake,
				undo: store.undoLastAction,
				showAddSleepLog: {
					showingAddSleepLogSheet = true
				},
				showRecentLogs: {
					showingZynLogList = false
					showingSleepLogList = true
				}
			)
		case .zyn:
			ZynTrackerPage(
				dailyCount: todayZynCount,
				statusSubtitle: lastZynSubtitle,
				canUndo: store.canUndo,
				quickLog: { store.addZynLog(at: Date()) },
				addLog: { showingAddZynLogSheet = true },
				undo: store.undoLastAction,
				showRecentLogs: {
					showingSleepLogList = false
					showingZynLogList = true
				},
				removeTracker: {
					removePageAndShiftRight(.zyn)
				}
			)
		case .custom(let tracker):
			CustomTrackerPage(
				tracker: tracker,
				dailyCount: todayHabitCount(for: tracker),
				statusSubtitle: lastHabitSubtitle(for: tracker),
				canUndo: store.canUndo,
				quickLog: { store.logHabit(tracker) },
				addLog: { showingAddCustomLogTracker = tracker },
				undo: store.undoLastAction,
				showRecentLogs: { showingHabitLogTracker = tracker },
				removeTracker: {
					removePageAndShiftRight(.custom(tracker))
				}
			)
		case .insights:
			InsightsPage(
				sleepEvents: store.sleepEvents,
				zynEvents: store.zynEvents,
				habitEvents: store.habitEvents,
				isZynTrackerActive: store.isZynTrackerActive,
				activeCustomTrackers: store.activeCustomTrackers,
				showHistory: { showingHistory = true },
				openManageTrackers: { showingManageTrackersSheet = true }
			)
		}
	}

	var sleepCardSnapshot: SleepCardSnapshot {
		let now = Date()
		let calendar = Calendar.current

		if let current = store.currentSleepEvent {
			return SleepCardSnapshot(
				intervalText: sleepIntervalLabel(for: current)
			)
		}

		let todayStart = sleepDayStart(for: now)
		let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? now
		let latestCompletedToday = store.sleepEvents
			.filter {
				guard let end = $0.end else { return false }
				return end >= todayStart && end < todayEnd
			}
			.max(by: { ($0.end ?? $0.start) < ($1.end ?? $1.start) })

		guard let latest = latestCompletedToday else {
			return SleepCardSnapshot(
				intervalText: "No logs yet today"
			)
		}

		return SleepCardSnapshot(
			intervalText: sleepIntervalLabel(for: latest)
		)
	}

	var todayZynCount: Int {
		let dayStart = Calendar.current.startOfDay(for: Date())
		return store.zynEvents(inDayStarting: dayStart).count
	}

	var lastZynSubtitle: String {
		guard let latest = store.zynEvents.max(by: { $0.timestamp < $1.timestamp }) else { return "No logs yet today" }
		return "Last logged \(latest.timestamp.formatted(date: .omitted, time: .shortened))"
	}

	func todayHabitCount(for tracker: TrackerKind) -> Int {
		let dayStart = Calendar.current.startOfDay(for: Date())
		return store.habitCount(inDayStarting: dayStart, tracker: tracker)
	}

	func lastHabitSubtitle(for tracker: TrackerKind) -> String {
		let events = store.habitEvents(for: tracker)
		guard let latest = events.first else { return "No logs yet today" }
		return "Last logged \(latest.timestamp.formatted(date: .omitted, time: .shortened))"
	}

	func ensureSelectedPageIsValid(preferred: HomePagerPage = .sleep) {
		let pages = pagerPages
		let validIDs = Set(pages.map(\.id))
		guard !validIDs.contains(selectedPageID) else { return }
		if selectedPageID == HomePagerPage.add.id, let firstPage = pages.first {
			selectedPageID = firstPage.id
			return
		}
		if validIDs.contains(preferred.id) {
			selectedPageID = preferred.id
		} else if let firstPage = pages.first {
			selectedPageID = firstPage.id
		}
	}

	func sleepIntervalLabel(for event: SleepEvent) -> String {
		let start = event.start.formatted(date: .omitted, time: .shortened)
		if let end = event.end {
			return "\(start) → \(end.formatted(date: .omitted, time: .shortened))"
		}
		return "\(start) →"
	}

	func sleepDayStart(for timestamp: Date, boundaryHour: Int = 15) -> Date {
		let calendar = Calendar.current
		let startOfCalendarDay = calendar.startOfDay(for: timestamp)
		let hour = calendar.component(.hour, from: timestamp)
		let baseDay = hour < boundaryHour
			? calendar.date(byAdding: .day, value: -1, to: startOfCalendarDay) ?? startOfCalendarDay
			: startOfCalendarDay
		return calendar.date(byAdding: .hour, value: boundaryHour, to: baseDay) ?? baseDay
	}

	var pageIndicators: some View {
		HStack(spacing: 7) {
			ForEach(pagerPages) { page in
				Group {
					if selectedPageID == page.id {
						Capsule()
							.fill(Color(red: 0.67, green: 0.86, blue: 1.0))
							.frame(width: 16, height: 7)
						} else {
							Circle()
								.fill(Color.white.opacity(0.55))
								.frame(width: 7, height: 7)
						}
					}
				.shadow(color: selectedPageID == page.id ? Color(red: 0.55, green: 0.79, blue: 1.0).opacity(0.58) : .clear, radius: 4)
				.onTapGesture {
					withAnimation(.easeOut(duration: 0.25)) {
						selectedPageID = page.id
					}
				}
			}
		}
		.padding(.horizontal, 11)
		.padding(.vertical, 7)
		.background(
			Capsule()
				.fill(Color(red: 0.17, green: 0.24, blue: 0.36).opacity(0.56))
				.overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1))
		)
	}
}

private enum HomePagerPage: Identifiable, Hashable {
	case add
	case sleep
	case zyn
	case custom(TrackerKind)
	case insights

	var id: String {
		switch self {
		case .add: return "add"
		case .sleep: return "sleep"
		case .zyn: return "zyn"
		case .custom(let tracker): return "custom-\(tracker.rawValue)"
		case .insights: return "insights"
		}
	}

}

private enum InsightsSort: String {
	case date = "Date"
	case sleep = "Sleep"
	case zyn = "Zyn"
}

private enum InsightsTrackerSelection: Identifiable, Hashable {
	case zyn
	case custom(TrackerKind)

	var id: String {
		switch self {
		case .zyn: return "zyn"
		case .custom(let tracker): return "custom-\(tracker.rawValue)"
		}
	}

	var title: String {
		switch self {
		case .zyn:
			return "ZYN"
		case .custom(let tracker):
			return tracker.displayName
		}
	}
}

private struct SleepCardSnapshot {
	let intervalText: String
}

private func sleepDurationLabel(start: Date, end: Date) -> String {
	let safeSeconds = max(0, Int(end.timeIntervalSince(start).rounded()))
	let hours = safeSeconds / 3600
	let minutes = (safeSeconds % 3600) / 60
	if hours > 0 {
		return "\(hours)h \(minutes)m"
	}
	if minutes > 0 {
		return "\(minutes)m"
	}
	return "<1m"
}

private struct SleepPage: View {
	let isSleeping: Bool
	let intervalLabel: String
	let canUndo: Bool
	let toggleSleepWake: () -> Void
	let undo: () -> Void
	let showAddSleepLog: () -> Void
	let showRecentLogs: () -> Void

	var body: some View {
		VStack(spacing: 20) {
			Text("Sleep Tracker")
				.frame(maxWidth: .infinity, alignment: .center)
				.font(.system(size: 34, weight: .semibold))
				.foregroundStyle(Color.white.opacity(0.96))
				.padding(.top, 12)
				.padding(.bottom, -6)
				.offset(y: 6)

				SleepCenteredSummaryCard(
					status: isSleeping ? "Sleeping" : "Awake",
					intervalText: intervalLabel
				)

			Color.clear
				.frame(height: 10)

				PressCommitButton(action: toggleSleepWake, hitDiameter: 182) {
					ZStack {
						Circle()
							.fill(
								RadialGradient(
									colors: [buttonTheme.glow.opacity(0.42), buttonTheme.glow.opacity(0.16), .clear],
									center: .center,
									startRadius: 30,
									endRadius: 160
								)
							)
							.frame(width: 270, height: 270)

						Circle()
							.fill(
								LinearGradient(
									colors: buttonTheme.outerGradient,
								startPoint: .topLeading,
								endPoint: .bottomTrailing
							)
						)
						.frame(width: 245, height: 245)
						.overlay {
							Circle().stroke(Color.white.opacity(0.22), lineWidth: 1.0)
						}

					Circle()
						.fill(
							LinearGradient(
								colors: buttonTheme.innerGradient,
								startPoint: .topLeading,
								endPoint: .bottomTrailing
							)
						)
						.frame(width: 182, height: 182)
						.overlay(
							Circle().stroke(buttonTheme.ringColor, lineWidth: 4)
						)
						.shadow(color: Color.black.opacity(0.35), radius: 18, y: 10)

						VStack(spacing: 6) {
							ZStack {
								Image(systemName: "moon.stars.fill")
									.opacity(isSleeping ? 0 : 1)
								Image(systemName: "sun.max.fill")
									.opacity(isSleeping ? 1 : 0)
							}
							.font(.system(size: 24, weight: .semibold))
							.foregroundStyle(Color.white.opacity(0.96))
							.animation(.easeInOut(duration: 0.18), value: isSleeping)

							ZStack {
								Text("Sleep")
									.opacity(isSleeping ? 0 : 1)
								Text("Wake")
									.opacity(isSleeping ? 1 : 0)
							}
							.font(.system(size: 33, weight: .semibold, design: .rounded))
							.foregroundStyle(.white)
							.animation(.easeInOut(duration: 0.18), value: isSleeping)
						}
					}
						.frame(width: 280, height: 280)
						.animation(.easeInOut(duration: 0.22), value: isSleeping)
				}

				HStack(spacing: 14) {
					Button(action: showAddSleepLog) {
						WeatherActionPill(label: "Add Sleep Log")
					}
					.buttonStyle(.plain)
				}

				Button(action: undo) {
					WeatherActionPill(label: "Undo last action")
				}
				.buttonStyle(.plain)
				.opacity(canUndo ? 1 : 0.45)
				.disabled(!canUndo)

				Button(action: showRecentLogs) {
					WeatherActionPill(label: "View recent logs")
				}
				.buttonStyle(.plain)

			Spacer(minLength: 24)
		}
		.padding(.horizontal, 24)
		.padding(.top, 60)
		.padding(.bottom, 24)
	}

	private var buttonTheme: SleepButtonTheme {
		if isSleeping {
			return SleepButtonTheme(
				glow: Color(red: 0.98, green: 0.70, blue: 0.24),
				outerGradient: [Color.orange.opacity(0.33), Color.orange.opacity(0.18)],
				innerGradient: [Color(red: 0.98, green: 0.66, blue: 0.24), Color(red: 0.94, green: 0.52, blue: 0.16)],
				ringColor: Color(red: 1.0, green: 0.82, blue: 0.50),
				iconName: "sun.max.fill"
			)
		}

		return SleepButtonTheme(
			glow: Color.blue,
			outerGradient: [Color.blue.opacity(0.34), Color.blue.opacity(0.20)],
			innerGradient: [Color(red: 0.21, green: 0.51, blue: 0.96), Color(red: 0.15, green: 0.39, blue: 0.92)],
			ringColor: Color(red: 0.24, green: 0.58, blue: 1.0),
			iconName: "moon.stars.fill"
		)
	}
}

private struct ZynTrackerPage: View {
	let dailyCount: Int
	let statusSubtitle: String
	let canUndo: Bool
	let quickLog: () -> Void
	let addLog: () -> Void
	let undo: () -> Void
	let showRecentLogs: () -> Void
	let removeTracker: () -> Void

	var body: some View {
		VStack(spacing: 20) {
			Text("ZYN Tracker")
				.frame(maxWidth: .infinity, alignment: .center)
				.font(.system(size: 34, weight: .semibold))
				.foregroundStyle(Color.white.opacity(0.96))
				.padding(.top, 12)
				.padding(.bottom, -6)
				.offset(y: 6)

			ZStack(alignment: .topLeading) {
				ZynCenteredSummaryCard(
					todayCount: dailyCount,
					subtitle: statusSubtitle
				)

				TrackerRemoveButton(action: removeTracker)
					.padding(.top, 10)
					.padding(.leading, 10)
			}

			Color.clear
				.frame(height: 10)

			PressCommitButton(action: quickLog, hitDiameter: 182) {
				ZynCanButton()
			}

			Button(action: addLog) {
				WeatherActionPill(label: "Add ZYN Log")
			}
			.buttonStyle(.plain)

			Button(action: undo) {
				WeatherActionPill(label: "Undo last action")
			}
			.buttonStyle(.plain)
			.opacity(canUndo ? 1 : 0.45)
			.disabled(!canUndo)

			Button(action: showRecentLogs) {
				WeatherActionPill(label: "View recent logs")
			}
			.buttonStyle(.plain)

			Spacer(minLength: 24)
		}
		.padding(.horizontal, 24)
		.padding(.top, 60)
		.padding(.bottom, 24)
	}
}

private struct ZynCanButton: View {
	var body: some View {
			ZStack {
				Circle()
					.fill(
						RadialGradient(
						colors: [Color.blue.opacity(0.40), Color.blue.opacity(0.18), .clear],
						center: .center,
						startRadius: 30,
						endRadius: 160
					)
				)
				.frame(width: 270, height: 270)

				Circle()
					.fill(
						LinearGradient(
							colors: [Color.blue.opacity(0.34), Color.blue.opacity(0.20)],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						)
					)
					.frame(width: 245, height: 245)
					.overlay {
						Circle().stroke(Color.white.opacity(0.22), lineWidth: 1.0)
					}

				Image("ZynCan")
					.resizable()
					.scaledToFit()
					.frame(width: 182, height: 182)
					.clipShape(Circle())
					.overlay(
						Circle()
							.stroke(Color(red: 0.21, green: 0.51, blue: 0.96), lineWidth: 4)
					)
					.shadow(color: Color.black.opacity(0.36), radius: 20, y: 10)
				}
				.frame(width: 280, height: 280)
	}
}

private func trackerAccentColor(_ tracker: TrackerKind) -> Color {
	switch tracker {
	case .coffee:
		return Color(red: 0.78, green: 0.55, blue: 0.32)
	case .tea:
		return Color(red: 0.58, green: 0.68, blue: 0.40)
	case .cigarette:
		return Color(red: 0.68, green: 0.70, blue: 0.76)
	case .vape:
		return Color(red: 0.84, green: 0.87, blue: 0.92)
	case .drink:
		return Color(red: 0.95, green: 0.63, blue: 0.35)
	case .supplement:
		return Color(red: 0.66, green: 0.56, blue: 0.96)
	case .water:
		return Color(red: 0.39, green: 0.80, blue: 0.95)
	case .sleepManual:
		return Color(red: 0.58, green: 0.64, blue: 0.94)
	case .fastFood:
		return Color(red: 0.92, green: 0.44, blue: 0.44)
	case .energyDrink:
		return Color(red: 0.95, green: 0.82, blue: 0.34)
	case .cannabis:
		return Color(red: 0.45, green: 0.78, blue: 0.45)
	}
}

private func trackerButtonAssetName(_ tracker: TrackerKind) -> String? {
	switch tracker {
	case .coffee:
		return "CoffeeButton"
	case .cannabis:
		return "CannabisButton"
	case .tea:
		return "TeaButton"
	case .drink:
		return "DrinkButton"
	case .cigarette:
		return "CigButton"
	case .vape:
		return "VapeButton"
	case .supplement:
		return "SupplementButton"
	case .water:
		return "WaterButton"
	case .fastFood:
		return "MealButton"
	default:
		return nil
	}
}

private func trackerButtonUIImage(_ tracker: TrackerKind) -> UIImage? {
	guard let assetName = trackerButtonAssetName(tracker) else { return nil }
	return UIImage(named: assetName)
}

private func trackerGlyphAssetName(_ tracker: TrackerKind) -> String {
	switch tracker {
	case .coffee:
		return "TrackerCoffeeIcon"
	case .tea:
		return "TrackerTeaIcon"
	case .cigarette:
		return "TrackerCigaretteIcon"
	case .vape:
		return "TrackerVapeIcon"
	case .drink:
		return "TrackerDrinkIcon"
	case .supplement:
		return "TrackerSupplementIcon"
	case .water:
		return "TrackerWaterIcon"
	case .sleepManual:
		return "TrackerSleepIcon"
	case .fastFood:
		return "TrackerFastFoodIcon"
	case .energyDrink:
		return "TrackerEnergyIcon"
	case .cannabis:
		return "TrackerCannabisIcon"
	}
}

private func trackerGlyphSystemName(_ tracker: TrackerKind) -> String {
	switch tracker {
	case .coffee:
		return "cup.and.saucer.fill"
	case .tea:
		return "mug.fill"
	case .cigarette:
		return "smoke.fill"
	case .vape:
		return "wind"
	case .drink:
		return "wineglass.fill"
	case .supplement:
		return "pill.fill"
	case .water:
		return "drop.fill"
	case .sleepManual:
		return "bed.double.fill"
	case .fastFood:
		return "fork.knife"
	case .energyDrink:
		return "bolt.fill"
	case .cannabis:
		return "leaf.fill"
	}
}

private struct TrackerGlyphIcon: View {
	let tracker: TrackerKind
	let size: CGFloat
	let tint: Color

	private var uiImage: UIImage? {
		UIImage(named: trackerGlyphAssetName(tracker))
	}

	private var sizeMultiplier: CGFloat {
		switch tracker {
		case .cigarette:
			return 1.45
		case .cannabis:
			return 1.10
		default:
			return 1.0
		}
	}

	var body: some View {
		let effectiveSize = size * sizeMultiplier
		Group {
			if let uiImage {
				Image(uiImage: uiImage)
					.renderingMode(.template)
					.resizable()
					.scaledToFit()
					.frame(width: effectiveSize, height: effectiveSize)
					.foregroundStyle(tint)
			} else {
				Image(systemName: trackerGlyphSystemName(tracker))
					.font(.system(size: effectiveSize, weight: .semibold))
					.foregroundStyle(tint)
			}
		}
		.frame(width: size, height: size)
	}
}

private struct TrackerRemoveButton: View {
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			Image(systemName: "minus")
				.font(.system(size: 13, weight: .bold))
				.foregroundStyle(Color.white.opacity(0.90))
				.frame(width: 26, height: 26)
				.background(
					Circle()
						.fill(Color(red: 0.19, green: 0.28, blue: 0.41).opacity(0.92))
						.overlay(
							Circle()
								.stroke(Color(red: 0.66, green: 0.82, blue: 0.98).opacity(0.34), lineWidth: 1)
						)
				)
				.shadow(color: Color.black.opacity(0.22), radius: 4, y: 2)
		}
		.buttonStyle(.plain)
	}
}

private struct AddTrackerPage: View {
	let activeCount: Int
	let maxCount: Int
	let openManageTrackers: () -> Void

	var body: some View {
		VStack(spacing: 18) {
			Text("Add Tracker")
				.frame(maxWidth: .infinity, alignment: .center)
				.font(.system(size: 34, weight: .semibold))
				.foregroundStyle(Color.white.opacity(0.96))
				.padding(.top, 12)
				.padding(.bottom, -6)
				.offset(y: 6)

			Spacer(minLength: 16)

			Button(action: openManageTrackers) {
				ZStack {
					Circle()
						.fill(
							LinearGradient(
								colors: [Color(red: 0.24, green: 0.47, blue: 0.79), Color(red: 0.17, green: 0.35, blue: 0.62)],
								startPoint: .topLeading,
								endPoint: .bottomTrailing
							)
						)
						.frame(width: 174, height: 174)
						.overlay(
							Circle()
								.stroke(Color.white.opacity(0.28), lineWidth: 1.4)
						)
						.shadow(color: Color.black.opacity(0.30), radius: 14, y: 8)

					Image(systemName: "plus")
						.font(.system(size: 52, weight: .semibold))
						.foregroundStyle(Color.white.opacity(0.95))
				}
			}
			.buttonStyle(.plain)
			.disabled(activeCount >= maxCount)
			.opacity(activeCount >= maxCount ? 0.45 : 1)

			Text("\(activeCount) / \(maxCount) active trackers")
				.font(.system(size: 14, weight: .semibold))
				.foregroundStyle(Color.white.opacity(0.72))

			if activeCount >= maxCount {
				Text("Remove one tracker to add another.")
					.font(.system(size: 13, weight: .medium))
					.foregroundStyle(Color.white.opacity(0.62))
			}

			Spacer(minLength: 24)
		}
		.padding(.horizontal, 24)
		.padding(.top, 60)
		.padding(.bottom, 24)
	}
}

private struct CustomTrackerPage: View {
	let tracker: TrackerKind
	let dailyCount: Int
	let statusSubtitle: String
	let canUndo: Bool
	let quickLog: () -> Void
	let addLog: () -> Void
	let undo: () -> Void
	let showRecentLogs: () -> Void
	let removeTracker: () -> Void

	var body: some View {
		VStack(spacing: 20) {
			Text("\(tracker.displayName) Tracker")
				.frame(maxWidth: .infinity, alignment: .center)
				.font(.system(size: 34, weight: .semibold))
				.foregroundStyle(Color.white.opacity(0.96))
				.padding(.top, 12)
				.padding(.bottom, -6)
				.offset(y: 6)

			ZStack(alignment: .topLeading) {
				CustomTrackerSummaryCard(
					tracker: tracker,
					todayCount: dailyCount,
					subtitle: statusSubtitle
				)

				TrackerRemoveButton(action: removeTracker)
					.padding(.top, 10)
					.padding(.leading, 10)
					.accessibilityLabel("Remove \(tracker.displayName)")
			}

			Color.clear
				.frame(height: 10)

			PressCommitButton(action: quickLog, hitDiameter: 182) {
				CustomTrackerButton(tracker: tracker)
			}

			Button(action: addLog) {
				WeatherActionPill(label: "Add \(tracker.displayName) Log")
			}
			.buttonStyle(.plain)

			Button(action: undo) {
				WeatherActionPill(label: "Undo last action")
			}
			.buttonStyle(.plain)
			.opacity(canUndo ? 1 : 0.45)
			.disabled(!canUndo)

			Button(action: showRecentLogs) {
				WeatherActionPill(label: "View recent logs")
			}
			.buttonStyle(.plain)

			Spacer(minLength: 24)
		}
		.padding(.horizontal, 24)
		.padding(.top, 60)
		.padding(.bottom, 24)
	}
}

private struct CustomTrackerSummaryCard: View {
	let tracker: TrackerKind
	let todayCount: Int
	let subtitle: String

	var body: some View {
		VStack(spacing: 8) {
			Text("Today")
				.font(.system(size: 14, weight: .semibold))
				.foregroundStyle(Color.white.opacity(0.62))

			Text(trackerCountSummaryLabel(todayCount, tracker: tracker))
				.font(.system(size: 46, weight: .bold))
				.foregroundStyle(.white)
				.monospacedDigit()
				.multilineTextAlignment(.center)

			Text(subtitle)
				.font(.system(size: 18, weight: .medium))
				.foregroundStyle(Color.white.opacity(0.72))
				.monospacedDigit()
				.multilineTextAlignment(.center)
		}
		.frame(maxWidth: .infinity, alignment: .center)
		.padding(.horizontal, 20)
		.padding(.vertical, 18)
		.background(WeatherSummaryCardShell())
	}
}

private struct CustomTrackerButton: View {
	let tracker: TrackerKind

	var body: some View {
		let accent = trackerAccentColor(tracker)
		let imageScale: CGFloat = {
			switch tracker {
			case .vape:
				return 1.18
			default:
				return 1.0
			}
		}()
		let imageOffset: CGSize = {
			switch tracker {
			case .water:
				// Water icon has extra visual weight to the bottom-right; nudge into optical center.
				return CGSize(width: -7, height: -6)
			default:
				return .zero
			}
		}()
		ZStack {
			Circle()
				.fill(
					RadialGradient(
						colors: [accent.opacity(0.40), accent.opacity(0.18), .clear],
						center: .center,
						startRadius: 30,
						endRadius: 160
					)
				)
				.frame(width: 270, height: 270)

			Circle()
				.fill(
					LinearGradient(
						colors: [accent.opacity(0.34), accent.opacity(0.20)],
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					)
				)
				.frame(width: 245, height: 245)
				.overlay {
					Circle().stroke(Color.white.opacity(0.22), lineWidth: 1.0)
				}

			Circle()
				.fill(
					LinearGradient(
						colors: [accent.opacity(0.92), accent.opacity(0.78)],
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					)
				)
				.frame(width: 182, height: 182)
				.overlay(
					Circle()
						.stroke(accent.opacity(0.95), lineWidth: 4)
				)
				.shadow(color: Color.black.opacity(0.36), radius: 20, y: 10)

			ZStack {
				if let uiImage = trackerButtonUIImage(tracker) {
					Image(uiImage: uiImage)
						.resizable()
						.scaledToFit()
						.frame(width: 146 * imageScale, height: 146 * imageScale)
						.offset(imageOffset)
				} else {
					Text(tracker.emoji)
						.font(.system(size: 72))
				}
			}
		}
		.frame(width: 280, height: 280)
	}
}

private struct PressCommitButton<Label: View>: View {
	let action: () -> Void
	let hitDiameter: CGFloat
	private let minimumPressedDuration: TimeInterval = 0.12
	private let pressInDuration: TimeInterval = 0.10
	private let releaseDuration: TimeInterval = 0.18
	private let pressedScale: CGFloat = 0.95
	private let pressedYOffset: CGFloat = 4
	private let cancelDragDistance: CGFloat = 28
	@ViewBuilder let label: () -> Label

	@State private var isPressed: Bool = false
	@State private var touchStartTime: Date?
	@State private var touchActive: Bool = false
	@State private var cancelledByDrag: Bool = false
	@State private var releaseWorkItem: DispatchWorkItem?

	init(action: @escaping () -> Void, hitDiameter: CGFloat = 210, @ViewBuilder label: @escaping () -> Label) {
		self.action = action
		self.hitDiameter = hitDiameter
		self.label = label
	}

	var body: some View {
		ZStack {
			label()
				.allowsHitTesting(false)

			Circle()
				.fill(Color.white.opacity(0.001))
				.frame(width: hitDiameter, height: hitDiameter)
				.contentShape(Circle())
		}
			.scaleEffect(isPressed ? pressedScale : 1.0)
			.offset(y: isPressed ? pressedYOffset : 0)
			.simultaneousGesture(
				DragGesture(minimumDistance: 0)
					.onChanged { value in
						if !touchActive {
							touchActive = true
							cancelledByDrag = false
							touchStartTime = Date()
							cancelPendingWork()
							withAnimation(.easeOut(duration: pressInDuration)) {
								isPressed = true
							}
						}

						let travel = hypot(value.translation.width, value.translation.height)
						if !cancelledByDrag && travel > cancelDragDistance {
							cancelledByDrag = true
							withAnimation(.easeOut(duration: 0.08)) {
								isPressed = false
							}
						}
					}
					.onEnded { value in
						guard touchActive else { return }
						touchActive = false
						let travel = hypot(value.translation.width, value.translation.height)
						if cancelledByDrag || travel > cancelDragDistance {
							cancelledByDrag = false
							touchStartTime = nil
							withAnimation(.easeOut(duration: 0.08)) {
								isPressed = false
							}
							return
						}

						let start = touchStartTime ?? Date()
						let elapsed = Date().timeIntervalSince(start)
						let holdFor = max(0, minimumPressedDuration - elapsed)
						touchStartTime = nil
						cancelledByDrag = false

							let releaseItem = DispatchWorkItem {
								releaseWorkItem = nil
								action()
								withAnimation(.spring(response: releaseDuration, dampingFraction: 0.78)) {
									isPressed = false
								}
							}

						releaseWorkItem = releaseItem
						DispatchQueue.main.asyncAfter(deadline: .now() + holdFor, execute: releaseItem)
					}
			)
			.onDisappear {
				cancelPendingWork()
			}
	}

	private func cancelPendingWork() {
		releaseWorkItem?.cancel()
		releaseWorkItem = nil
	}
}

private struct SleepLogSheet: View {
	let events: [SleepEvent]
	let onDelete: (UUID) -> Void

	private let sleepDayBoundaryHour: Int = 15
	@State private var revealedDeleteID: UUID?
	@State private var displayedEvents: [SleepEvent] = []
	@State private var removingEventIDs: Set<UUID> = []

	var body: some View {
		NavigationStack {
			List {
				if logSections.isEmpty {
					Section {
						Text("No sleep logs yet")
							.foregroundStyle(.secondary)
					}
				} else {
					ForEach(logSections) { section in
						Section(section.title.uppercased()) {
							ForEach(section.events) { event in
								AttachedSwipeSleepRow(
									event: event,
									intervalText: intervalLabel(for: event),
									isRemoving: removingEventIDs.contains(event.id),
									revealedDeleteID: $revealedDeleteID,
									onDelete: { deleteWithCollapse(event.id) }
								)
							}
						}
					}
				}
			}
			.scrollContentBackground(.hidden)
			.background(
				LinearGradient(
					colors: [
						Color(red: 0.09, green: 0.16, blue: 0.26).opacity(0.94),
						Color(red: 0.08, green: 0.14, blue: 0.24).opacity(0.96)
					],
					startPoint: .topLeading,
					endPoint: .bottomTrailing
				)
				.ignoresSafeArea()
			)
			.navigationTitle("Recent Sleep Logs")
			.navigationBarTitleDisplayMode(.inline)
		}
		.preferredColorScheme(.dark)
		.presentationDetents([.fraction(0.58)])
		.presentationDragIndicator(.visible)
		.onAppear {
			displayedEvents = events
		}
		.onChange(of: events) { newEvents in
			displayedEvents = newEvents.filter { !removingEventIDs.contains($0.id) }
		}
	}

	private var logSections: [SleepLogSection] {
		let grouped = Dictionary(grouping: displayedEvents) { event in
			sleepDayStart(for: event.start)
		}

		return grouped.keys
			.sorted(by: >)
			.map { dayStart in
				SleepLogSection(
					dayStart: dayStart,
					title: sectionTitle(for: dayStart),
					events: (grouped[dayStart] ?? []).sorted(by: { $0.start > $1.start })
				)
			}
	}

	private func sectionTitle(for dayStart: Date) -> String {
		let calendar = Calendar.current
		let currentSleepDay = sleepDayStart(for: Date())
		if calendar.isDate(dayStart, inSameDayAs: currentSleepDay) { return "Today" }
		if let yesterdaySleepDay = calendar.date(byAdding: .day, value: -1, to: currentSleepDay),
		   calendar.isDate(dayStart, inSameDayAs: yesterdaySleepDay) {
			return "Yesterday"
		}
		return dayStart.formatted(.dateTime.month().day().year())
	}

	private func sleepDayStart(for timestamp: Date) -> Date {
		let calendar = Calendar.current
		let startOfCalendarDay = calendar.startOfDay(for: timestamp)
		let hour = calendar.component(.hour, from: timestamp)
		let baseDay = hour < sleepDayBoundaryHour
			? calendar.date(byAdding: .day, value: -1, to: startOfCalendarDay) ?? startOfCalendarDay
			: startOfCalendarDay
		return calendar.date(byAdding: .hour, value: sleepDayBoundaryHour, to: baseDay) ?? baseDay
	}

	private func intervalLabel(for event: SleepEvent) -> String {
		let start = event.start.formatted(date: .omitted, time: .shortened)
		if let end = event.end {
			return "\(start) → \(end.formatted(date: .omitted, time: .shortened))"
		}
		return "\(start) →"
	}

		private func deleteWithCollapse(_ id: UUID) {
			guard !removingEventIDs.contains(id) else { return }
			withAnimation(.easeInOut(duration: 0.18)) {
				_ = removingEventIDs.insert(id)
			}
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
			displayedEvents.removeAll { $0.id == id }
			removingEventIDs.remove(id)
			if revealedDeleteID == id {
				revealedDeleteID = nil
			}
			onDelete(id)
		}
	}
}

private struct SleepLogSheetRow: View {
	let event: SleepEvent
	let intervalText: String

	var body: some View {
		HStack(spacing: 12) {
			Text(intervalText)
				.font(.system(size: 17, weight: .semibold))
				.foregroundStyle(.white)
				.monospacedDigit()
				.lineLimit(1)
			Spacer()
			if let end = event.end {
				Text(sleepDurationLabel(start: event.start, end: end))
					.font(.system(size: 15, weight: .semibold))
					.foregroundStyle(Color.white.opacity(0.80))
					.monospacedDigit()
			} else {
				TimelineView(.periodic(from: .now, by: 60)) { timeline in
					VStack(alignment: .trailing, spacing: 2) {
						Text(sleepDurationLabel(start: event.start, end: timeline.date))
							.font(.system(size: 15, weight: .semibold))
							.foregroundStyle(Color.white.opacity(0.88))
							.monospacedDigit()
						Text("Live")
							.font(.system(size: 11, weight: .bold))
							.foregroundStyle(Color.white.opacity(0.66))
					}
				}
			}
		}
		.padding(.horizontal, 12)
		.frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
		.background(
			RoundedRectangle(cornerRadius: 14, style: .continuous)
				.fill(Color(red: 0.15, green: 0.22, blue: 0.34).opacity(0.72))
		)
	}
}

private struct AttachedSwipeSleepRow: View {
	private enum DragAxis {
		case undecided
		case horizontal
		case vertical
	}

	let event: SleepEvent
	let intervalText: String
	let isRemoving: Bool
	@Binding var revealedDeleteID: UUID?
	let onDelete: () -> Void

	@State private var rowOffset: CGFloat = 0
	@State private var dragAxis: DragAxis = .undecided
	private let revealWidth: CGFloat = 92
	private let revealTrigger: CGFloat = 54
	private let minimumHorizontalStart: CGFloat = 16
	private let horizontalPriorityRatio: CGFloat = 1.5

	var body: some View {
		ZStack(alignment: .trailing) {
			Button(role: .destructive, action: onDelete) {
				ZStack {
					RoundedRectangle(cornerRadius: 14, style: .continuous)
						.fill(Color.red.opacity(0.88))
					Image(systemName: "trash.fill")
						.font(.system(size: 16, weight: .semibold))
						.foregroundStyle(.white)
				}
				.frame(width: revealWidth, height: 58)
			}
			.buttonStyle(.plain)
			.offset(x: revealWidth - revealedWidth)

			SleepLogSheetRow(event: event, intervalText: intervalText)
				.frame(height: 58)
				.offset(x: rowOffset)
				.simultaneousGesture(rowDragGesture)
				.onTapGesture {
					if revealedDeleteID == event.id {
						withAnimation(.easeOut(duration: 0.15)) {
							revealedDeleteID = nil
							rowOffset = 0
						}
					}
				}
		}
		.frame(height: 58)
		.clipped()
		.listRowInsets(EdgeInsets(top: isRemoving ? 0 : 6, leading: 12, bottom: isRemoving ? 0 : 6, trailing: 12))
		.listRowBackground(Color.clear)
		.listRowSeparator(.hidden)
		.opacity(isRemoving ? 0 : 1)
		.scaleEffect(y: isRemoving ? 0.96 : 1, anchor: .top)
		.frame(height: isRemoving ? 0 : 58)
		.clipped()
		.allowsHitTesting(!isRemoving)
		.animation(.easeInOut(duration: 0.18), value: isRemoving)
		.onChange(of: revealedDeleteID) { newValue in
			if newValue == event.id {
				withAnimation(.easeOut(duration: 0.15)) {
					rowOffset = -revealWidth
				}
			} else {
				withAnimation(.easeOut(duration: 0.15)) {
					rowOffset = 0
				}
			}
		}
	}

	private var revealedWidth: CGFloat {
		max(0, min(revealWidth, -rowOffset))
	}

	private var rowDragGesture: some Gesture {
		DragGesture(minimumDistance: 16)
			.onChanged { value in
				let x = value.translation.width
				let y = value.translation.height

				if dragAxis == .undecided {
					let absX = abs(x)
					let absY = abs(y)
					if absX < minimumHorizontalStart && absY < minimumHorizontalStart {
						return
					}
					if x < 0, absX > absY * horizontalPriorityRatio {
						dragAxis = .horizontal
					} else if revealedDeleteID == event.id, absX > absY * horizontalPriorityRatio {
						dragAxis = .horizontal
					} else {
						dragAxis = .vertical
						return
					}
				}

				guard dragAxis == .horizontal else { return }
				let translation = value.translation.width
				if revealedDeleteID == event.id {
					rowOffset = max(-revealWidth, min(0, -revealWidth + translation))
				} else {
					rowOffset = max(-revealWidth, min(0, translation))
				}
			}
			.onEnded { _ in
				guard dragAxis == .horizontal else {
					dragAxis = .undecided
					return
				}

				let shouldReveal = rowOffset < -revealTrigger
				withAnimation(.easeOut(duration: 0.16)) {
					if shouldReveal {
						revealedDeleteID = event.id
						rowOffset = -revealWidth
					} else {
						revealedDeleteID = nil
						rowOffset = 0
					}
				}
				dragAxis = .undecided
			}
	}
}

private struct ZynLogSheet: View {
	let events: [ZynEvent]
	let onDelete: (UUID) -> Void
	@State private var revealedDeleteID: UUID?
	@State private var displayedEvents: [ZynEvent] = []
	@State private var removingEventIDs: Set<UUID> = []

	var body: some View {
		NavigationStack {
			List {
				if logSections.isEmpty {
					Section {
						Text("No zyn logs yet")
							.foregroundStyle(.secondary)
					}
				} else {
					ForEach(logSections) { section in
						Section(section.title.uppercased()) {
							ForEach(section.events) { event in
								AttachedSwipeZynRow(
									event: event,
									label: eventLabel(for: event),
									isRemoving: removingEventIDs.contains(event.id),
									revealedDeleteID: $revealedDeleteID,
									onDelete: { deleteWithCollapse(event.id) }
								)
							}
						}
					}
				}
			}
			.scrollContentBackground(.hidden)
			.background(
				LinearGradient(
					colors: [
						Color(red: 0.09, green: 0.16, blue: 0.26).opacity(0.94),
						Color(red: 0.08, green: 0.14, blue: 0.24).opacity(0.96)
					],
					startPoint: .topLeading,
					endPoint: .bottomTrailing
				)
				.ignoresSafeArea()
			)
			.navigationTitle("Recent Zyn Logs")
			.navigationBarTitleDisplayMode(.inline)
		}
		.preferredColorScheme(.dark)
		.presentationDetents([.fraction(0.58)])
		.presentationDragIndicator(.visible)
		.onAppear {
			displayedEvents = events
		}
		.onChange(of: events) { newEvents in
			displayedEvents = newEvents.filter { !removingEventIDs.contains($0.id) }
		}
	}

	private var logSections: [ZynLogSection] {
		let calendar = Calendar.current
		let grouped = Dictionary(grouping: displayedEvents) { event in
			calendar.startOfDay(for: event.timestamp)
		}

		return grouped.keys
			.sorted(by: >)
			.map { dayStart in
				ZynLogSection(
					dayStart: dayStart,
					title: sectionTitle(for: dayStart),
					events: (grouped[dayStart] ?? []).sorted(by: { $0.timestamp > $1.timestamp })
				)
			}
	}

	private func sectionTitle(for dayStart: Date) -> String {
		let calendar = Calendar.current
		if calendar.isDateInToday(dayStart) { return "Today" }
		if calendar.isDateInYesterday(dayStart) { return "Yesterday" }
		return dayStart.formatted(.dateTime.month().day().year())
	}

	private func eventLabel(for event: ZynEvent) -> String {
		let trimmedStrength = event.strength?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
		if trimmedStrength.isEmpty {
			return "Zyn Log"
		}
		return "\(trimmedStrength) Zyn"
	}

		private func deleteWithCollapse(_ id: UUID) {
			guard !removingEventIDs.contains(id) else { return }
			withAnimation(.easeInOut(duration: 0.18)) {
				_ = removingEventIDs.insert(id)
			}
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
			displayedEvents.removeAll { $0.id == id }
			removingEventIDs.remove(id)
			if revealedDeleteID == id {
				revealedDeleteID = nil
			}
			onDelete(id)
		}
	}
}

private struct AttachedSwipeZynRow: View {
	private enum DragAxis {
		case undecided
		case horizontal
		case vertical
	}

	let event: ZynEvent
	let label: String
	let isRemoving: Bool
	@Binding var revealedDeleteID: UUID?
	let onDelete: () -> Void

	@State private var rowOffset: CGFloat = 0
	@State private var dragAxis: DragAxis = .undecided
	private let revealWidth: CGFloat = 92
	private let revealTrigger: CGFloat = 54
	private let minimumHorizontalStart: CGFloat = 16
	private let horizontalPriorityRatio: CGFloat = 1.5

	var body: some View {
		ZStack(alignment: .trailing) {
			Button(role: .destructive, action: onDelete) {
				ZStack {
					RoundedRectangle(cornerRadius: 14, style: .continuous)
						.fill(Color.red.opacity(0.88))
					Image(systemName: "trash.fill")
						.font(.system(size: 16, weight: .semibold))
						.foregroundStyle(.white)
				}
				.frame(width: revealWidth, height: 58)
			}
			.buttonStyle(.plain)
			.offset(x: revealWidth - revealedWidth)

			HStack(spacing: 12) {
				Text(label)
					.font(.system(size: 17, weight: .semibold))
					.foregroundStyle(.white)
				Spacer()
				Text(event.timestamp.formatted(date: .omitted, time: .shortened))
					.font(.system(size: 15, weight: .medium))
					.foregroundStyle(Color.white.opacity(0.68))
					.monospacedDigit()
			}
			.padding(.horizontal, 12)
			.frame(height: 58)
			.background(
				RoundedRectangle(cornerRadius: 14, style: .continuous)
					.fill(Color(red: 0.15, green: 0.22, blue: 0.34).opacity(0.72))
			)
			.offset(x: rowOffset)
			.simultaneousGesture(rowDragGesture)
			.onTapGesture {
				if revealedDeleteID == event.id {
					withAnimation(.easeOut(duration: 0.15)) {
						revealedDeleteID = nil
						rowOffset = 0
					}
				}
				}
		}
		.frame(height: 58)
		.clipped()
		.listRowInsets(EdgeInsets(top: isRemoving ? 0 : 6, leading: 12, bottom: isRemoving ? 0 : 6, trailing: 12))
		.listRowBackground(Color.clear)
		.listRowSeparator(.hidden)
		.opacity(isRemoving ? 0 : 1)
		.scaleEffect(y: isRemoving ? 0.96 : 1, anchor: .top)
		.frame(height: isRemoving ? 0 : 58)
		.clipped()
		.allowsHitTesting(!isRemoving)
		.animation(.easeInOut(duration: 0.18), value: isRemoving)
		.onChange(of: revealedDeleteID) { newValue in
			if newValue == event.id {
				withAnimation(.easeOut(duration: 0.15)) {
					rowOffset = -revealWidth
				}
			} else {
				withAnimation(.easeOut(duration: 0.15)) {
					rowOffset = 0
				}
			}
		}
	}

	private var revealedWidth: CGFloat {
		max(0, min(revealWidth, -rowOffset))
	}

	private var rowDragGesture: some Gesture {
		DragGesture(minimumDistance: 16)
			.onChanged { value in
				let x = value.translation.width
				let y = value.translation.height

				if dragAxis == .undecided {
					let absX = abs(x)
					let absY = abs(y)
					if absX < minimumHorizontalStart && absY < minimumHorizontalStart {
						return
					}
					if x < 0, absX > absY * horizontalPriorityRatio {
						dragAxis = .horizontal
					} else if revealedDeleteID == event.id, absX > absY * horizontalPriorityRatio {
						dragAxis = .horizontal
					} else {
						dragAxis = .vertical
						return
					}
				}

				guard dragAxis == .horizontal else { return }
				let translation = value.translation.width
				if revealedDeleteID == event.id {
					rowOffset = max(-revealWidth, min(0, -revealWidth + translation))
				} else {
					rowOffset = max(-revealWidth, min(0, translation))
				}
			}
			.onEnded { _ in
				guard dragAxis == .horizontal else {
					dragAxis = .undecided
					return
				}

				let shouldReveal = rowOffset < -revealTrigger
				withAnimation(.easeOut(duration: 0.16)) {
					if shouldReveal {
						revealedDeleteID = event.id
						rowOffset = -revealWidth
					} else {
						revealedDeleteID = nil
						rowOffset = 0
					}
				}
				dragAxis = .undecided
			}
	}
}

private struct SleepLogListOverlay: View {
	let events: [SleepEvent]
	let onDelete: (UUID) -> Void
	let onClose: () -> Void

	@State private var panelOffset: CGFloat = 520
	@State private var backdropOpacity: CGFloat = 0
	@State private var isDismissing: Bool = false
	@State private var revealedDeleteID: UUID?
	@State private var displayedEvents: [SleepEvent] = []
	@State private var removingEventIDs: Set<UUID> = []
	private let panelAnimationDuration: TimeInterval = 0.22
	private let maxBackdropOpacity: CGFloat = 0.38
	private let sleepDayBoundaryHour: Int = 15

	var body: some View {
		ZStack(alignment: .bottom) {
			Color.black.opacity(backdropOpacity)
				.ignoresSafeArea()
				.contentShape(Rectangle())

			VStack(spacing: 0) {
				HStack {
					Text("Recent Sleep Logs")
						.font(.system(size: 20, weight: .bold, design: .rounded))
						.foregroundStyle(.white)
					Spacer()
					Button(action: dismissOverlay) {
						Image(systemName: "xmark")
							.font(.system(size: 14, weight: .bold))
							.foregroundStyle(Color.white.opacity(0.85))
							.frame(width: 30, height: 30)
							.background(Circle().fill(Color.white.opacity(0.12)))
					}
					.buttonStyle(.plain)
				}
				.padding(.horizontal, 20)
				.padding(.vertical, 14)

				Divider().background(Color.white.opacity(0.12))

				if logSections.isEmpty {
					VStack(spacing: 10) {
						Image(systemName: "clock.badge.questionmark")
							.font(.system(size: 28, weight: .semibold))
							.foregroundStyle(Color.white.opacity(0.42))
						Text("No sleep logs yet")
							.font(.system(size: 17, weight: .semibold, design: .rounded))
							.foregroundStyle(Color.white.opacity(0.70))
					}
					.frame(maxWidth: .infinity, maxHeight: .infinity)
				} else {
					ScrollView(showsIndicators: false) {
						LazyVStack(alignment: .leading, spacing: 0) {
							ForEach(logSections) { section in
								Text(section.title.uppercased())
									.font(.system(size: 14, weight: .medium, design: .rounded))
									.foregroundStyle(Color.white.opacity(0.42))
									.padding(.top, 18)
									.padding(.bottom, 8)
									.padding(.horizontal, 20)

								ForEach(section.events) { event in
									SwipeToDeleteSleepLogRow(
										event: event,
										label: eventLabel(for: event),
										isRemoving: removingEventIDs.contains(event.id),
										revealedDeleteID: $revealedDeleteID,
										onDelete: { deleteWithCollapse(event.id) }
									)
									.padding(.horizontal, 12)
								}
							}
						}
						.padding(.bottom, 24)
					}
				}
			}
			.frame(maxWidth: .infinity)
			.frame(height: 470)
			.background(
				RoundedRectangle(cornerRadius: 28, style: .continuous)
					.fill(Color(red: 0.06, green: 0.10, blue: 0.18).opacity(0.98))
					.overlay(
						RoundedRectangle(cornerRadius: 28, style: .continuous)
							.stroke(Color.white.opacity(0.12), lineWidth: 1)
					)
			)
			.padding(.horizontal, 14)
			.padding(.bottom, 10)
			.offset(y: panelOffset)
		}
		.onAppear {
			panelOffset = 520
			backdropOpacity = 0
			displayedEvents = events
			withAnimation(.easeOut(duration: panelAnimationDuration)) {
				panelOffset = 0
				backdropOpacity = maxBackdropOpacity
			}
		}
		.onChange(of: events) { newEvents in
			displayedEvents = newEvents.filter { !removingEventIDs.contains($0.id) }
		}
		.transition(.opacity)
	}

	private func dismissOverlay() {
		guard !isDismissing else { return }
		isDismissing = true
		withAnimation(.easeIn(duration: panelAnimationDuration)) {
			panelOffset = 520
			backdropOpacity = 0
		}
		DispatchQueue.main.asyncAfter(deadline: .now() + panelAnimationDuration) {
			onClose()
		}
	}

		private func deleteWithCollapse(_ id: UUID) {
			guard !removingEventIDs.contains(id) else { return }
			withAnimation(.easeInOut(duration: 0.18)) {
				_ = removingEventIDs.insert(id)
			}
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
			displayedEvents.removeAll { $0.id == id }
			removingEventIDs.remove(id)
			if revealedDeleteID == id {
				revealedDeleteID = nil
			}
			onDelete(id)
		}
	}

	private var logSections: [SleepLogSection] {
		let grouped = Dictionary(grouping: displayedEvents) { event in
			sleepDayStart(for: event.start)
		}

		return grouped.keys
			.sorted(by: >)
			.map { dayStart in
				SleepLogSection(
					dayStart: dayStart,
					title: sectionTitle(for: dayStart),
					events: (grouped[dayStart] ?? []).sorted(by: { $0.start > $1.start })
				)
			}
	}

	private func sectionTitle(for dayStart: Date) -> String {
		let calendar = Calendar.current
		let currentSleepDay = sleepDayStart(for: Date())
		if calendar.isDate(dayStart, inSameDayAs: currentSleepDay) { return "Today" }
		if let yesterdaySleepDay = calendar.date(byAdding: .day, value: -1, to: currentSleepDay),
		   calendar.isDate(dayStart, inSameDayAs: yesterdaySleepDay) {
			return "Yesterday"
		}
		return dayStart.formatted(.dateTime.month().day().year())
	}

	private func sleepDayStart(for timestamp: Date) -> Date {
		let calendar = Calendar.current
		let startOfCalendarDay = calendar.startOfDay(for: timestamp)
		let hour = calendar.component(.hour, from: timestamp)
		let baseDay = hour < sleepDayBoundaryHour
			? calendar.date(byAdding: .day, value: -1, to: startOfCalendarDay) ?? startOfCalendarDay
			: startOfCalendarDay
		return calendar.date(byAdding: .hour, value: sleepDayBoundaryHour, to: baseDay) ?? baseDay
	}

	private func eventLabel(for event: SleepEvent) -> String {
		let start = event.start.formatted(date: .omitted, time: .shortened)
		if let end = event.end {
			return "\(start) → \(end.formatted(date: .omitted, time: .shortened))"
		}
		return "\(start) →"
	}
}

private struct ZynLogListOverlay: View {
	let events: [ZynEvent]
	let onDelete: (UUID) -> Void
	let onClose: () -> Void

	@State private var panelOffset: CGFloat = 520
	@State private var backdropOpacity: CGFloat = 0
	@State private var isDismissing: Bool = false
	@State private var revealedDeleteID: UUID?
	@State private var displayedEvents: [ZynEvent] = []
	@State private var removingEventIDs: Set<UUID> = []
	private let panelAnimationDuration: TimeInterval = 0.22
	private let maxBackdropOpacity: CGFloat = 0.38
	private let deleteCollapseDuration: TimeInterval = 0.18
	private let deleteRemoveDelay: TimeInterval = 0.20

	var body: some View {
		ZStack(alignment: .bottom) {
			Color.black.opacity(backdropOpacity)
				.ignoresSafeArea()
				.contentShape(Rectangle())

			VStack(spacing: 0) {
				HStack {
					Text("Recent Zyn Logs")
						.font(.system(size: 20, weight: .bold, design: .rounded))
						.foregroundStyle(.white)
					Spacer()
					Button(action: dismissOverlay) {
						Image(systemName: "xmark")
							.font(.system(size: 14, weight: .bold))
							.foregroundStyle(Color.white.opacity(0.85))
							.frame(width: 30, height: 30)
							.background(Circle().fill(Color.white.opacity(0.12)))
					}
					.buttonStyle(.plain)
					}
					.padding(.horizontal, 20)
					.padding(.vertical, 14)

					Divider().background(Color.white.opacity(0.12))

				if logSections.isEmpty {
					VStack(spacing: 10) {
						Image(systemName: "clock.badge.questionmark")
							.font(.system(size: 28, weight: .semibold))
							.foregroundStyle(Color.white.opacity(0.42))
						Text("No zyn logs yet")
							.font(.system(size: 17, weight: .semibold, design: .rounded))
							.foregroundStyle(Color.white.opacity(0.70))
					}
					.frame(maxWidth: .infinity, maxHeight: .infinity)
				} else {
					ScrollView(showsIndicators: false) {
						LazyVStack(alignment: .leading, spacing: 0) {
							ForEach(logSections) { section in
								Text(section.title.uppercased())
									.font(.system(size: 14, weight: .medium, design: .rounded))
									.foregroundStyle(Color.white.opacity(0.42))
									.padding(.top, 18)
									.padding(.bottom, 8)
									.padding(.horizontal, 20)

								ForEach(section.events) { event in
									SwipeToDeleteLogRow(
										event: event,
										label: eventLabel(for: event),
										isRemoving: removingEventIDs.contains(event.id),
										revealedDeleteID: $revealedDeleteID,
										onDelete: { deleteWithCollapse(event.id) }
									)
									.padding(.horizontal, 12)
								}
							}
						}
						.padding(.bottom, 24)
					}
				}
			}
			.frame(maxWidth: .infinity)
			.frame(height: 470)
			.background(
				RoundedRectangle(cornerRadius: 28, style: .continuous)
					.fill(Color(red: 0.06, green: 0.10, blue: 0.18).opacity(0.98))
					.overlay(
						RoundedRectangle(cornerRadius: 28, style: .continuous)
							.stroke(Color.white.opacity(0.12), lineWidth: 1)
					)
				)
				.padding(.horizontal, 14)
				.padding(.bottom, 10)
				.offset(y: panelOffset)
		}
		.onAppear {
			panelOffset = 520
			backdropOpacity = 0
			displayedEvents = events
			withAnimation(.easeOut(duration: panelAnimationDuration)) {
				panelOffset = 0
				backdropOpacity = maxBackdropOpacity
			}
		}
		.onChange(of: events) { newEvents in
			displayedEvents = newEvents.filter { !removingEventIDs.contains($0.id) }
		}
		.transition(.opacity)
	}

	private func dismissOverlay() {
		guard !isDismissing else { return }
		isDismissing = true
		withAnimation(.easeIn(duration: panelAnimationDuration)) {
			panelOffset = 520
			backdropOpacity = 0
		}
		DispatchQueue.main.asyncAfter(deadline: .now() + panelAnimationDuration) {
			onClose()
		}
	}

		private func deleteWithCollapse(_ id: UUID) {
			guard !removingEventIDs.contains(id) else { return }
			withAnimation(.easeInOut(duration: deleteCollapseDuration)) {
				_ = removingEventIDs.insert(id)
			}
		DispatchQueue.main.asyncAfter(deadline: .now() + deleteRemoveDelay) {
			withAnimation(.easeInOut(duration: deleteCollapseDuration)) {
				displayedEvents.removeAll { $0.id == id }
				removingEventIDs.remove(id)
				if revealedDeleteID == id {
					revealedDeleteID = nil
				}
			}
			onDelete(id)
		}
	}

	private var logSections: [ZynLogSection] {
		let calendar = Calendar.current
		let grouped = Dictionary(grouping: displayedEvents) { event in
			calendar.startOfDay(for: event.timestamp)
		}

		return grouped.keys
			.sorted(by: >)
			.map { dayStart in
				ZynLogSection(
					dayStart: dayStart,
					title: sectionTitle(for: dayStart),
					events: (grouped[dayStart] ?? []).sorted(by: { $0.timestamp > $1.timestamp })
				)
			}
	}

	private func sectionTitle(for dayStart: Date) -> String {
		let calendar = Calendar.current
		if calendar.isDateInToday(dayStart) { return "Today" }
		if calendar.isDateInYesterday(dayStart) { return "Yesterday" }
		return dayStart.formatted(.dateTime.month().day().year())
	}

	private func eventLabel(for event: ZynEvent) -> String {
		let trimmedStrength = event.strength?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
		if trimmedStrength.isEmpty {
			return "Zyn Log"
		}
		return "\(trimmedStrength) Zyn"
	}
}

private struct SwipeToDeleteSleepLogRow: View {
	private enum DragAxis {
		case undecided
		case horizontal
		case vertical
	}

	let event: SleepEvent
	let label: String
	let isRemoving: Bool
	@Binding var revealedDeleteID: UUID?
	let onDelete: () -> Void

	@State private var rowOffset: CGFloat = 0
	@State private var dragAxis: DragAxis = .undecided
	private let revealWidth: CGFloat = 88
	private let revealTrigger: CGFloat = 54
	private let minimumHorizontalStart: CGFloat = 18
	private let horizontalPriorityRatio: CGFloat = 1.55

	var body: some View {
		ZStack(alignment: .leading) {
			Button(role: .destructive, action: onDelete) {
				ZStack {
					RoundedRectangle(cornerRadius: 14, style: .continuous)
						.fill(Color.red.opacity(0.88))
					Image(systemName: "trash.fill")
						.font(.system(size: 16, weight: .semibold))
						.foregroundStyle(.white)
				}
				.frame(width: revealWidth, height: 58)
			}
			.buttonStyle(.plain)
			.opacity(deleteRevealProgress)

			HStack(spacing: 12) {
				Text(label)
					.font(.system(size: 18, weight: .semibold, design: .rounded))
					.foregroundStyle(.white)
					.monospacedDigit()
					.lineLimit(1)
				Spacer()
				durationView
			}
			.padding(.horizontal, 12)
			.frame(height: 58)
			.background(
				RoundedRectangle(cornerRadius: 14, style: .continuous)
					.fill(Color(red: 0.10, green: 0.16, blue: 0.28).opacity(0.98))
			)
			.offset(x: rowOffset)
			.simultaneousGesture(rowDragGesture)
			.onTapGesture {
				if revealedDeleteID == event.id {
					withAnimation(.easeOut(duration: 0.15)) {
						revealedDeleteID = nil
						rowOffset = 0
					}
				}
			}
		}
		.frame(height: isRemoving ? 0 : 66)
		.opacity(isRemoving ? 0 : 1)
		.scaleEffect(y: isRemoving ? 0.96 : 1, anchor: .top)
		.clipped()
		.allowsHitTesting(!isRemoving)
		.animation(.easeInOut(duration: 0.18), value: isRemoving)
		.onChange(of: revealedDeleteID) { newValue in
			if newValue == event.id {
				withAnimation(.easeOut(duration: 0.15)) {
					rowOffset = revealWidth
				}
			} else {
				withAnimation(.easeOut(duration: 0.15)) {
					rowOffset = 0
				}
			}
		}
	}

	private var deleteRevealProgress: CGFloat {
		let start: CGFloat = 30
		let progress = (rowOffset - start) / max(1, revealWidth - start)
		return min(1, max(0, progress))
	}

	private var rowDragGesture: some Gesture {
		DragGesture(minimumDistance: 18)
			.onChanged { value in
				let x = value.translation.width
				let y = value.translation.height

				if dragAxis == .undecided {
					let absX = abs(x)
					let absY = abs(y)
					if absX < minimumHorizontalStart && absY < minimumHorizontalStart {
						return
					}
					if x > 0, absX > absY * horizontalPriorityRatio {
						dragAxis = .horizontal
					} else if revealedDeleteID == event.id, absX > absY * horizontalPriorityRatio {
						dragAxis = .horizontal
					} else {
						dragAxis = .vertical
						return
					}
				}

				guard dragAxis == .horizontal else { return }

				let translation = value.translation.width
				if revealedDeleteID == event.id {
					rowOffset = max(0, min(revealWidth, revealWidth + translation))
				} else {
					rowOffset = max(0, min(revealWidth, translation))
				}
			}
			.onEnded { _ in
				guard dragAxis == .horizontal else {
					dragAxis = .undecided
					return
				}

				let shouldReveal = rowOffset > revealTrigger
				withAnimation(.easeOut(duration: 0.16)) {
					if shouldReveal {
						revealedDeleteID = event.id
						rowOffset = revealWidth
					} else {
						revealedDeleteID = nil
						rowOffset = 0
					}
				}
				dragAxis = .undecided
			}
	}

	@ViewBuilder
	private var durationView: some View {
		if let end = event.end {
			Text(sleepDurationLabel(start: event.start, end: end))
				.font(.system(size: 15, weight: .semibold, design: .rounded))
				.foregroundStyle(Color.white.opacity(0.80))
				.monospacedDigit()
		} else {
			TimelineView(.periodic(from: .now, by: 60)) { timeline in
				VStack(alignment: .trailing, spacing: 3) {
					Text(sleepDurationLabel(start: event.start, end: timeline.date))
						.font(.system(size: 15, weight: .semibold, design: .rounded))
						.foregroundStyle(Color.white.opacity(0.88))
						.monospacedDigit()
					Text("Live")
						.font(.system(size: 11, weight: .bold, design: .rounded))
						.foregroundStyle(Color.white.opacity(0.66))
				}
			}
		}
	}
}

private struct SwipeToDeleteLogRow: View {
	private enum DragAxis {
		case undecided
		case horizontal
		case vertical
	}

	let event: ZynEvent
	let label: String
	let isRemoving: Bool
	@Binding var revealedDeleteID: UUID?
	let onDelete: () -> Void

	@State private var rowOffset: CGFloat = 0
	@State private var dragAxis: DragAxis = .undecided
	private let revealWidth: CGFloat = 88
	private let revealTrigger: CGFloat = 54
	private let minimumHorizontalStart: CGFloat = 18
	private let horizontalPriorityRatio: CGFloat = 1.55

	var body: some View {
		ZStack(alignment: .leading) {
			Button(role: .destructive, action: onDelete) {
				ZStack {
					RoundedRectangle(cornerRadius: 14, style: .continuous)
						.fill(Color.red.opacity(0.88))
					Image(systemName: "trash.fill")
						.font(.system(size: 16, weight: .semibold))
						.foregroundStyle(.white)
				}
				.frame(width: revealWidth, height: 58)
			}
			.buttonStyle(.plain)
			.opacity(deleteRevealProgress)

			HStack(spacing: 12) {
				Text(label)
					.font(.system(size: 18, weight: .semibold, design: .rounded))
					.foregroundStyle(.white)
				Spacer()
				Text(event.timestamp.formatted(date: .omitted, time: .shortened))
					.font(.system(size: 15, weight: .medium, design: .rounded))
					.foregroundStyle(Color.white.opacity(0.64))
					.monospacedDigit()
			}
			.padding(.horizontal, 12)
			.frame(height: 58)
			.background(
				RoundedRectangle(cornerRadius: 14, style: .continuous)
					.fill(Color(red: 0.10, green: 0.16, blue: 0.28).opacity(0.98))
			)
			.offset(x: rowOffset)
			.simultaneousGesture(rowDragGesture)
			.onTapGesture {
				if revealedDeleteID == event.id {
					withAnimation(.easeOut(duration: 0.15)) {
						revealedDeleteID = nil
						rowOffset = 0
					}
				}
			}
		}
		.frame(height: isRemoving ? 0 : 66)
		.opacity(isRemoving ? 0 : 1)
		.scaleEffect(y: isRemoving ? 0.96 : 1, anchor: .top)
		.clipped()
		.allowsHitTesting(!isRemoving)
		.animation(.easeInOut(duration: 0.18), value: isRemoving)
		.onChange(of: revealedDeleteID) { newValue in
			if newValue == event.id {
				withAnimation(.easeOut(duration: 0.15)) {
					rowOffset = revealWidth
				}
			} else {
				withAnimation(.easeOut(duration: 0.15)) {
					rowOffset = 0
				}
			}
		}
	}

	private var deleteRevealProgress: CGFloat {
		let start: CGFloat = 30
		let progress = (rowOffset - start) / max(1, revealWidth - start)
		return min(1, max(0, progress))
	}

	private var rowDragGesture: some Gesture {
		DragGesture(minimumDistance: 18)
			.onChanged { value in
				let x = value.translation.width
				let y = value.translation.height

				if dragAxis == .undecided {
					let absX = abs(x)
					let absY = abs(y)
					if absX < minimumHorizontalStart && absY < minimumHorizontalStart {
						return
					}
					if x > 0, absX > absY * horizontalPriorityRatio {
						dragAxis = .horizontal
					} else if revealedDeleteID == event.id, absX > absY * horizontalPriorityRatio {
						dragAxis = .horizontal
					} else {
						dragAxis = .vertical
						return
					}
				}

				guard dragAxis == .horizontal else { return }

				let translation = value.translation.width
				if revealedDeleteID == event.id {
					rowOffset = max(0, min(revealWidth, revealWidth + translation))
				} else {
					rowOffset = max(0, min(revealWidth, translation))
				}
			}
			.onEnded { _ in
				guard dragAxis == .horizontal else {
					dragAxis = .undecided
					return
				}

				let shouldReveal = rowOffset > revealTrigger
				withAnimation(.easeOut(duration: 0.16)) {
					if shouldReveal {
						revealedDeleteID = event.id
						rowOffset = revealWidth
					} else {
						revealedDeleteID = nil
						rowOffset = 0
					}
				}
				dragAxis = .undecided
			}
	}
}

private struct ManageTrackersSheet: View {
	@Environment(\.dismiss) private var dismiss
	let isZynTrackerActive: Bool
	let activeTrackers: [TrackerKind]
	let orderedActivePageIDs: [String]
	let maxActiveTrackers: Int
	let canActivateZyn: () -> Bool
	let activateZyn: () -> Void
	let deactivateZyn: () -> Void
	let canActivate: (TrackerKind) -> Bool
	let activate: (TrackerKind) -> Void
	let deactivate: (TrackerKind) -> Void

	private enum ManageTrackerListItem: Identifiable {
		case zyn
		case custom(TrackerKind)

		var id: String {
			switch self {
			case .zyn:
				return "zyn"
			case .custom(let tracker):
				return "custom-\(tracker.rawValue)"
			}
		}
	}

	private var trackerCatalog: [TrackerKind] {
		TrackerKind.allCases.filter { !$0.isBuiltInDisabled && !$0.isRetiredFromUI }
	}

	private var activeAddableCount: Int {
		activeTrackers.count + (isZynTrackerActive ? 1 : 0)
	}

	private var orderedRows: [ManageTrackerListItem] {
		var rows: [ManageTrackerListItem] = []
		var seen = Set<String>()
		let activeCustomSet = Set(activeTrackers)

		// User-specified rule: top of list should mirror right-most active page first.
		for id in orderedActivePageIDs.reversed() {
			let row: ManageTrackerListItem?
			if id == "zyn" {
				row = isZynTrackerActive ? .zyn : nil
			} else if id.hasPrefix("custom-"),
					  let tracker = TrackerKind(rawValue: String(id.dropFirst("custom-".count))),
					  activeCustomSet.contains(tracker) {
				row = .custom(tracker)
			} else {
				row = nil
			}

			if let row, seen.insert(row.id).inserted {
				rows.append(row)
			}
		}

		// Fallback safety if active IDs are missing from the passed ordering.
		if isZynTrackerActive, seen.insert("zyn").inserted {
			rows.append(.zyn)
		}
		for tracker in activeTrackers where seen.insert("custom-\(tracker.rawValue)").inserted {
			rows.append(.custom(tracker))
		}

		// Inactive trackers remain below active rows.
		if !isZynTrackerActive {
			rows.append(.zyn)
		}
		for tracker in trackerCatalog where !activeCustomSet.contains(tracker) {
			rows.append(.custom(tracker))
		}

		return rows
	}

	var body: some View {
		NavigationStack {
			List {
				Section {
					HStack {
						Text("Active")
							.font(.system(size: 15, weight: .semibold))
						Spacer()
						Text("\(activeAddableCount) / \(maxActiveTrackers) active")
							.font(.system(size: 14, weight: .semibold))
							.foregroundStyle(Color.white.opacity(0.74))
							.monospacedDigit()
					}
				}

				Section("Trackers") {
					ForEach(orderedRows) { row in
						switch row {
						case .zyn:
							zynRow
								.padding(.vertical, 4)
						case .custom(let tracker):
							trackerRow(tracker)
								.padding(.vertical, 4)
						}
					}
				}
			}
			.scrollContentBackground(.hidden)
			.background(
				LinearGradient(
					colors: [
						Color(red: 0.09, green: 0.16, blue: 0.26).opacity(0.94),
						Color(red: 0.08, green: 0.14, blue: 0.24).opacity(0.96)
					],
					startPoint: .topLeading,
					endPoint: .bottomTrailing
				)
				.ignoresSafeArea()
			)
			.navigationTitle("Manage Trackers")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button("Done") {
						dismiss()
					}
					.font(.system(size: 16, weight: .semibold))
				}
			}
		}
		.preferredColorScheme(.dark)
		.presentationDetents([.fraction(0.68)])
		.presentationDragIndicator(.visible)
	}

	private var zynRow: some View {
		HStack(spacing: 12) {
			Image(systemName: "pills.fill")
				.font(.system(size: 18, weight: .semibold))
				.foregroundStyle(Color.white.opacity(0.62))
				.frame(width: 20, height: 20)

			Text("ZYN")
				.font(.system(size: 16, weight: .semibold))
				.foregroundStyle(.white)

			Spacer()

			if isZynTrackerActive {
				Button("Remove") {
					deactivateZyn()
				}
				.font(.system(size: 13, weight: .semibold))
				.foregroundStyle(.white)
				.padding(.horizontal, 12)
				.padding(.vertical, 6)
				.background(
					Capsule()
						.fill(Color.red.opacity(0.68))
				)
				.buttonStyle(.plain)
			} else {
				Button("Add") {
					activateZyn()
				}
				.font(.system(size: 13, weight: .semibold))
				.foregroundStyle(.white)
				.padding(.horizontal, 16)
				.padding(.vertical, 6)
				.background(
					Capsule()
						.fill(Color(red: 0.26, green: 0.51, blue: 0.86).opacity(0.88))
				)
				.buttonStyle(.plain)
				.disabled(!canActivateZyn())
				.opacity(canActivateZyn() ? 1 : 0.42)
			}
		}
	}

	private func trackerRow(_ tracker: TrackerKind) -> some View {
		HStack(spacing: 12) {
			TrackerGlyphIcon(
				tracker: tracker,
				size: 20,
				tint: Color.white.opacity(0.62)
			)
			.frame(width: 22, height: 22)

			Text(tracker.displayName)
				.font(.system(size: 16, weight: .semibold))
				.foregroundStyle(.white)

			Spacer()

			actionButton(for: tracker)
		}
	}

	@ViewBuilder
	private func actionButton(for tracker: TrackerKind) -> some View {
		if tracker.isBuiltInDisabled {
			Text("Built-in")
				.font(.system(size: 13, weight: .semibold))
				.foregroundStyle(Color.white.opacity(0.48))
				.padding(.horizontal, 10)
				.padding(.vertical, 6)
				.background(
					Capsule()
						.fill(Color.white.opacity(0.08))
				)
		} else if activeTrackers.contains(tracker) {
			Button("Remove") {
				deactivate(tracker)
			}
			.font(.system(size: 13, weight: .semibold))
			.foregroundStyle(.white)
			.padding(.horizontal, 12)
			.padding(.vertical, 6)
			.background(
				Capsule()
					.fill(Color.red.opacity(0.68))
			)
			.buttonStyle(.plain)
		} else {
			Button("Add") {
				activate(tracker)
			}
			.font(.system(size: 13, weight: .semibold))
			.foregroundStyle(.white)
			.padding(.horizontal, 16)
			.padding(.vertical, 6)
			.background(
				Capsule()
					.fill(Color(red: 0.26, green: 0.51, blue: 0.86).opacity(0.88))
			)
			.buttonStyle(.plain)
			.disabled(!canActivate(tracker))
			.opacity(canActivate(tracker) ? 1 : 0.42)
		}
	}
}

private struct HabitLogSheet: View {
	let tracker: TrackerKind
	let events: [HabitEvent]
	let onDelete: (UUID) -> Void

	private var calendar: Calendar { Calendar.current }
	@State private var revealedDeleteID: UUID?
	@State private var displayedEvents: [HabitEvent] = []
	@State private var removingEventIDs: Set<UUID> = []

	var body: some View {
		NavigationStack {
			List {
				if logSections.isEmpty {
					Section {
						Text("No \(tracker.displayName.lowercased()) logs yet")
							.foregroundStyle(.secondary)
					}
				} else {
					ForEach(logSections) { section in
						Section(section.title.uppercased()) {
							ForEach(section.events) { event in
								AttachedSwipeHabitRow(
									event: event,
									label: eventLabel(for: event),
									isRemoving: removingEventIDs.contains(event.id),
									revealedDeleteID: $revealedDeleteID,
									onDelete: { deleteWithCollapse(event.id) }
								)
							}
						}
					}
				}
			}
			.scrollContentBackground(.hidden)
			.background(
				LinearGradient(
					colors: [
						Color(red: 0.09, green: 0.16, blue: 0.26).opacity(0.94),
						Color(red: 0.08, green: 0.14, blue: 0.24).opacity(0.96)
					],
					startPoint: .topLeading,
					endPoint: .bottomTrailing
				)
				.ignoresSafeArea()
			)
			.navigationTitle("Recent \(tracker.displayName) Logs")
			.navigationBarTitleDisplayMode(.inline)
		}
		.preferredColorScheme(.dark)
		.presentationDetents([.fraction(0.58)])
		.presentationDragIndicator(.visible)
		.onAppear {
			displayedEvents = events
		}
		.onChange(of: events) { newEvents in
			displayedEvents = newEvents.filter { !removingEventIDs.contains($0.id) }
		}
	}

	private var logSections: [HabitLogSection] {
		let grouped = Dictionary(grouping: displayedEvents) { event in
			calendar.startOfDay(for: event.timestamp)
		}

		return grouped.keys
			.sorted(by: >)
			.map { dayStart in
				HabitLogSection(
					dayStart: dayStart,
					title: sectionTitle(for: dayStart),
					events: (grouped[dayStart] ?? []).sorted(by: { $0.timestamp > $1.timestamp })
				)
			}
	}

	private func sectionTitle(for dayStart: Date) -> String {
		let today = calendar.startOfDay(for: Date())
		if calendar.isDate(dayStart, inSameDayAs: today) {
			return "Today"
		}
		if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
		   calendar.isDate(dayStart, inSameDayAs: yesterday) {
			return "Yesterday"
		}
		return dayStart.formatted(.dateTime.month().day().year())
	}

	private func eventLabel(for event: HabitEvent) -> String {
		if let note = event.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
			return note
		}
		return "\(tracker.displayName) Log"
	}

		private func deleteWithCollapse(_ id: UUID) {
			guard !removingEventIDs.contains(id) else { return }
			withAnimation(.easeInOut(duration: 0.18)) {
				_ = removingEventIDs.insert(id)
			}
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
			displayedEvents.removeAll { $0.id == id }
			removingEventIDs.remove(id)
			if revealedDeleteID == id {
				revealedDeleteID = nil
			}
			onDelete(id)
		}
	}
}

private struct AttachedSwipeHabitRow: View {
	private enum DragAxis {
		case undecided
		case horizontal
		case vertical
	}

	let event: HabitEvent
	let label: String
	let isRemoving: Bool
	@Binding var revealedDeleteID: UUID?
	let onDelete: () -> Void

	@State private var rowOffset: CGFloat = 0
	@State private var dragAxis: DragAxis = .undecided
	private let revealWidth: CGFloat = 92
	private let revealTrigger: CGFloat = 54
	private let minimumHorizontalStart: CGFloat = 16
	private let horizontalPriorityRatio: CGFloat = 1.5

	var body: some View {
		ZStack(alignment: .trailing) {
			Button(role: .destructive, action: onDelete) {
				ZStack {
					RoundedRectangle(cornerRadius: 14, style: .continuous)
						.fill(Color.red.opacity(0.88))
					Image(systemName: "trash.fill")
						.font(.system(size: 16, weight: .semibold))
						.foregroundStyle(.white)
				}
				.frame(width: revealWidth, height: 58)
			}
			.buttonStyle(.plain)
			.offset(x: revealWidth - revealedWidth)

			HStack(spacing: 12) {
				Text(label)
					.font(.system(size: 17, weight: .semibold))
					.foregroundStyle(.white)
					.lineLimit(1)
				Spacer()
				Text(event.timestamp.formatted(date: .omitted, time: .shortened))
					.font(.system(size: 15, weight: .medium))
					.foregroundStyle(Color.white.opacity(0.68))
					.monospacedDigit()
			}
			.padding(.horizontal, 12)
			.frame(height: 58)
			.background(
				RoundedRectangle(cornerRadius: 14, style: .continuous)
					.fill(Color(red: 0.15, green: 0.22, blue: 0.34).opacity(0.72))
			)
			.offset(x: rowOffset)
			.simultaneousGesture(rowDragGesture)
			.onTapGesture {
				if revealedDeleteID == event.id {
					withAnimation(.easeOut(duration: 0.15)) {
						revealedDeleteID = nil
						rowOffset = 0
					}
				}
			}
		}
		.frame(height: 58)
		.clipped()
		.listRowInsets(EdgeInsets(top: isRemoving ? 0 : 6, leading: 12, bottom: isRemoving ? 0 : 6, trailing: 12))
		.listRowBackground(Color.clear)
		.listRowSeparator(.hidden)
		.opacity(isRemoving ? 0 : 1)
		.scaleEffect(y: isRemoving ? 0.96 : 1, anchor: .top)
		.frame(height: isRemoving ? 0 : 58)
		.clipped()
		.allowsHitTesting(!isRemoving)
		.animation(.easeInOut(duration: 0.18), value: isRemoving)
		.onChange(of: revealedDeleteID) { newValue in
			if newValue == event.id {
				withAnimation(.easeOut(duration: 0.15)) {
					rowOffset = -revealWidth
				}
			} else {
				withAnimation(.easeOut(duration: 0.15)) {
					rowOffset = 0
				}
			}
		}
	}

	private var revealedWidth: CGFloat {
		max(0, min(revealWidth, -rowOffset))
	}

	private var rowDragGesture: some Gesture {
		DragGesture(minimumDistance: 16)
			.onChanged { value in
				let x = value.translation.width
				let y = value.translation.height

				if dragAxis == .undecided {
					let absX = abs(x)
					let absY = abs(y)
					if absX < minimumHorizontalStart && absY < minimumHorizontalStart {
						return
					}
					if x < 0, absX > absY * horizontalPriorityRatio {
						dragAxis = .horizontal
					} else if revealedDeleteID == event.id, absX > absY * horizontalPriorityRatio {
						dragAxis = .horizontal
					} else {
						dragAxis = .vertical
						return
					}
				}

				guard dragAxis == .horizontal else { return }
				let translation = value.translation.width
				if revealedDeleteID == event.id {
					rowOffset = max(-revealWidth, min(0, -revealWidth + translation))
				} else {
					rowOffset = max(-revealWidth, min(0, translation))
				}
			}
			.onEnded { _ in
				guard dragAxis == .horizontal else {
					dragAxis = .undecided
					return
				}

				let shouldReveal = rowOffset < -revealTrigger
				withAnimation(.easeOut(duration: 0.16)) {
					if shouldReveal {
						revealedDeleteID = event.id
						rowOffset = -revealWidth
					} else {
						revealedDeleteID = nil
						rowOffset = 0
					}
				}
				dragAxis = .undecided
			}
	}
}

private struct HabitLogSection: Identifiable {
	let dayStart: Date
	let title: String
	let events: [HabitEvent]
	var id: Date { dayStart }
}

private struct ZynLogSection: Identifiable {
	let dayStart: Date
	let title: String
	let events: [ZynEvent]
	var id: Date { dayStart }
}

private struct SleepLogSection: Identifiable {
	let dayStart: Date
	let title: String
	let events: [SleepEvent]
	var id: Date { dayStart }
}

private enum InsightsHistorySource: Hashable {
	case sleep(UUID)
	case zyn(UUID)
	case custom(UUID, TrackerKind)

	var id: String {
		switch self {
		case .sleep(let id):
			return "sleep-\(id.uuidString)"
		case .zyn(let id):
			return "zyn-\(id.uuidString)"
		case .custom(let id, _):
			return "custom-\(id.uuidString)"
		}
	}
}

private struct InsightsHistoryEntry: Identifiable {
	let source: InsightsHistorySource
	let timestamp: Date
	let title: String
	let subtitle: String?

	var id: String { source.id }
}

private struct InsightsHistorySection: Identifiable {
	let dayStart: Date
	let title: String
	let entries: [InsightsHistoryEntry]
	var id: Date { dayStart }
}

private struct InsightsFullHistorySheet: View {
	let sleepEvents: [SleepEvent]
	let zynEvents: [ZynEvent]
	let habitEvents: [HabitEvent]
	let onDeleteSleep: (UUID) -> Void
	let onDeleteZyn: (UUID) -> Void
	let onDeleteHabit: (UUID) -> Void

	private var calendar: Calendar { Calendar.current }
	@State private var revealedDeleteID: String?
	@State private var displayedEntries: [InsightsHistoryEntry] = []
	@State private var removingEntryIDs: Set<String> = []
	@State private var pendingDeleteEntryIDs: Set<String> = []

	var body: some View {
		List {
			if sections.isEmpty {
				Section {
					Text("No logs yet.")
						.foregroundStyle(.secondary)
				}
			} else {
				ForEach(sections) { section in
					Section(section.title.uppercased()) {
						ForEach(section.entries) { entry in
							AttachedSwipeInsightsHistoryRow(
								entry: entry,
								isRemoving: removingEntryIDs.contains(entry.id),
								revealedDeleteID: $revealedDeleteID,
								onDelete: { deleteWithCollapse(entry) }
							)
						}
					}
				}
			}
		}
		.scrollContentBackground(.hidden)
		.background(
			LinearGradient(
				colors: [
					Color(red: 0.09, green: 0.16, blue: 0.26).opacity(0.94),
					Color(red: 0.08, green: 0.14, blue: 0.24).opacity(0.96)
				],
				startPoint: .topLeading,
				endPoint: .bottomTrailing
			)
			.ignoresSafeArea()
		)
		.navigationTitle("Full History")
		.navigationBarTitleDisplayMode(.inline)
		.preferredColorScheme(.dark)
		.presentationDetents([.large])
		.presentationDragIndicator(.visible)
		.onAppear {
			syncDisplayedEntries()
		}
		.onChange(of: sleepEvents) { _ in
			syncDisplayedEntries()
		}
		.onChange(of: zynEvents) { _ in
			syncDisplayedEntries()
		}
		.onChange(of: habitEvents) { _ in
			syncDisplayedEntries()
		}
	}

	private var combinedEntries: [InsightsHistoryEntry] {
		var entries: [InsightsHistoryEntry] = sleepEvents.map { event in
			InsightsHistoryEntry(
				source: .sleep(event.id),
				timestamp: event.start,
				title: "Sleep Log",
				subtitle: sleepSubtitle(for: event)
			)
		}

		entries.append(contentsOf: zynEvents.map { event in
			InsightsHistoryEntry(
				source: .zyn(event.id),
				timestamp: event.timestamp,
				title: "ZYN Log",
				subtitle: normalizedNote(event.note)
			)
		})

		entries.append(contentsOf: habitEvents.compactMap { event in
			guard !event.tracker.isRetiredFromUI else { return nil }
			return InsightsHistoryEntry(
				source: .custom(event.id, event.tracker),
				timestamp: event.timestamp,
				title: "\(event.tracker.displayName) Log",
				subtitle: normalizedNote(event.note)
			)
		})

		return entries.sorted { $0.timestamp > $1.timestamp }
	}

	private var sections: [InsightsHistorySection] {
		let grouped = Dictionary(grouping: displayedEntries) { entry in
			calendar.startOfDay(for: entry.timestamp)
		}

		return grouped.keys
			.sorted(by: >)
			.map { dayStart in
				InsightsHistorySection(
					dayStart: dayStart,
					title: sectionTitle(for: dayStart),
					entries: (grouped[dayStart] ?? []).sorted(by: { $0.timestamp > $1.timestamp })
				)
			}
	}

	private func sectionTitle(for dayStart: Date) -> String {
		let today = calendar.startOfDay(for: Date())
		if calendar.isDate(dayStart, inSameDayAs: today) {
			return "Today"
		}
		if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
		   calendar.isDate(dayStart, inSameDayAs: yesterday) {
			return "Yesterday"
		}
		return dayStart.formatted(.dateTime.month().day().year())
	}

	private func syncDisplayedEntries() {
		let latestEntries = combinedEntries
		let latestEntryIDs = Set(latestEntries.map(\.id))
		pendingDeleteEntryIDs.formIntersection(latestEntryIDs)
		displayedEntries = latestEntries.filter { entry in
			!removingEntryIDs.contains(entry.id) && !pendingDeleteEntryIDs.contains(entry.id)
		}
	}

	private func sleepSubtitle(for event: SleepEvent) -> String {
		let start = event.start.formatted(date: .omitted, time: .shortened)
		if let end = event.end {
			return "\(start) → \(end.formatted(date: .omitted, time: .shortened))"
		}
		return "\(start) → Ongoing"
	}

	private func normalizedNote(_ note: String?) -> String? {
		guard let normalized = note?.trimmingCharacters(in: .whitespacesAndNewlines), !normalized.isEmpty else {
			return nil
		}
		return normalized
	}

	private func deleteWithCollapse(_ entry: InsightsHistoryEntry) {
		guard !removingEntryIDs.contains(entry.id), !pendingDeleteEntryIDs.contains(entry.id) else { return }
		withAnimation(.easeInOut(duration: 0.18)) {
			_ = removingEntryIDs.insert(entry.id)
		}
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
			displayedEntries.removeAll { $0.id == entry.id }
			_ = pendingDeleteEntryIDs.insert(entry.id)
			removingEntryIDs.remove(entry.id)
			if revealedDeleteID == entry.id {
				revealedDeleteID = nil
			}
			switch entry.source {
			case .sleep(let sleepID):
				onDeleteSleep(sleepID)
			case .zyn(let zynID):
				onDeleteZyn(zynID)
			case .custom(let habitID, _):
				onDeleteHabit(habitID)
			}
			syncDisplayedEntries()
		}
	}
}

private struct AttachedSwipeInsightsHistoryRow: View {
	private enum DragAxis {
		case undecided
		case horizontal
		case vertical
	}

	let entry: InsightsHistoryEntry
	let isRemoving: Bool
	@Binding var revealedDeleteID: String?
	let onDelete: () -> Void

	@State private var rowOffset: CGFloat = 0
	@State private var dragAxis: DragAxis = .undecided
	private let revealWidth: CGFloat = 92
	private let revealTrigger: CGFloat = 54
	private let minimumHorizontalStart: CGFloat = 16
	private let horizontalPriorityRatio: CGFloat = 1.5

	var body: some View {
		ZStack(alignment: .trailing) {
			Button(role: .destructive, action: onDelete) {
				ZStack {
					RoundedRectangle(cornerRadius: 14, style: .continuous)
						.fill(Color.red.opacity(0.88))
					Image(systemName: "trash.fill")
						.font(.system(size: 16, weight: .semibold))
						.foregroundStyle(.white)
				}
				.frame(width: revealWidth, height: 58)
			}
			.buttonStyle(.plain)
			.offset(x: revealWidth - revealedWidth)

			HStack(spacing: 12) {
				iconView
					.frame(width: 20, height: 20)

				VStack(alignment: .leading, spacing: 2) {
					Text(entry.title)
						.font(.system(size: 17, weight: .semibold))
						.foregroundStyle(.white)
						.lineLimit(1)

					if let subtitle = entry.subtitle {
						Text(subtitle)
							.font(.system(size: 13, weight: .medium))
							.foregroundStyle(Color.white.opacity(0.64))
							.lineLimit(1)
					}
				}

				Spacer()
				Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
					.font(.system(size: 15, weight: .medium))
					.foregroundStyle(Color.white.opacity(0.68))
					.monospacedDigit()
			}
			.padding(.horizontal, 12)
			.frame(height: 58)
			.background(
				RoundedRectangle(cornerRadius: 14, style: .continuous)
					.fill(Color(red: 0.15, green: 0.22, blue: 0.34).opacity(0.72))
			)
			.offset(x: rowOffset)
			.simultaneousGesture(rowDragGesture)
			.onTapGesture {
				if revealedDeleteID == entry.id {
					withAnimation(.easeOut(duration: 0.15)) {
						revealedDeleteID = nil
						rowOffset = 0
					}
				}
			}
		}
		.frame(height: 58)
		.clipped()
		.listRowInsets(EdgeInsets(top: isRemoving ? 0 : 6, leading: 12, bottom: isRemoving ? 0 : 6, trailing: 12))
		.listRowBackground(Color.clear)
		.listRowSeparator(.hidden)
		.opacity(isRemoving ? 0 : 1)
		.scaleEffect(y: isRemoving ? 0.96 : 1, anchor: .top)
		.frame(height: isRemoving ? 0 : 58)
		.clipped()
		.allowsHitTesting(!isRemoving)
		.animation(.easeInOut(duration: 0.18), value: isRemoving)
		.onChange(of: revealedDeleteID) { newValue in
			if newValue == entry.id {
				withAnimation(.easeOut(duration: 0.15)) {
					rowOffset = -revealWidth
				}
			} else {
				withAnimation(.easeOut(duration: 0.15)) {
					rowOffset = 0
				}
			}
		}
	}

	private var revealedWidth: CGFloat {
		max(0, min(revealWidth, -rowOffset))
	}

	@ViewBuilder
	private var iconView: some View {
		switch entry.source {
		case .sleep:
			Image(systemName: "bed.double.fill")
				.font(.system(size: 12, weight: .semibold))
				.foregroundStyle(Color.white.opacity(0.74))
		case .zyn:
			Image(systemName: "pills.fill")
				.font(.system(size: 12, weight: .semibold))
				.foregroundStyle(Color.white.opacity(0.74))
		case .custom(_, let tracker):
			TrackerGlyphIcon(
				tracker: tracker,
				size: 15,
				tint: Color.white.opacity(0.74)
			)
		}
	}

	private var rowDragGesture: some Gesture {
		DragGesture(minimumDistance: 16)
			.onChanged { value in
				let x = value.translation.width
				let y = value.translation.height

				if dragAxis == .undecided {
					let absX = abs(x)
					let absY = abs(y)
					if absX < minimumHorizontalStart && absY < minimumHorizontalStart {
						return
					}
					if x < 0, absX > absY * horizontalPriorityRatio {
						dragAxis = .horizontal
					} else if revealedDeleteID == entry.id, absX > absY * horizontalPriorityRatio {
						dragAxis = .horizontal
					} else {
						dragAxis = .vertical
						return
					}
				}

				guard dragAxis == .horizontal else { return }
				let translation = value.translation.width
				if revealedDeleteID == entry.id {
					rowOffset = max(-revealWidth, min(0, -revealWidth + translation))
				} else {
					rowOffset = max(-revealWidth, min(0, translation))
				}
			}
			.onEnded { _ in
				guard dragAxis == .horizontal else {
					dragAxis = .undecided
					return
				}

				let shouldReveal = rowOffset < -revealTrigger
				withAnimation(.easeOut(duration: 0.16)) {
					if shouldReveal {
						revealedDeleteID = entry.id
						rowOffset = -revealWidth
					} else {
						revealedDeleteID = nil
						rowOffset = 0
					}
				}
				dragAxis = .undecided
			}
	}
}

private enum InsightsChartRange: String, CaseIterable, Identifiable {
	case day = "D"
	case week = "W"
	case month = "M"
	case sixMonths = "6M"
	case year = "Y"

	var id: String { rawValue }
}

private struct InsightsChartBucket: Identifiable {
	let start: Date
	let value: Double
	let label: String

	var id: Date { start }
}

private struct InsightsChartBucketSet {
	let buckets: [InsightsChartBucket]
	let summaryValue: Double
	let summaryTitle: String
	let rangeLabel: String
}

private struct InsightsAxisTick: Identifiable {
	let id: Int
	let position: CGFloat
	let label: String
}

private struct InsightsGridLine: Identifiable {
	enum Style {
		case dashed
		case solid
	}

	let id: String
	let position: CGFloat
	let style: Style
}

private struct InsightsBucketLayer: Identifiable {
	let id: String
	let buckets: [InsightsChartBucket]
	let slotOffset: CGFloat
}

private struct InsightsGridLineLayer: Identifiable {
	let id: String
	let lines: [InsightsGridLine]
	let slotOffset: CGFloat
}

private struct InsightsTickLayer: Identifiable {
	let id: String
	let ticks: [InsightsAxisTick]
	let slotOffset: CGFloat
}

private struct InsightsSelectionMarker {
	let index: Int
	let value: Double
}

private struct InsightsStatCardSizePreferenceKey: PreferenceKey {
	static var defaultValue: CGSize = .zero

	static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
		let next = nextValue()
		if next.width > 0, next.height > 0 {
			value = next
		}
	}
}

private struct InsightsPlotWidthPreferenceKey: PreferenceKey {
	static var defaultValue: CGFloat = 0

	static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
		let next = nextValue()
		if next > 0 {
			value = next
		}
	}
}

private struct TopRoundedBar: Shape {
	let cornerRadius: CGFloat

	func path(in rect: CGRect) -> Path {
		let radius = min(cornerRadius, rect.width / 2, rect.height)
		var path = Path()
		path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
		path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
		path.addQuadCurve(
			to: CGPoint(x: rect.minX + radius, y: rect.minY),
			control: CGPoint(x: rect.minX, y: rect.minY)
		)
		path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
		path.addQuadCurve(
			to: CGPoint(x: rect.maxX, y: rect.minY + radius),
			control: CGPoint(x: rect.maxX, y: rect.minY)
		)
		path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
		path.closeSubpath()
		return path
	}
}

private struct InsightsChartPlotView: View {
	let leftBuckets: [InsightsChartBucket]?
	let leftGridLines: [InsightsGridLine]?
	let currentBuckets: [InsightsChartBucket]
	let currentGridLines: [InsightsGridLine]
	let rightBuckets: [InsightsChartBucket]?
	let rightGridLines: [InsightsGridLine]?
	let axisTop: Double
	let showMidYAxisLabel: Bool
	let topAxisLabel: String
	let midAxisLabel: String
	let isDayMode: Bool
	let barBaseColor: Color
	let slideTranslation: CGFloat

	var body: some View {
		GeometryReader { proxy in
			let plotHeight = proxy.size.height
			let yAxisWidth: CGFloat = 30
			let plotWidth = max(1, proxy.size.width - yAxisWidth)

			HStack(spacing: 0) {
				HStack(spacing: 0) {
					if let leftBuckets, let leftGridLines {
						plotPage(
							buckets: leftBuckets,
							gridLines: leftGridLines,
							plotWidth: plotWidth,
							plotHeight: plotHeight
						)
					} else {
						Color.clear.frame(width: plotWidth, height: plotHeight)
					}

					plotPage(
						buckets: currentBuckets,
						gridLines: currentGridLines,
						plotWidth: plotWidth,
						plotHeight: plotHeight
					)

					if let rightBuckets, let rightGridLines {
						plotPage(
							buckets: rightBuckets,
							gridLines: rightGridLines,
							plotWidth: plotWidth,
							plotHeight: plotHeight
						)
					} else {
						Color.clear.frame(width: plotWidth, height: plotHeight)
					}
				}
				.frame(width: plotWidth * 3, height: plotHeight, alignment: .leading)
				.offset(x: -plotWidth + slideTranslation)
				.frame(width: plotWidth, height: plotHeight, alignment: .leading)
				.clipped()
				.background(
					Color.clear
						.preference(key: InsightsPlotWidthPreferenceKey.self, value: plotWidth)
				)

				VStack(spacing: 0) {
					Text(topAxisLabel)
					Spacer()
					if showMidYAxisLabel {
						Text(midAxisLabel)
						Spacer()
					}
					Text("0")
				}
				.font(.system(size: 10, weight: .semibold))
				.foregroundStyle(Color.white.opacity(0.62))
				.monospacedDigit()
				.frame(width: yAxisWidth)
			}
		}
		.frame(height: 220)
	}

	@ViewBuilder
	private func plotPage(
		buckets: [InsightsChartBucket],
		gridLines: [InsightsGridLine],
		plotWidth: CGFloat,
		plotHeight: CGFloat
	) -> some View {
		ZStack(alignment: .bottomLeading) {
			Path { path in
				for line in 0...4 {
					let y = plotHeight * CGFloat(line) / 4
					path.move(to: CGPoint(x: 0, y: y))
					path.addLine(to: CGPoint(x: plotWidth, y: y))
				}
			}
			.stroke(Color.white.opacity(0.16), lineWidth: 1)

			Path { path in
				for line in gridLines where line.style == .dashed {
					let x = plotWidth * line.position
					path.move(to: CGPoint(x: x, y: 0))
					path.addLine(to: CGPoint(x: x, y: plotHeight))
				}
			}
			.stroke(
				Color.white.opacity(0.14),
				style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [2, 4])
			)

			Path { path in
				for line in gridLines where line.style == .solid {
					let x = plotWidth * line.position
					path.move(to: CGPoint(x: x, y: 0))
					path.addLine(to: CGPoint(x: x, y: plotHeight))
				}
			}
			.stroke(Color.white.opacity(0.18), lineWidth: 1)

			let slotCount = max(1, buckets.count)
			let cellWidth = plotWidth / CGFloat(slotCount)

			ForEach(buckets.indices, id: \.self) { index in
				let bucket = buckets[index]
				let height = barHeight(for: bucket.value, plotHeight: plotHeight)
				if height > 0 {
					TopRoundedBar(cornerRadius: 3)
						.fill(
							LinearGradient(
								colors: [
									barBaseColor.opacity(0.97),
									barBaseColor.opacity(0.74)
								],
								startPoint: .top,
								endPoint: .bottom
							)
						)
						.frame(width: barWidth(for: cellWidth), height: height)
						.position(
							x: cellWidth * (CGFloat(index) + 0.5),
							y: plotHeight - (height / 2)
						)
				}
			}
		}
		.frame(width: plotWidth, height: plotHeight, alignment: .bottomLeading)
	}

	private func barHeight(for value: Double, plotHeight: CGFloat) -> CGFloat {
		guard value > 0, axisTop > 0 else { return 0 }
		let normalized = value / axisTop
		return max(2, plotHeight * normalized)
	}

	private func barWidth(for cellWidth: CGFloat) -> CGFloat {
		if isDayMode {
			let scaled = cellWidth * 0.84
			return min(22, max(4, scaled))
		}
		let scaled = cellWidth * 0.55
		return min(20, max(2, scaled))
	}
}

private struct InsightsChartXAxisView: View {
	let tickLayers: [InsightsTickLayer]
	let trailingAxisWidth: CGFloat

	var body: some View {
		GeometryReader { proxy in
			let plotWidth = max(1, proxy.size.width - trailingAxisWidth)
			ZStack {
				ForEach(tickLayers) { layer in
					ForEach(layer.ticks) { tick in
						let rawX = plotWidth * (tick.position + layer.slotOffset)
						Text(tick.label)
							.font(.system(size: 10, weight: .semibold))
							.foregroundStyle(Color.white.opacity(0.62))
							.position(x: rawX, y: 6)
					}
				}
			}
			.frame(width: plotWidth, alignment: .leading)
			.clipped()
		}
		.frame(height: 12)
	}
}

private struct InsightsPage: View {
	let sleepEvents: [SleepEvent]
	let zynEvents: [ZynEvent]
	let habitEvents: [HabitEvent]
	let isZynTrackerActive: Bool
	let activeCustomTrackers: [TrackerKind]
	let showHistory: () -> Void
	let openManageTrackers: () -> Void

	@State private var selectedRange: InsightsChartRange = .week
	@State private var anchorDate: Date = Date()
	@State private var dayOffset: Int = 0
	@State private var weekDayOffset: Int = 0
	@State private var weekArrowAnimationToken: Int = 0
	@State private var weekArrowTargetOffset: Int? = nil
	@State private var isWeekArrowAnimating: Bool = false
	@State private var weekDragTranslation: CGFloat = 0
	@State private var selectedBucketStart: Date? = nil
	@State private var chartCardWidth: CGFloat = 0
	@State private var cachedTodayStart: Date = Calendar.current.startOfDay(for: Date())
	@State private var cachedFirstDataDayStart: Date = Calendar.current.startOfDay(for: Date())
	@State private var cachedLatestLogDayStart: Date = Calendar.current.startOfDay(for: Date())
	@State private var monthOffset: Int = 0
	@State private var sixMonthOffset: Int = 0
	@State private var yearOffset: Int = 0
	@State private var sleepWeekPageOffset: Int = 0
	@State private var sleepWeekArrowAnimationToken: Int = 0
	@State private var sleepWeekArrowTargetOffset: Int? = nil
	@State private var isSleepWeekArrowAnimating: Bool = false
	@State private var sleepWeekDragTranslation: CGFloat = 0
	@State private var sleepPlotWidth: CGFloat = 0
	@State private var chartPlotWidth: CGFloat = 0
	@State private var selectedStatCardSize: CGSize = .zero
	@State private var didHandleChartTap: Bool = false
	@State private var selectedTrackerID: String = ""

	private var calendar: Calendar { Calendar.current }
	private var sundayCalendar: Calendar {
		var value = Calendar.current
		value.firstWeekday = 1
		value.minimumDaysInFirstWeek = 1
		return value
	}

	private var isoCalendar: Calendar {
		var value = Calendar.current
		value.firstWeekday = 2
		value.minimumDaysInFirstWeek = 4
		return value
	}

	private var selectableRanges: [InsightsChartRange] {
		[.day, .week, .month, .year]
	}

	private var hasZynHistory: Bool {
		!zynEvents.isEmpty
	}

	private var loggedCustomTrackers: [TrackerKind] {
		let filteredEvents = habitEvents.filter { !$0.tracker.isBuiltInDisabled && !$0.tracker.isRetiredFromUI }
		let latestByTracker = Dictionary(grouping: filteredEvents, by: \.tracker).compactMapValues { events in
			events.map(\.timestamp).max()
		}
		var ordered = activeCustomTrackers
			.reversed()
			.filter { latestByTracker[$0] != nil && !$0.isRetiredFromUI }
		let orderedSet = Set(ordered)
		let remaining = latestByTracker.keys
			.filter { !orderedSet.contains($0) }
			.sorted { (latestByTracker[$0] ?? .distantPast) > (latestByTracker[$1] ?? .distantPast) }
		ordered.append(contentsOf: remaining)
		return ordered
	}

	private var availableChartTrackers: [InsightsTrackerSelection] {
		var trackers: [InsightsTrackerSelection] = []
		if hasZynHistory {
			trackers.append(.zyn)
		}
		trackers.append(contentsOf: loggedCustomTrackers.map(InsightsTrackerSelection.custom))
		return trackers
	}

	private var selectedChartTracker: InsightsTrackerSelection? {
		availableChartTrackers.first(where: { $0.id == selectedTrackerID }) ?? availableChartTrackers.first
	}

	private var selectedChartBarColor: Color {
		guard let tracker = selectedChartTracker else {
			return Color(red: 0.33, green: 0.68, blue: 1.0)
		}
		switch tracker {
		case .zyn:
			return Color(red: 0.33, green: 0.68, blue: 1.0)
		case .custom(let customTracker):
			return trackerAccentColor(customTracker)
		}
	}

	private func selectedChartUnitLabel(for quantity: Double) -> String {
		guard let tracker = selectedChartTracker else { return "Logs" }
		let isSingular = abs(quantity - 1.0) < 0.0001
		switch tracker {
		case .zyn:
			return isSingular ? "ZYN" : "ZYN's"
		case .custom(let customTracker):
			if customTracker == .cannabis {
				return "Cannabis"
			}
			return isSingular ? customTracker.displayName : "\(customTracker.displayName)'s"
		}
	}

	private var chartEventTimestamps: [Date] {
		guard let tracker = selectedChartTracker else { return [] }
		switch tracker {
		case .zyn:
			return zynEvents.map(\.timestamp)
		case .custom(let customTracker):
			return habitEvents
				.filter { $0.tracker == customTracker }
				.map(\.timestamp)
		}
	}

	var body: some View {
		ScrollView(showsIndicators: false) {
			VStack(spacing: 16) {
				Text("Insights")
					.frame(maxWidth: .infinity, alignment: .center)
					.font(.system(size: 34, weight: .semibold))
					.foregroundStyle(Color.white.opacity(0.96))
					.padding(.top, 0)
					.offset(y: 6)

				if availableChartTrackers.isEmpty {
					VStack(spacing: 10) {
						Text("No tracker charts yet")
							.font(.system(size: 18, weight: .semibold))
							.foregroundStyle(Color.white.opacity(0.86))
						Text("Add trackers from the Add page to show charts here.")
							.font(.system(size: 13, weight: .medium))
							.foregroundStyle(Color.white.opacity(0.62))
					}
					.frame(maxWidth: .infinity)
					.padding(.vertical, 22)
					.background(
						RoundedRectangle(cornerRadius: 24, style: .continuous)
							.fill(Color.white.opacity(0.07))
							.overlay(
								RoundedRectangle(cornerRadius: 24, style: .continuous)
									.stroke(Color.white.opacity(0.12), lineWidth: 1)
							)
					)
				} else {
					trackerSelector
					rangeSelector
					periodNavigator

					VStack(alignment: .leading, spacing: 4) {
						Text(bucketSet.summaryTitle)
							.font(.system(size: 12, weight: .semibold))
							.foregroundStyle(Color.white.opacity(0.66))

							HStack(alignment: .firstTextBaseline, spacing: 4) {
								Text(summaryValueLabel)
									.font(.system(size: 44, weight: .bold))
									.foregroundStyle(.white)
									.monospacedDigit()
								Text(selectedChartUnitLabel(for: bucketSet.summaryValue))
									.font(.system(size: 24, weight: .semibold))
									.foregroundStyle(Color.white.opacity(0.86))
							}

						Text(bucketSet.rangeLabel)
							.font(.system(size: 15, weight: .medium))
							.foregroundStyle(Color.white.opacity(0.70))
					}
					.frame(maxWidth: .infinity, alignment: .leading)

					chartCard
				}

				Button(action: showHistory) {
					Text("View Full History")
						.font(.system(size: 17, weight: .semibold, design: .rounded))
						.foregroundStyle(.white)
						.padding(.horizontal, 22)
						.padding(.vertical, 13)
						.background(
							Capsule()
								.fill(Color.blue.opacity(0.58))
								.overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1))
						)
				}
				.buttonStyle(.plain)

				sleepRhythmCard
			}
			.padding(.horizontal, 24)
			.padding(.top, 34)
			.padding(.bottom, 24)
		}
		.simultaneousGesture(
			TapGesture()
				.onEnded {
					if didHandleChartTap {
						didHandleChartTap = false
						return
					}
					if selectedBucketStart != nil {
						clearSelectedBucket(animated: true)
					}
				}
		)
		.onChange(of: selectedRange) { newRange in
			guard newRange != .sixMonths else {
				selectedRange = .month
				return
			}
			weekArrowAnimationToken += 1
			weekArrowTargetOffset = nil
			isWeekArrowAnimating = false
			weekDragTranslation = 0
			clearSelectedBucket(animated: false)
			resetTopRangeToCurrent(for: newRange)
			clampOffsets()
		}
		.onChange(of: zynEvents.count) { _ in
			refreshTodayStart()
			recomputeDataBounds()
			weekArrowAnimationToken += 1
			weekArrowTargetOffset = nil
			isWeekArrowAnimating = false
			weekDragTranslation = 0
			sleepWeekArrowAnimationToken += 1
			sleepWeekArrowTargetOffset = nil
			isSleepWeekArrowAnimating = false
			sleepWeekDragTranslation = 0
			clearSelectedBucket(animated: false)
			clampOffsets()
			clampSleepWeekPageOffset()
			syncSelectedRangeToAnchor()
		}
		.onChange(of: selectedTrackerID) { _ in
			clearSelectedBucket(animated: false)
			refreshTodayStart()
			recomputeDataBounds()
			resetTopRangeToCurrent(for: selectedRange)
			clampOffsets()
		}
		.onChange(of: sleepEvents.count) { _ in
			weekArrowAnimationToken += 1
			weekArrowTargetOffset = nil
			isWeekArrowAnimating = false
			sleepWeekArrowAnimationToken += 1
			sleepWeekArrowTargetOffset = nil
			isSleepWeekArrowAnimating = false
			sleepWeekDragTranslation = 0
			clampSleepWeekPageOffset()
		}
		.onChange(of: habitEvents.count) { _ in
			refreshTodayStart()
			recomputeDataBounds()
			weekArrowAnimationToken += 1
			weekArrowTargetOffset = nil
			isWeekArrowAnimating = false
			weekDragTranslation = 0
			clearSelectedBucket(animated: false)
			clampOffsets()
			syncSelectedRangeToAnchor()
			sleepWeekArrowAnimationToken += 1
			sleepWeekArrowTargetOffset = nil
			isSleepWeekArrowAnimating = false
			sleepWeekDragTranslation = 0
			clampSleepWeekPageOffset()
		}
		.onChange(of: activeCustomTrackers) { _ in
			syncSelectedChartTracker()
			refreshTodayStart()
			recomputeDataBounds()
			resetTopRangeToCurrent(for: selectedRange)
			clampOffsets()
			clampSleepWeekPageOffset()
		}
		.onChange(of: isZynTrackerActive) { _ in
			syncSelectedChartTracker()
			refreshTodayStart()
			recomputeDataBounds()
			resetTopRangeToCurrent(for: selectedRange)
			clampOffsets()
		}
		.onAppear {
			if selectedRange == .sixMonths {
				selectedRange = .month
			}
			syncSelectedChartTracker()
			refreshTodayStart()
			recomputeDataBounds()
			weekArrowAnimationToken += 1
			weekArrowTargetOffset = nil
			isWeekArrowAnimating = false
			weekDragTranslation = 0
			sleepWeekArrowAnimationToken += 1
			sleepWeekArrowTargetOffset = nil
			isSleepWeekArrowAnimating = false
			sleepWeekDragTranslation = 0
			clampSleepWeekPageOffset()
			clearSelectedBucket(animated: false)
			resetTopRangeToCurrent(for: selectedRange)
			clampOffsets()
		}
	}

	private var periodNavigator: some View {
		HStack {
			Button {
				shiftCurrentRange(older: true)
			} label: {
				Image(systemName: "chevron.left")
					.font(.system(size: 13, weight: .bold))
					.frame(width: 30, height: 30)
					.background(Circle().fill(Color.white.opacity(0.10)))
			}
			.buttonStyle(.plain)
			.disabled(currentOffset >= maxOffset || isWeekArrowAnimating)
			.opacity((currentOffset >= maxOffset || isWeekArrowAnimating) ? 0.45 : 1)

			Text(periodLabel)
				.font(.system(size: 14, weight: .semibold))
				.foregroundStyle(Color.white.opacity(0.88))
				.monospacedDigit()
				.frame(maxWidth: .infinity)

			Button {
				shiftCurrentRange(older: false)
			} label: {
				Image(systemName: "chevron.right")
					.font(.system(size: 13, weight: .bold))
					.frame(width: 30, height: 30)
					.background(Circle().fill(Color.white.opacity(0.10)))
			}
			.buttonStyle(.plain)
			.disabled(currentOffset == 0 || isWeekArrowAnimating)
			.opacity((currentOffset == 0 || isWeekArrowAnimating) ? 0.45 : 1)
		}
	}

	private var trackerSelector: some View {
		ScrollView(.horizontal, showsIndicators: false) {
			HStack(spacing: 8) {
				ForEach(availableChartTrackers) { tracker in
					let isSelected = tracker.id == (selectedChartTracker?.id ?? "")
					let foreground = isSelected ? Color.white : Color.white.opacity(0.72)
					Button {
						guard selectedTrackerID != tracker.id else { return }
						withAnimation(.easeOut(duration: 0.2)) {
							selectedTrackerID = tracker.id
						}
					} label: {
						HStack(spacing: 6) {
							switch tracker {
							case .zyn:
								Image(systemName: "pills.fill")
									.font(.system(size: 12, weight: .semibold))
									.foregroundStyle(foreground)
							case .custom(let customTracker):
								TrackerGlyphIcon(
									tracker: customTracker,
									size: 13,
									tint: foreground
								)
							}

							Text(tracker.title)
								.font(.system(size: 13, weight: .semibold))
								.foregroundStyle(foreground)
						}
							.padding(.horizontal, 12)
							.padding(.vertical, 7)
							.background(
								Capsule()
									.fill(isSelected ? Color(red: 0.34, green: 0.51, blue: 0.76).opacity(0.95) : Color.white.opacity(0.10))
									.overlay(
										Capsule()
											.stroke(Color.white.opacity(isSelected ? 0.34 : 0.16), lineWidth: 1)
									)
							)
					}
					.buttonStyle(.plain)
					.contentShape(Rectangle())
					.padding(.vertical, 2)
				}
			}
			.padding(.horizontal, 2)
			.padding(.vertical, 2)
		}
		.contentShape(Rectangle())
	}

	private var rangeSelector: some View {
		HStack(spacing: 0) {
			ForEach(selectableRanges) { range in
				Button {
					guard !isWeekArrowAnimating else { return }
					withAnimation(.easeOut(duration: 0.18)) {
						selectedRange = range
					}
				} label: {
					Text(range.rawValue)
						.font(.system(size: 14, weight: .bold))
						.foregroundStyle(selectedRange == range ? Color.white : Color.white.opacity(0.66))
						.frame(maxWidth: .infinity)
						.padding(.vertical, 6)
						.background(
							Capsule()
								.fill(selectedRange == range ? Color(red: 0.34, green: 0.51, blue: 0.76).opacity(0.95) : Color.clear)
						)
				}
				.buttonStyle(.plain)
			}
		}
		.padding(3)
		.background(
			Capsule()
				.fill(Color.white.opacity(0.10))
				.overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1))
		)
		.overlay {
			GeometryReader { proxy in
				let hitHeight = proxy.size.height + 16
				Color.clear
					.contentShape(Rectangle())
					.frame(width: proxy.size.width, height: hitHeight)
					.position(x: proxy.size.width / 2, y: proxy.size.height / 2)
					.gesture(
						DragGesture(minimumDistance: 0)
							.onEnded { value in
								guard !isWeekArrowAnimating else { return }
								guard abs(value.translation.width) < 12, abs(value.translation.height) < 12 else { return }
								let clampedX = min(max(0, value.location.x), max(0, proxy.size.width - 0.001))
								let count = max(1, selectableRanges.count)
								let segmentWidth = proxy.size.width / CGFloat(count)
								let rawIndex = Int(floor(clampedX / max(1, segmentWidth)))
								let index = min(selectableRanges.count - 1, max(0, rawIndex))
								let target = selectableRanges[index]
								guard selectedRange != target else { return }
								withAnimation(.easeOut(duration: 0.18)) {
									selectedRange = target
								}
							}
					)
			}
		}
	}

	private var addTrackerRow: some View {
		Button(action: openManageTrackers) {
			HStack(spacing: 8) {
				Spacer()
				Image(systemName: "plus.circle.fill")
					.font(.system(size: 16, weight: .semibold))
				Text("Add Tracker")
					.font(.system(size: 15, weight: .semibold))
				Spacer()
			}
			.foregroundStyle(Color.white.opacity(0.92))
			.padding(.vertical, 12)
			.background(
				RoundedRectangle(cornerRadius: 16, style: .continuous)
					.fill(Color.white.opacity(0.08))
					.overlay(
						RoundedRectangle(cornerRadius: 16, style: .continuous)
							.stroke(Color.white.opacity(0.14), lineWidth: 1)
					)
			)
		}
		.buttonStyle(.plain)
	}

	private var chartCard: some View {
		let currentRange = selectedRange
		let currentRangeOffset = currentOffset
		let rangeStep = stepSize(for: currentRange)
		let rangeMaxOffset = maxOffset(for: currentRange)
		let currentBucketSet = bucketSet(for: currentRange, offset: currentRangeOffset)
		let buckets = currentBucketSet.buckets
		let gridLines = axisGridLines(for: currentRange, buckets: buckets)
		let olderOffset = min(rangeMaxOffset, currentRangeOffset + rangeStep)
		let newerOffset = max(0, currentRangeOffset - rangeStep)
		let olderBucketSet = olderOffset == currentRangeOffset ? nil : bucketSet(for: currentRange, offset: olderOffset)
		let newerBucketSet = newerOffset == currentRangeOffset ? nil : bucketSet(for: currentRange, offset: newerOffset)
		let olderGridLines = olderBucketSet.map { axisGridLines(for: currentRange, buckets: $0.buckets) }
		let newerGridLines = newerBucketSet.map { axisGridLines(for: currentRange, buckets: $0.buckets) }
		let ticks = axisTicks(for: currentRange, buckets: buckets)
		let axisTop = yAxisTopValue
		let topLabel = axisLabel(axisTop)
		let midLabel = axisLabel(axisTop / 2)
		let visibleSlots = max(1, buckets.count)
		let selectedBucketIndex: Int?

		let tickLayers: [InsightsTickLayer] = [
			InsightsTickLayer(id: "current-ticks", ticks: ticks, slotOffset: 0)
		]

		if let selected = selectedBucket,
		   let index = buckets.firstIndex(where: { $0.start == selected.start }) {
			selectedBucketIndex = index
		} else {
			selectedBucketIndex = nil
		}

		return VStack(spacing: 10) {
			InsightsChartPlotView(
				leftBuckets: olderBucketSet?.buckets,
				leftGridLines: olderGridLines,
				currentBuckets: buckets,
				currentGridLines: gridLines,
				rightBuckets: newerBucketSet?.buckets,
				rightGridLines: newerGridLines,
				axisTop: axisTop,
				showMidYAxisLabel: showMidYAxisLabel,
				topAxisLabel: topLabel,
				midAxisLabel: midLabel,
				isDayMode: selectedRange == .day,
				barBaseColor: selectedChartBarColor,
				slideTranslation: weekDragTranslation
			)
			.onPreferenceChange(InsightsPlotWidthPreferenceKey.self) { width in
				if width > 0 {
					chartPlotWidth = width
				}
			}

			InsightsChartXAxisView(
				tickLayers: tickLayers,
				trailingAxisWidth: 30
			)
		}
		.padding(.horizontal, 14)
		.padding(.top, 14)
		.padding(.bottom, 12)
		.background(
			RoundedRectangle(cornerRadius: 24, style: .continuous)
				.fill(Color.white.opacity(0.07))
				.overlay(
					RoundedRectangle(cornerRadius: 24, style: .continuous)
						.stroke(Color.white.opacity(0.12), lineWidth: 1)
				)
		)
		.background(
			GeometryReader { proxy in
				Color.clear
					.onAppear {
						chartCardWidth = proxy.size.width
					}
					.onChange(of: proxy.size.width) { width in
						chartCardWidth = width
					}
			}
			)
			.contentShape(Rectangle())
			.simultaneousGesture(chartTapGesture, including: .all)
			.overlay(alignment: .topLeading) {
				if let selected = selectedBucket, let selectedIndex = selectedBucketIndex {
					GeometryReader { proxy in
						let plotWidth = max(1, proxy.size.width - 58)
						let slotCount = CGFloat(max(1, visibleSlots))
						let cellWidth = plotWidth / slotCount
						let x = 14 + cellWidth * (CGFloat(selectedIndex) + 0.5)
						let halfWidth = max(0, selectedStatCardSize.width / 2)
							let minCardX = halfWidth + 4
							let maxCardX = proxy.size.width - halfWidth - 4
							let clampedX = halfWidth > 0 ? min(max(x, minCardX), maxCardX) : x
							let bubbleOffsetX = clampedX - x
							let barHeight = selectionLineBarHeight(for: selected.value, axisTop: axisTop)
							let bubbleCenterY = selectedStatCardSize.height > 0 ? (-(selectedStatCardSize.height / 2) - 12) : -48
							let bubbleBottomY = bubbleCenterY + (selectedStatCardSize.height / 2)
							let plotTopY: CGFloat = 14
							let barTopY = plotTopY + (220 - barHeight)

						if barHeight > 0, selectedStatCardSize.height > 0 {
							Path { path in
								path.move(to: CGPoint(x: x, y: bubbleBottomY))
								path.addLine(to: CGPoint(x: x, y: barTopY))
							}
							.stroke(Color.white.opacity(0.74), lineWidth: 1.4)
						}

						VStack(spacing: 0) {
							VStack(alignment: .leading, spacing: 1) {
							Text("TOTAL")
								.font(.system(size: 10, weight: .semibold))
								.foregroundStyle(Color.white.opacity(0.70))

								HStack(alignment: .firstTextBaseline, spacing: 3) {
									Text("\(selectedBucketTotalCount(for: selected))")
										.font(.system(size: 24, weight: .bold))
										.foregroundStyle(.white)
										.monospacedDigit()
									Text(selectedChartUnitLabel(for: Double(selectedBucketTotalCount(for: selected))))
										.font(.system(size: 13, weight: .semibold))
										.foregroundStyle(Color.white.opacity(0.86))
								}

							Text(selectedBucketLabel(for: selected))
								.font(.system(size: 11, weight: .medium))
								.foregroundStyle(Color.white.opacity(0.72))
						}
						.padding(.horizontal, 10)
						.padding(.vertical, 7)
						.background(
							RoundedRectangle(cornerRadius: 11, style: .continuous)
								.fill(Color(red: 0.13, green: 0.20, blue: 0.32).opacity(0.95))
								.overlay(
									RoundedRectangle(cornerRadius: 11, style: .continuous)
										.stroke(Color.white.opacity(0.22), lineWidth: 1)
								)
							)
							.offset(x: bubbleOffsetX)
							.background(
								GeometryReader { bubbleProxy in
									Color.clear
										.preference(key: InsightsStatCardSizePreferenceKey.self, value: bubbleProxy.size)
								}
							)

							}
							.position(x: x, y: bubbleCenterY)
							.allowsHitTesting(false)
						}
					}
				}
			.onPreferenceChange(InsightsStatCardSizePreferenceKey.self) { size in
				if size.width > 0, size.height > 0 {
					selectedStatCardSize = size
				}
			}
		}

	private var sleepRhythmCard: some View {
		let days = sleepRhythmDays(for: sleepWeekPageOffset)
		let sleepBlockColor = Color(red: 0.72, green: 0.63, blue: 0.96).opacity(0.9)
		let zynMarkerColor = Color(red: 0.33, green: 0.68, blue: 1.0).opacity(0.98)
		let markerTrackers = activeMarkerTrackers
		let viewportHeight = UIScreen.main.bounds.height
		let sleepPlotHeight: CGFloat = max(340, min(520, viewportHeight * 0.58))
		let usageMarkerHeight: CGFloat = 1.6
		let legendUsageMarkerHeight: CGFloat = 1.0
		let yTicks: [(label: String, fraction: CGFloat)] = [
			("00:00", 0.0),
			("06:00", 0.25),
			("12:00", 0.5),
			("18:00", 0.75),
			("23:59", 1.0)
		]

		return VStack(alignment: .leading, spacing: 10) {
			HStack(alignment: .firstTextBaseline, spacing: 10) {
				Text("Sleep Routine")
					.font(.system(size: 22, weight: .semibold))
					.foregroundStyle(.white)
				Spacer(minLength: 8)
				Button {
					shiftSleepRhythmWeek(older: true)
				} label: {
					Image(systemName: "chevron.left")
						.font(.system(size: 12, weight: .bold))
						.frame(width: 26, height: 26)
						.background(Circle().fill(Color.white.opacity(0.10)))
				}
				.buttonStyle(.plain)
				.disabled(sleepWeekPageOffset >= maxPastSleepWeekOffset || isSleepWeekArrowAnimating)
				.opacity((sleepWeekPageOffset >= maxPastSleepWeekOffset || isSleepWeekArrowAnimating) ? 0.45 : 1)

				Text(sleepRhythmPeriodLabel)
					.font(.system(size: 12, weight: .semibold))
					.foregroundStyle(Color.white.opacity(0.78))
					.monospacedDigit()

				Button {
					shiftSleepRhythmWeek(older: false)
				} label: {
					Image(systemName: "chevron.right")
						.font(.system(size: 12, weight: .bold))
						.frame(width: 26, height: 26)
						.background(Circle().fill(Color.white.opacity(0.10)))
				}
				.buttonStyle(.plain)
				.disabled(sleepWeekPageOffset == 0 || isSleepWeekArrowAnimating)
				.opacity((sleepWeekPageOffset == 0 || isSleepWeekArrowAnimating) ? 0.45 : 1)
			}

			Text("Sleep blocks with usage markers")
				.font(.system(size: 12, weight: .medium))
				.foregroundStyle(Color.white.opacity(0.62))

			HStack(spacing: 0) {
				Spacer()
					.frame(width: 44)
				ForEach(days.indices, id: \.self) { index in
					Text(days[index].formatted(.dateTime.day()))
						.font(.system(size: 12, weight: .semibold))
						.foregroundStyle(Color.white.opacity(0.66))
						.frame(maxWidth: .infinity)
				}
			}

				GeometryReader { proxy in
					let labelWidth: CGFloat = 44
					let plotWidth = max(1, proxy.size.width - labelWidth)
					let gap: CGFloat = 6
					let columnWidth = max(4, (plotWidth - gap * 6) / 7)
					let plotHeight = proxy.size.height
					let olderOffset = min(maxPastSleepWeekOffset, sleepWeekPageOffset + 1)
					let newerOffset = max(0, sleepWeekPageOffset - 1)
					let olderDays = olderOffset == sleepWeekPageOffset ? nil : sleepRhythmDays(for: olderOffset)
					let newerDays = newerOffset == sleepWeekPageOffset ? nil : sleepRhythmDays(for: newerOffset)

					HStack(spacing: 0) {
						ZStack(alignment: .topLeading) {
							ForEach(yTicks.indices, id: \.self) { index in
								let tick = yTicks[index]
								Text(tick.label)
									.font(.system(size: 11, weight: .medium))
									.foregroundStyle(Color.white.opacity(0.58))
									.position(x: labelWidth / 2, y: max(8, min(plotHeight - 8, plotHeight * tick.fraction)))
							}
						}
						.frame(width: labelWidth, height: plotHeight)

						HStack(spacing: 0) {
							if let olderDays {
								sleepRhythmPlotPage(
									days: olderDays,
									plotWidth: plotWidth,
									plotHeight: plotHeight,
									gap: gap,
								columnWidth: columnWidth,
								sleepBlockColor: sleepBlockColor,
								zynMarkerColor: zynMarkerColor,
								activeTrackers: markerTrackers,
								usageMarkerHeight: usageMarkerHeight
							)
						} else {
							Color.clear.frame(width: plotWidth, height: plotHeight)
						}

							sleepRhythmPlotPage(
								days: days,
								plotWidth: plotWidth,
								plotHeight: plotHeight,
								gap: gap,
								columnWidth: columnWidth,
								sleepBlockColor: sleepBlockColor,
								zynMarkerColor: zynMarkerColor,
								activeTrackers: markerTrackers,
								usageMarkerHeight: usageMarkerHeight
							)

							if let newerDays {
								sleepRhythmPlotPage(
									days: newerDays,
									plotWidth: plotWidth,
									plotHeight: plotHeight,
									gap: gap,
									columnWidth: columnWidth,
									sleepBlockColor: sleepBlockColor,
									zynMarkerColor: zynMarkerColor,
									activeTrackers: markerTrackers,
									usageMarkerHeight: usageMarkerHeight
								)
							} else {
								Color.clear.frame(width: plotWidth, height: plotHeight)
							}
						}
						.frame(width: plotWidth * 3, height: plotHeight, alignment: .leading)
						.offset(x: -plotWidth + sleepWeekDragTranslation)
						.frame(width: plotWidth, height: plotHeight, alignment: .leading)
						.clipped()
					}
					.onAppear {
						sleepPlotWidth = plotWidth
					}
					.onChange(of: plotWidth) { width in
						sleepPlotWidth = width
					}
				}
				.frame(height: sleepPlotHeight)

			ScrollView(.horizontal, showsIndicators: false) {
				HStack(spacing: 14) {
					HStack(spacing: 6) {
						Circle()
							.fill(sleepBlockColor)
							.frame(width: 8, height: 8)
						Text("Sleep")
							.font(.system(size: 11, weight: .semibold))
							.foregroundStyle(Color.white.opacity(0.68))
					}

					if hasZynHistory {
						HStack(spacing: 6) {
							Rectangle()
								.fill(zynMarkerColor)
								.frame(width: 12, height: legendUsageMarkerHeight)
							Image(systemName: "pills.fill")
								.font(.system(size: 10, weight: .semibold))
								.foregroundStyle(Color.white.opacity(0.68))
							Text("ZYN")
								.font(.system(size: 11, weight: .semibold))
								.foregroundStyle(Color.white.opacity(0.68))
						}
					}

					ForEach(markerTrackers) { tracker in
						HStack(spacing: 6) {
							Rectangle()
								.fill(markerColor(for: tracker))
								.frame(width: 12, height: legendUsageMarkerHeight)
							TrackerGlyphIcon(
								tracker: tracker,
								size: 10,
								tint: Color.white.opacity(0.68)
							)
							Text(tracker.displayName)
								.font(.system(size: 11, weight: .semibold))
								.foregroundStyle(Color.white.opacity(0.68))
						}
					}
				}
				.padding(.vertical, 3)
			}
			.contentShape(Rectangle())
		}
		.padding(.horizontal, 14)
		.padding(.top, 14)
		.padding(.bottom, 12)
		.background(
			RoundedRectangle(cornerRadius: 24, style: .continuous)
				.fill(Color.white.opacity(0.07))
				.overlay(
					RoundedRectangle(cornerRadius: 24, style: .continuous)
						.stroke(Color.white.opacity(0.12), lineWidth: 1)
				)
		)
	}

	@ViewBuilder
	private func sleepRhythmPlotPage(
		days: [Date],
		plotWidth: CGFloat,
		plotHeight: CGFloat,
		gap: CGFloat,
		columnWidth: CGFloat,
		sleepBlockColor: Color,
		zynMarkerColor: Color,
		activeTrackers: [TrackerKind],
		usageMarkerHeight: CGFloat
	) -> some View {
		ZStack(alignment: .topLeading) {
			Path { path in
				for line in 0...12 {
					let y = plotHeight * CGFloat(line) / 12
					path.move(to: CGPoint(x: 0, y: y))
					path.addLine(to: CGPoint(x: plotWidth, y: y))
				}
			}
			.stroke(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [2, 4]))

			HStack(alignment: .top, spacing: gap) {
				ForEach(days.indices, id: \.self) { index in
					let dayStart = days[index]
					let sleepBlocks = sleepFractions(for: dayStart)
					let markers = markerFractions(
						for: dayStart,
						activeTrackers: activeTrackers,
						zynColor: zynMarkerColor
					)
					let markerPlacements = stackedMarkerPlacements(
						markers: markers,
						plotHeight: plotHeight,
						preferredHeight: usageMarkerHeight
					)

					ZStack(alignment: .top) {
						RoundedRectangle(cornerRadius: 4, style: .continuous)
							.fill(Color.white.opacity(0.05))

						ForEach(sleepBlocks.indices, id: \.self) { blockIndex in
							let block = sleepBlocks[blockIndex]
							Rectangle()
								.fill(sleepBlockColor)
								.frame(width: columnWidth - 4, height: max(2, (block.end - block.start) * plotHeight))
								.position(
									x: columnWidth / 2,
									y: ((block.start + block.end) / 2) * plotHeight
								)
						}

						ForEach(markerPlacements.indices, id: \.self) { markIndex in
							Capsule()
								.fill(markerPlacements[markIndex].color)
								.frame(width: columnWidth - 4, height: markerPlacements[markIndex].height)
								.overlay(
									Capsule()
										.stroke(Color.white.opacity(0.45), lineWidth: 0.5)
								)
								.shadow(color: markerPlacements[markIndex].color.opacity(0.62), radius: 1.8)
								.position(x: columnWidth / 2, y: markerPlacements[markIndex].y)
						}
					}
					.frame(width: columnWidth, height: plotHeight)
				}
			}
			.frame(width: plotWidth, height: plotHeight, alignment: .topLeading)
		}
	}

	private func sleepRhythmDays(for pageOffset: Int) -> [Date] {
		(0..<7).compactMap { value in
			calendar.date(byAdding: .day, value: value, to: selectedSleepWeekStart(for: pageOffset))
		}
	}

	private func sleepFractions(for dayStart: Date) -> [(start: CGFloat, end: CGFloat)] {
		guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
		var segments: [(start: CGFloat, end: CGFloat)] = []
		for event in sleepEvents {
			let eventEnd = event.end ?? Date()
			guard eventEnd > event.start else { continue }
			let clampedStart = max(event.start, dayStart)
			let clampedEnd = min(eventEnd, dayEnd)
			guard clampedEnd > clampedStart else { continue }
			let startFraction = max(0, min(1, CGFloat(clampedStart.timeIntervalSince(dayStart) / 86_400)))
			let endFraction = max(0, min(1, CGFloat(clampedEnd.timeIntervalSince(dayStart) / 86_400)))
			segments.append((start: startFraction, end: endFraction))
		}
		return segments
	}

	private var activeMarkerTrackers: [TrackerKind] {
		loggedCustomTrackers
	}

	private func markerColor(for tracker: TrackerKind) -> Color {
		trackerAccentColor(tracker).opacity(0.98)
	}

	private func markerFractions(
		for dayStart: Date,
		activeTrackers: [TrackerKind],
		zynColor: Color
	) -> [(fraction: CGFloat, color: Color)] {
		guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
		var markers: [(fraction: CGFloat, color: Color)] = []

		for event in zynEvents where event.timestamp >= dayStart && event.timestamp < dayEnd {
			let fraction = max(0, min(1, CGFloat(event.timestamp.timeIntervalSince(dayStart) / 86_400)))
			markers.append((fraction: fraction, color: zynColor))
		}

		let activeSet = Set(activeTrackers)
		for event in habitEvents where activeSet.contains(event.tracker) && event.timestamp >= dayStart && event.timestamp < dayEnd {
			let fraction = max(0, min(1, CGFloat(event.timestamp.timeIntervalSince(dayStart) / 86_400)))
			markers.append((fraction: fraction, color: markerColor(for: event.tracker)))
		}

		return markers.sorted(by: { $0.fraction < $1.fraction })
	}

	private func stackedMarkerPlacements(
		markers: [(fraction: CGFloat, color: Color)],
		plotHeight: CGFloat,
		preferredHeight: CGFloat
	) -> [(y: CGFloat, color: Color, height: CGFloat)] {
		guard !markers.isEmpty else { return [] }
		let maxPerMarker = plotHeight / CGFloat(markers.count)
		let markerHeight = min(preferredHeight, max(0.3, maxPerMarker - 0.1))
		let minGap = markerHeight
		let half = markerHeight / 2
		let lowerBound = half
		let upperBound = max(half, plotHeight - half)
		var positions = markers.map { marker in
			max(lowerBound, min(upperBound, marker.fraction * plotHeight))
		}

		if positions.count > 1 {
			for index in 1..<positions.count {
				positions[index] = max(positions[index], positions[index - 1] + minGap)
			}

			if let last = positions.last, last > upperBound {
				let shift = last - upperBound
				for index in positions.indices {
					positions[index] -= shift
				}
			}

			for index in stride(from: positions.count - 2, through: 0, by: -1) {
				positions[index] = min(positions[index], positions[index + 1] - minGap)
			}

			if positions[0] < lowerBound {
				let shift = lowerBound - positions[0]
				for index in positions.indices {
					positions[index] += shift
				}
			}
		}

		return markers.enumerated().map { index, marker in
			(y: positions[index], color: marker.color, height: markerHeight)
		}
	}

	private var currentSleepWeekStart: Date {
		sundayCalendar.dateInterval(of: .weekOfYear, for: todayStart)?.start ?? todayStart
	}

	private func selectedSleepWeekStart(for pageOffset: Int) -> Date {
		calendar.date(byAdding: .weekOfYear, value: -pageOffset, to: currentSleepWeekStart) ?? currentSleepWeekStart
	}

	private var selectedSleepWeekStart: Date {
		selectedSleepWeekStart(for: sleepWeekPageOffset)
	}

	private var selectedSleepWeekEnd: Date {
		calendar.date(byAdding: .day, value: 6, to: selectedSleepWeekStart) ?? selectedSleepWeekStart
	}

	private var earliestSleepRhythmDayStart: Date {
		let earliestSleep = sleepEvents.map(\.start).min()
		let earliestZyn = zynEvents.map(\.timestamp).min()
		let markerTrackerSet = Set(loggedCustomTrackers)
		let earliestHabit = habitEvents
			.filter { markerTrackerSet.contains($0.tracker) }
			.map(\.timestamp)
			.min()
		if let earliest = [earliestSleep, earliestZyn, earliestHabit].compactMap({ $0 }).min() {
			return calendar.startOfDay(for: earliest)
		}
		return todayStart
	}

	private var earliestSleepRhythmWeekStart: Date {
		sundayCalendar.dateInterval(of: .weekOfYear, for: earliestSleepRhythmDayStart)?.start ?? earliestSleepRhythmDayStart
	}

	private var maxPastSleepWeekOffset: Int {
		let dayDistance = max(0, calendar.dateComponents([.day], from: earliestSleepRhythmWeekStart, to: currentSleepWeekStart).day ?? 0)
		return dayDistance / 7
	}

	private var sleepRhythmPeriodLabel: String {
		"\(selectedSleepWeekStart.formatted(.dateTime.month().day())) – \(selectedSleepWeekEnd.formatted(.dateTime.month().day()))"
	}

	private func clampSleepWeekPageOffset() {
		sleepWeekPageOffset = min(maxPastSleepWeekOffset, max(0, sleepWeekPageOffset))
	}

	private func shiftSleepRhythmWeek(older: Bool) {
		guard !isSleepWeekArrowAnimating else { return }

		let direction: CGFloat = older ? 1 : -1
		let target = older ? min(maxPastSleepWeekOffset, sleepWeekPageOffset + 1) : max(0, sleepWeekPageOffset - 1)
		guard target != sleepWeekPageOffset else {
			let edgeNudge = sleepPageWidth * 0.12 * direction
			withAnimation(.easeOut(duration: 0.12)) {
				sleepWeekDragTranslation = edgeNudge
			}
			withAnimation(.easeOut(duration: 0.16).delay(0.08)) {
				sleepWeekDragTranslation = 0
			}
			return
		}

		sleepWeekArrowAnimationToken += 1
		let token = sleepWeekArrowAnimationToken
		sleepWeekArrowTargetOffset = target
		isSleepWeekArrowAnimating = true

		let slideTarget = direction * sleepPageWidth
		let slideDuration = 0.50

		animateSleepSlide(to: slideTarget, duration: slideDuration, token: token) {
			guard token == sleepWeekArrowAnimationToken else { return }
			sleepWeekPageOffset = target
			sleepWeekDragTranslation = 0
			sleepWeekArrowTargetOffset = nil
			isSleepWeekArrowAnimating = false
		}
	}

	private var chartTapGesture: some Gesture {
		SpatialTapGesture()
			.onEnded { value in
				guard !isWeekArrowAnimating else { return }
				didHandleChartTap = true
				selectDataBucketAtX(value.location.x, animated: true)
				DispatchQueue.main.async {
					didHandleChartTap = false
				}
			}
	}

	private var chartPageWidth: CGFloat {
		if chartPlotWidth > 20 {
			return chartPlotWidth
		}
		let measured = chartCardWidth - 58
		if measured > 20 {
			return measured
		}
		return max(220, UIScreen.main.bounds.width - 106)
	}

	private var sleepPageWidth: CGFloat {
		if sleepPlotWidth > 20 {
			return sleepPlotWidth
		}
		return chartPageWidth
	}

	private func easedSlideProgress(_ t: Double) -> Double {
		let clamped = max(0, min(1, t))
		return 1 - pow(1 - clamped, 3)
	}

	private func animateTopSlide(to target: CGFloat, duration: Double, token: Int, completion: @escaping () -> Void) {
		let start = weekDragTranslation
		let frameCount = max(1, Int(duration * 60))

		for frame in 1...frameCount {
			let delay = duration * Double(frame) / Double(frameCount)
			DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
				guard token == weekArrowAnimationToken else { return }
				let progress = Double(frame) / Double(frameCount)
				let eased = easedSlideProgress(progress)
				weekDragTranslation = start + (target - start) * CGFloat(eased)
				if frame == frameCount {
					completion()
				}
			}
		}
	}

	private func animateSleepSlide(to target: CGFloat, duration: Double, token: Int, completion: @escaping () -> Void) {
		let start = sleepWeekDragTranslation
		let frameCount = max(1, Int(duration * 60))

		for frame in 1...frameCount {
			let delay = duration * Double(frame) / Double(frameCount)
			DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
				guard token == sleepWeekArrowAnimationToken else { return }
				let progress = Double(frame) / Double(frameCount)
				let eased = easedSlideProgress(progress)
				sleepWeekDragTranslation = start + (target - start) * CGFloat(eased)
				if frame == frameCount {
					completion()
				}
			}
		}
	}

	private func animateRangeArrowShift(older: Bool) {
		guard !isWeekArrowAnimating else { return }
		let range = selectedRange

		let direction = older ? 1 : -1
		let current = offset(for: range)
		let delta = direction * stepSize(for: range)
		let targetOffset = max(0, min(maxOffset(for: range), current + delta))
		guard targetOffset != current else {
			let edgeNudge = chartPageWidth * 0.12 * CGFloat(direction)
			withAnimation(.easeOut(duration: 0.12)) {
				weekDragTranslation = edgeNudge
			}
			withAnimation(.easeOut(duration: 0.16).delay(0.08)) {
				weekDragTranslation = 0
			}
			return
		}

		weekArrowAnimationToken += 1
		let token = weekArrowAnimationToken
		weekArrowTargetOffset = targetOffset
		isWeekArrowAnimating = true

		let translationTarget = CGFloat(direction) * chartPageWidth
		let slideDuration = 0.50

		animateTopSlide(to: translationTarget, duration: slideDuration, token: token) {
			guard token == weekArrowAnimationToken else { return }
			setOffset(targetOffset, for: range)
			weekDragTranslation = 0
			weekArrowTargetOffset = nil
			isWeekArrowAnimating = false
			anchorDate = activePeriodAnchorDate
		}
	}

	private func axisTicks(for range: InsightsChartRange, buckets: [InsightsChartBucket]) -> [InsightsAxisTick] {
		guard !buckets.isEmpty else { return [] }

		switch range {
		case .day:
			let marks: [(hour: Int, label: String)] = [
				(0, "12AM"),
				(6, "6AM"),
				(12, "12PM"),
				(18, "6PM")
			]
			var ticks: [InsightsAxisTick] = []
			for (index, mark) in marks.enumerated() {
				let position: CGFloat
				if mark.hour == 0 {
					position = 0.06
				} else {
					// Place label in the first bar slot after each boundary line.
					position = (CGFloat(mark.hour) + 0.5) / 24.0
				}
				ticks.append(
					InsightsAxisTick(
						id: index,
						position: position,
						label: mark.label
					)
				)
			}
			return ticks
		case .week, .year:
			if range == .week {
				return weekTicks(for: buckets)
			}
			var ticks: [InsightsAxisTick] = []
			for index in buckets.indices {
				let label = buckets[index].label
				ticks.append(
					InsightsAxisTick(
						id: index,
						position: centeredTickPosition(index: index, count: buckets.count),
						label: label
					)
				)
			}
			return ticks
		case .month, .sixMonths:
			var ticks: [InsightsAxisTick] = []
			var labelIndex = 0
			for index in buckets.indices {
				let label = buckets[index].label
				if label.isEmpty { continue }
				ticks.append(
					InsightsAxisTick(
						id: labelIndex,
						position: centeredTickPosition(index: index, count: buckets.count),
						label: label
					)
				)
				labelIndex += 1
			}
			return ticks
		}
	}

	private func weekTicks(for buckets: [InsightsChartBucket]) -> [InsightsAxisTick] {
		var ticks: [InsightsAxisTick] = []
		for index in buckets.indices {
			let label = buckets[index].label
			ticks.append(
				InsightsAxisTick(
					id: index,
					position: centeredTickPosition(index: index, count: buckets.count),
					label: label
				)
			)
		}
		return ticks
	}

	private func axisGridLines(for range: InsightsChartRange, buckets: [InsightsChartBucket]) -> [InsightsGridLine] {
		guard !buckets.isEmpty else { return [] }

		switch range {
		case .day:
			var lines: [InsightsGridLine] = [
				InsightsGridLine(id: "day-solid-0", position: 0, style: .solid),
				InsightsGridLine(id: "day-solid-24", position: 1, style: .solid)
			]
			let dashedMarks = [6, 12, 18]
			for mark in dashedMarks {
				lines.append(
					InsightsGridLine(
						id: "day-dashed-\(mark)",
						position: dayBoundaryPosition(hourMark: mark),
						style: .dashed
					)
				)
			}
			return lines
		case .week:
			return weekBoundaryGridLines(for: buckets)
		case .year:
			return (0...buckets.count).map { index in
				InsightsGridLine(
					id: "std-\(index)",
					position: boundaryTickPosition(index: index, count: buckets.count),
					style: (index == 0 || index == buckets.count) ? .solid : .dashed
				)
			}
		case .month:
			var lines: [InsightsGridLine] = []
			if buckets.count > 7 {
				for boundary in stride(from: 7, through: buckets.count - 1, by: 7) {
					lines.append(
						InsightsGridLine(
							id: "month-week-\(boundary)",
							position: boundaryTickPosition(index: boundary, count: buckets.count),
							style: .dashed
						)
					)
				}
			}
			lines.append(InsightsGridLine(id: "month-solid-start", position: 0, style: .solid))
			lines.append(InsightsGridLine(id: "month-solid-end", position: 1, style: .solid))
			return lines
		case .sixMonths:
			let sixMonthEndMonthStart = calendar.date(byAdding: .month, value: -sixMonthOffset, to: currentMonthStart) ?? currentMonthStart
			guard let startMonth = calendar.date(byAdding: .month, value: -5, to: sixMonthEndMonthStart),
				  let afterEndMonth = calendar.date(byAdding: .month, value: 1, to: sixMonthEndMonthStart) else {
				return []
			}

			var lines: [InsightsGridLine] = []
			var cursor = startMonth
			var monthIndex = 0
			while cursor <= afterEndMonth {
				lines.append(
					InsightsGridLine(
						id: "sixm-month-\(monthIndex)",
						position: sixMonthBoundaryPosition(for: cursor, buckets: buckets),
						style: .dashed
					)
				)
				monthIndex += 1
					guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
					cursor = nextMonth
				}
			return ensureStartBoundaryLine(lines)
		}
	}

	private func centeredTickPosition(index: Int, count: Int) -> CGFloat {
		guard count > 0 else { return 0.5 }
		return (CGFloat(index) + 0.5) / CGFloat(count)
	}

	private func boundaryTickPosition(index: Int, count: Int) -> CGFloat {
		guard count > 0 else { return 0.5 }
		return CGFloat(index) / CGFloat(count)
	}

	private func dayBoundaryPosition(hourMark: Int) -> CGFloat {
		CGFloat(hourMark) / 24.0
	}

	private func ensureStartBoundaryLine(_ lines: [InsightsGridLine]) -> [InsightsGridLine] {
		let hasStart = lines.contains { abs($0.position) < 0.0001 }
		guard !hasStart else { return lines }
		var adjusted = lines
		adjusted.append(InsightsGridLine(id: "auto-start-\(lines.count)", position: 0, style: .dashed))
		return adjusted
	}

	private func sixMonthBoundaryPosition(for boundary: Date, buckets: [InsightsChartBucket]) -> CGFloat {
		guard !buckets.isEmpty else { return 0 }
		let starts = buckets.map(\.start)
		guard let first = starts.first else { return 0 }
		let count = starts.count
		if boundary <= first { return 0 }
		if count == 1 { return 1 }

		for index in 0..<(count - 1) {
			let start = starts[index]
			let end = starts[index + 1]
			if boundary >= start && boundary <= end {
				let total = end.timeIntervalSince(start)
				guard total > 0 else { return CGFloat(index) / CGFloat(count) }
				let fraction = max(0, min(1, boundary.timeIntervalSince(start) / total))
				return (CGFloat(index) + CGFloat(fraction)) / CGFloat(count)
			}
		}

		guard let last = starts.last else { return 1 }
		let assumedEnd = calendar.date(byAdding: .day, value: 7, to: last) ?? last
		if boundary <= assumedEnd {
			let total = assumedEnd.timeIntervalSince(last)
			guard total > 0 else { return 1 }
			let fraction = max(0, min(1, boundary.timeIntervalSince(last) / total))
			return (CGFloat(count - 1) + CGFloat(fraction)) / CGFloat(count)
		}
		return 1
	}

	private var currentOffset: Int {
		offset(for: selectedRange)
	}

	private var maxOffset: Int {
		maxOffset(for: selectedRange)
	}

	private func offset(for range: InsightsChartRange) -> Int {
		switch range {
		case .day: return dayOffset
		case .week: return weekDayOffset
		case .month: return monthOffset
		case .sixMonths: return sixMonthOffset
		case .year: return yearOffset
		}
	}

	private func maxOffset(for range: InsightsChartRange) -> Int {
		switch range {
		case .day: return maxPastDayOffset
		case .week: return maxPastWeekDayOffset
		case .month: return maxPastMonthOffset
		case .sixMonths: return maxPastSixMonthOffset
		case .year: return maxPastYearOffset
		}
	}

	private func stepSize(for range: InsightsChartRange) -> Int {
		switch range {
		case .week: return 7
		default: return 1
		}
	}

	private func setOffset(_ value: Int, for range: InsightsChartRange) {
		switch range {
		case .day:
			dayOffset = value
		case .week:
			weekDayOffset = value
		case .month:
			monthOffset = value
		case .sixMonths:
			sixMonthOffset = value
		case .year:
			yearOffset = value
		}
	}

	private var periodLabel: String {
		switch selectedRange {
		case .day:
			return selectedDayStart.formatted(.dateTime.weekday(.abbreviated).month().day().year())
		case .week:
			return "\(selectedWeekStart.formatted(.dateTime.month().day())) - \(selectedWeekEnd.formatted(.dateTime.month().day().year()))"
		case .month:
			return selectedMonthStart.formatted(.dateTime.month(.wide).year())
		case .sixMonths:
			let startMonth = calendar.date(byAdding: .month, value: -5, to: selectedSixMonthEndMonthStart) ?? selectedSixMonthEndMonthStart
			return "\(startMonth.formatted(.dateTime.month(.abbreviated).year())) - \(selectedSixMonthEndMonthStart.formatted(.dateTime.month(.abbreviated).year()))"
		case .year:
			return selectedYearStart.formatted(.dateTime.year())
		}
	}

	private var bucketSet: InsightsChartBucketSet {
		bucketSet(for: selectedRange, offset: currentOffset)
	}

	private func bucketSet(for range: InsightsChartRange, offset: Int) -> InsightsChartBucketSet {
		switch range {
		case .day:
			let dayStart = calendar.date(byAdding: .day, value: -offset, to: todayStart) ?? todayStart
			return dayBucketSet(for: dayStart)
		case .week:
			let weekEnd = calendar.date(byAdding: .day, value: -offset, to: currentWeekWindowEndDay) ?? currentWeekWindowEndDay
			let weekStart = calendar.date(byAdding: .day, value: -6, to: weekEnd) ?? weekEnd
			return weekBucketSet(for: weekStart)
		case .month:
			let monthStart = calendar.date(byAdding: .month, value: -offset, to: currentMonthStart) ?? currentMonthStart
			return monthBucketSet(for: monthStart)
		case .sixMonths:
			let sixMonthEndMonthStart = calendar.date(byAdding: .month, value: -offset, to: currentMonthStart) ?? currentMonthStart
			return sixMonthBucketSet(endMonthStart: sixMonthEndMonthStart)
		case .year:
			let yearStart = calendar.date(byAdding: .year, value: -offset, to: currentYearStart) ?? currentYearStart
			return yearBucketSet(for: yearStart)
		}
	}

	private var summaryValueLabel: String {
		if selectedRange == .day {
			return "\(Int(bucketSet.summaryValue.rounded()))"
		}
		return String(format: "%.1f", bucketSet.summaryValue)
	}

	private var selectedBucket: InsightsChartBucket? {
		guard let start = selectedBucketStart else { return nil }
		return bucketSet.buckets.first(where: { $0.start == start })
	}

	@ViewBuilder
	private func selectedBucketSummaryCard(for bucket: InsightsChartBucket) -> some View {
		VStack(alignment: .leading, spacing: 4) {
			Text("TOTAL")
				.font(.system(size: 12, weight: .semibold))
				.foregroundStyle(Color.white.opacity(0.66))

				HStack(alignment: .firstTextBaseline, spacing: 4) {
					Text("\(selectedBucketTotalCount(for: bucket))")
						.font(.system(size: 44, weight: .bold))
						.foregroundStyle(.white)
						.monospacedDigit()
					Text(selectedChartUnitLabel(for: Double(selectedBucketTotalCount(for: bucket))))
						.font(.system(size: 24, weight: .semibold))
						.foregroundStyle(Color.white.opacity(0.86))
				}

			Text(selectedBucketLabel(for: bucket))
				.font(.system(size: 15, weight: .medium))
				.foregroundStyle(Color.white.opacity(0.70))
		}
		.padding(.horizontal, 14)
		.padding(.vertical, 10)
		.background(
			RoundedRectangle(cornerRadius: 14, style: .continuous)
				.fill(Color.white.opacity(0.10))
				.overlay(
					RoundedRectangle(cornerRadius: 14, style: .continuous)
						.stroke(Color.white.opacity(0.16), lineWidth: 1)
				)
		)
		.frame(maxWidth: .infinity, alignment: .leading)
	}

	private func selectedBucketTotalCount(for bucket: InsightsChartBucket) -> Int {
		if selectedRange == .year {
			guard let monthEnd = calendar.date(byAdding: .month, value: 1, to: bucket.start) else {
				return Int(bucket.value.rounded())
			}
			return eventCountInEligibleWindow(from: bucket.start, to: monthEnd)
		}
		return Int(bucket.value.rounded())
	}

	private func selectionLineBarHeight(for value: Double, axisTop: Double) -> CGFloat {
		guard value > 0, axisTop > 0 else { return 0 }
		let normalized = value / axisTop
		return max(2, 220 * normalized)
	}

	private func selectedBucketLabel(for bucket: InsightsChartBucket) -> String {
		switch selectedRange {
		case .day:
			return bucket.start.formatted(.dateTime.month().day().hour().minute())
		case .week, .month:
			return bucket.start.formatted(.dateTime.weekday(.abbreviated).month().day().year())
		case .sixMonths:
			let end = calendar.date(byAdding: .day, value: 6, to: bucket.start) ?? bucket.start
			return "\(bucket.start.formatted(.dateTime.month().day())) - \(end.formatted(.dateTime.month().day().year()))"
		case .year:
			return bucket.start.formatted(.dateTime.month(.wide).year())
		}
	}

	private func clearSelectedBucket(animated _: Bool) {
		selectedBucketStart = nil
	}

	private func selectDataBucketAtX(_ x: CGFloat, animated: Bool) {
		let buckets = bucketSet.buckets
		guard !buckets.isEmpty else {
			clearSelectedBucket(animated: animated)
			return
		}
		let plotWidth = max(1, chartCardWidth - 58)
		let relativeX = x - 14
		guard relativeX >= 0, relativeX <= plotWidth else {
			clearSelectedBucket(animated: animated)
			return
		}
		let slotWidth = plotWidth / CGFloat(max(1, buckets.count))
		let slot = max(0, min(buckets.count - 1, Int(floor(relativeX / slotWidth))))
		guard buckets[slot].value > 0 else {
			clearSelectedBucket(animated: animated)
			return
		}
		let target = buckets[slot].start
		guard selectedBucketStart != target else { return }
		selectedBucketStart = target
	}

	private var todayStart: Date {
		cachedTodayStart
	}

	private var latestLogDayStart: Date {
		cachedLatestLogDayStart
	}

	private var weekWindowBaseEndDay: Date {
		// Always anchor week navigation to the current calendar week.
		todayStart
	}

	private var currentWeekWindowEndDay: Date {
		let weekStart = sundayCalendar.dateInterval(of: .weekOfYear, for: weekWindowBaseEndDay)?.start ?? weekWindowBaseEndDay
		return calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekWindowBaseEndDay
	}

	private var tomorrowStart: Date {
		calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
	}

	private var currentMonthStart: Date {
		calendar.date(from: calendar.dateComponents([.year, .month], from: todayStart)) ?? todayStart
	}

	private var currentYearStart: Date {
		calendar.date(from: calendar.dateComponents([.year], from: todayStart)) ?? todayStart
	}

	private var firstDataDayStart: Date {
		cachedFirstDataDayStart
	}

	private func recomputeDataBounds() {
		let safeTodayStart = todayStart
		guard let firstEvent = chartEventTimestamps.first else {
			cachedFirstDataDayStart = safeTodayStart
			cachedLatestLogDayStart = safeTodayStart
			return
		}

		var earliest = firstEvent
		var latest = firstEvent
		for timestamp in chartEventTimestamps.dropFirst() {
			if timestamp < earliest {
				earliest = timestamp
			}
			if timestamp > latest {
				latest = timestamp
			}
		}

		cachedFirstDataDayStart = calendar.startOfDay(for: earliest)
		cachedLatestLogDayStart = calendar.startOfDay(for: latest)
	}

	private func refreshTodayStart() {
		cachedTodayStart = calendar.startOfDay(for: Date())
	}

	private var firstDataMonthStart: Date {
		calendar.date(from: calendar.dateComponents([.year, .month], from: firstDataDayStart)) ?? firstDataDayStart
	}

	private var firstDataYearStart: Date {
		calendar.date(from: calendar.dateComponents([.year], from: firstDataDayStart)) ?? firstDataDayStart
	}

	private var maxPastDayOffset: Int {
		max(0, calendar.dateComponents([.day], from: firstDataDayStart, to: todayStart).day ?? 0)
	}

	private var maxPastWeekDayOffset: Int {
		max(0, calendar.dateComponents([.day], from: firstDataDayStart, to: currentWeekWindowEndDay).day ?? 0) + 1
	}

	private var maxPastMonthOffset: Int {
		max(0, calendar.dateComponents([.month], from: firstDataMonthStart, to: currentMonthStart).month ?? 0)
	}

	private var maxPastSixMonthOffset: Int {
		max(0, calendar.dateComponents([.month], from: firstDataMonthStart, to: currentMonthStart).month ?? 0)
	}

	private var maxPastYearOffset: Int {
		max(0, calendar.dateComponents([.year], from: firstDataYearStart, to: currentYearStart).year ?? 0)
	}

	private var selectedDayStart: Date {
		calendar.date(byAdding: .day, value: -dayOffset, to: todayStart) ?? todayStart
	}

	private var selectedWeekEnd: Date {
		calendar.date(byAdding: .day, value: -weekDayOffset, to: currentWeekWindowEndDay) ?? currentWeekWindowEndDay
	}

	private var selectedWeekStart: Date {
		calendar.date(byAdding: .day, value: -6, to: selectedWeekEnd) ?? selectedWeekEnd
	}

	private var selectedMonthStart: Date {
		calendar.date(byAdding: .month, value: -monthOffset, to: currentMonthStart) ?? currentMonthStart
	}

	private var selectedSixMonthEndMonthStart: Date {
		calendar.date(byAdding: .month, value: -sixMonthOffset, to: currentMonthStart) ?? currentMonthStart
	}

	private var selectedYearStart: Date {
		calendar.date(byAdding: .year, value: -yearOffset, to: currentYearStart) ?? currentYearStart
	}

	private func syncSelectedRangeToAnchor() {
		let normalizedAnchor = max(firstDataDayStart, min(todayStart, calendar.startOfDay(for: anchorDate)))
		anchorDate = normalizedAnchor

		switch selectedRange {
		case .day:
			dayOffset = max(0, calendar.dateComponents([.day], from: normalizedAnchor, to: todayStart).day ?? 0)
		case .week:
			weekDayOffset = max(0, calendar.dateComponents([.day], from: normalizedAnchor, to: currentWeekWindowEndDay).day ?? 0)
		case .month:
			let start = calendar.date(from: calendar.dateComponents([.year, .month], from: normalizedAnchor)) ?? normalizedAnchor
			monthOffset = max(0, calendar.dateComponents([.month], from: start, to: currentMonthStart).month ?? 0)
		case .sixMonths:
			let start = calendar.date(from: calendar.dateComponents([.year, .month], from: normalizedAnchor)) ?? normalizedAnchor
			sixMonthOffset = max(0, calendar.dateComponents([.month], from: start, to: currentMonthStart).month ?? 0)
		case .year:
			let start = calendar.date(from: calendar.dateComponents([.year], from: normalizedAnchor)) ?? normalizedAnchor
			yearOffset = max(0, calendar.dateComponents([.year], from: start, to: currentYearStart).year ?? 0)
		}

		clampOffsets()
	}

	private func syncSelectedChartTracker() {
		let available = availableChartTrackers
		if let current = available.first(where: { $0.id == selectedTrackerID }) {
			selectedTrackerID = current.id
			return
		}
		selectedTrackerID = available.first?.id ?? ""
	}

	private func resetTopRangeToCurrent(for range: InsightsChartRange) {
		switch range {
		case .day:
			dayOffset = 0
		case .week:
			weekDayOffset = 0
		case .month:
			monthOffset = 0
		case .sixMonths:
			sixMonthOffset = 0
		case .year:
			yearOffset = 0
		}
		anchorDate = activePeriodAnchorDate
	}

	private func shiftCurrentRange(older: Bool) {
		clearSelectedBucket(animated: true)
		animateRangeArrowShift(older: older)
	}

	private func clampOffsets() {
		dayOffset = min(maxPastDayOffset, max(0, dayOffset))
		weekDayOffset = min(maxPastWeekDayOffset, max(0, weekDayOffset))
		monthOffset = min(maxPastMonthOffset, max(0, monthOffset))
		sixMonthOffset = min(maxPastSixMonthOffset, max(0, sixMonthOffset))
		yearOffset = min(maxPastYearOffset, max(0, yearOffset))
	}

	private var activePeriodAnchorDate: Date {
		switch selectedRange {
		case .day:
			return selectedDayStart
		case .week:
			return selectedWeekEnd
		case .month:
			let end = calendar.date(byAdding: .month, value: 1, to: selectedMonthStart) ?? selectedMonthStart
			return calendar.date(byAdding: .day, value: -1, to: end) ?? selectedMonthStart
		case .sixMonths:
			let end = calendar.date(byAdding: .month, value: 1, to: selectedSixMonthEndMonthStart) ?? selectedSixMonthEndMonthStart
			return calendar.date(byAdding: .day, value: -1, to: end) ?? selectedSixMonthEndMonthStart
		case .year:
			let end = calendar.date(byAdding: .year, value: 1, to: selectedYearStart) ?? selectedYearStart
			return calendar.date(byAdding: .day, value: -1, to: end) ?? selectedYearStart
		}
	}

	private var yAxisTopValue: Double {
		let rawMax = bucketSet.buckets.map(\.value).max() ?? 0

		if selectedRange == .day {
			return max(1, ceil(rawMax))
		}
		if rawMax <= 4 {
			return 5
		}
		if rawMax <= 10 {
			return 10
		}
		return ceil(rawMax / 10.0) * 10.0
	}

	private var showMidYAxisLabel: Bool {
		!(selectedRange == .day && yAxisTopValue <= 1)
	}

	private func axisLabel(_ value: Double) -> String {
		if value == floor(value) {
			return "\(Int(value))"
		}
		return String(format: "%.1f", value)
	}

	private func weekBoundaryGridLines(for buckets: [InsightsChartBucket]) -> [InsightsGridLine] {
		guard !buckets.isEmpty else { return [] }

		var lines: [InsightsGridLine] = []
		let count = buckets.count

		for index in 0...count {
			let boundaryPosition = boundaryTickPosition(index: index, count: count)
			let boundaryDate: Date?
			if index < count {
				boundaryDate = buckets[index].start
			} else if let last = buckets.last?.start {
				boundaryDate = calendar.date(byAdding: .day, value: 1, to: last)
			} else {
				boundaryDate = nil
			}
			let weekday = boundaryDate.map { calendar.component(.weekday, from: $0) }
			let style: InsightsGridLine.Style = (weekday == 1) ? .solid : .dashed
			lines.append(
				InsightsGridLine(
					id: "week-boundary-\(index)",
					position: boundaryPosition,
					style: style
				)
			)
		}

		return lines
	}

	private func dayBucketSet(for dayStart: Date) -> InsightsChartBucketSet {
		let buckets: [InsightsChartBucket] = (0..<24).compactMap { hour in
			guard let start = calendar.date(byAdding: .hour, value: hour, to: dayStart),
				  let end = calendar.date(byAdding: .hour, value: 1, to: start) else {
				return nil
			}
			let count = eventCount(from: start, to: end)
			let label: String
			switch hour {
			case 0: label = "12AM"
			case 6: label = "6AM"
			case 12: label = "12PM"
			case 18: label = "6PM"
			default: label = ""
			}
			return InsightsChartBucket(start: start, value: Double(count), label: label)
		}
		let total = buckets.reduce(0.0) { $0 + $1.value }
		return InsightsChartBucketSet(
			buckets: buckets,
			summaryValue: total,
			summaryTitle: "TOTAL",
			rangeLabel: dayStart.formatted(.dateTime.weekday(.abbreviated).month().day().year())
		)
	}

	private func weekBucketSet(for weekStart: Date) -> InsightsChartBucketSet {
		let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
		let starts: [Date] = (0..<7).compactMap { value in
			calendar.date(byAdding: .day, value: value, to: weekStart)
		}
		let buckets: [InsightsChartBucket] = starts.compactMap { start in
			guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
			let count = eventCount(from: start, to: end)
			let label = start.formatted(.dateTime.weekday(.abbreviated))
			return InsightsChartBucket(start: start, value: Double(count), label: label)
		}
		let summaryAverage = dailyAverage(in: weekStart, end: weekEnd)
		let endDisplay = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
		let startLabel = starts.first?.formatted(.dateTime.month().day()) ?? ""
		let endLabel = endDisplay.formatted(.dateTime.month().day().year())
		return InsightsChartBucketSet(
			buckets: buckets,
			summaryValue: summaryAverage,
			summaryTitle: "DAILY AVERAGE",
			rangeLabel: "\(startLabel) – \(endLabel)"
		)
	}

	private func monthBucketSet(for monthStart: Date) -> InsightsChartBucketSet {
		let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
		let days = max(1, calendar.dateComponents([.day], from: monthStart, to: monthEnd).day ?? 1)
		let buckets: [InsightsChartBucket] = (0..<days).compactMap { index in
			guard let start = calendar.date(byAdding: .day, value: index, to: monthStart),
				  let end = calendar.date(byAdding: .day, value: 1, to: start) else {
				return nil
			}
			let count = eventCount(from: start, to: end)
			let day = calendar.component(.day, from: start)
			let label = (index % 7 == 0) ? "\(day)" : ""
			return InsightsChartBucket(start: start, value: Double(count), label: label)
		}
		let summaryAverage = dailyAverage(in: monthStart, end: monthEnd)
		return InsightsChartBucketSet(
			buckets: buckets,
			summaryValue: summaryAverage,
			summaryTitle: "DAILY AVERAGE",
			rangeLabel: monthStart.formatted(.dateTime.month(.wide).year())
		)
	}

	private func sixMonthBucketSet(endMonthStart: Date) -> InsightsChartBucketSet {
		guard let startMonth = calendar.date(byAdding: .month, value: -5, to: endMonthStart),
			  let afterEndMonth = calendar.date(byAdding: .month, value: 1, to: endMonthStart),
			  let firstWeekStart = isoCalendar.dateInterval(of: .weekOfYear, for: startMonth)?.start,
			  let weekAfterEnd = isoCalendar.dateInterval(of: .weekOfYear, for: afterEndMonth)?.start else {
			return InsightsChartBucketSet(buckets: [], summaryValue: 0, summaryTitle: "DAILY AVERAGE", rangeLabel: "")
		}

		var buckets: [InsightsChartBucket] = []
		var previousMonth: Int?
		var cursor = firstWeekStart

		while cursor < weekAfterEnd {
			let weekStart = cursor
			guard let nextCursor = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart),
				  let rawWeekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
				break
			}
			cursor = nextCursor

			let weekEnd = min(rawWeekEnd, weekAfterEnd)
			let monthForLabelDate = max(weekStart, startMonth)
			let month = calendar.component(.month, from: monthForLabelDate)
			let showLabel = previousMonth != month
			previousMonth = month
			let label = showLabel ? monthForLabelDate.formatted(.dateTime.month(.abbreviated)) : ""
			let days = eligibleDayCount(in: weekStart, end: weekEnd)
			let total = eventCountInEligibleWindow(from: weekStart, to: weekEnd)
			let value = days > 0 ? Double(total) / Double(days) : 0
			buckets.append(InsightsChartBucket(start: weekStart, value: value, label: label))
		}

		let summaryAverage = dailyAverage(in: startMonth, end: afterEndMonth)
		let rangeLabel = "\(startMonth.formatted(.dateTime.month(.abbreviated).year())) – \(endMonthStart.formatted(.dateTime.month(.abbreviated).year()))"

		return InsightsChartBucketSet(
			buckets: buckets,
			summaryValue: summaryAverage,
			summaryTitle: "DAILY AVERAGE",
			rangeLabel: rangeLabel
		)
	}

	private func yearBucketSet(for yearStart: Date) -> InsightsChartBucketSet {
		let yearEnd = calendar.date(byAdding: .year, value: 1, to: yearStart) ?? yearStart
		let buckets: [InsightsChartBucket] = (0..<12).compactMap { index in
			guard let monthStart = calendar.date(byAdding: .month, value: index, to: yearStart),
				  let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
				return nil
			}
			let days = eligibleDayCount(in: monthStart, end: monthEnd)
			let total = eventCountInEligibleWindow(from: monthStart, to: monthEnd)
			let value = days > 0 ? Double(total) / Double(days) : 0
			return InsightsChartBucket(start: monthStart, value: value, label: monthStart.formatted(.dateTime.month(.abbreviated)))
		}

		return InsightsChartBucketSet(
			buckets: buckets,
			summaryValue: dailyAverage(in: yearStart, end: yearEnd),
			summaryTitle: "DAILY AVERAGE",
			rangeLabel: yearStart.formatted(.dateTime.year())
		)
	}

	private func eventCount(from start: Date, to end: Date) -> Int {
		chartEventTimestamps.reduce(0) { partialResult, timestamp in
			partialResult + ((timestamp >= start && timestamp < end) ? 1 : 0)
		}
	}

	private func eventCountInEligibleWindow(from start: Date, to end: Date) -> Int {
		let clampedStart = max(start, firstDataDayStart)
		let clampedEnd = min(end, tomorrowStart)
		guard clampedEnd > clampedStart else { return 0 }
		return eventCount(from: clampedStart, to: clampedEnd)
	}

	private func eligibleDayCount(in start: Date, end: Date) -> Int {
		let clampedStart = max(start, firstDataDayStart)
		let clampedEnd = min(end, tomorrowStart)
		guard clampedEnd > clampedStart else { return 0 }
		return max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: clampedStart), to: calendar.startOfDay(for: clampedEnd)).day ?? 0)
	}

	private func dailyAverage(in start: Date, end: Date) -> Double {
		let days = eligibleDayCount(in: start, end: end)
		guard days > 0 else { return 0 }
		let total = eventCountInEligibleWindow(from: start, to: end)
		return Double(total) / Double(days)
	}
}

private struct SleepCenteredSummaryCard: View {
	let status: String
	let intervalText: String

	var body: some View {
		VStack(spacing: 8) {
			Text("Today")
				.font(.system(size: 14, weight: .semibold))
				.foregroundStyle(Color.white.opacity(0.62))

			Text(status)
				.font(.system(size: 46, weight: .bold))
				.foregroundStyle(.white)

			Text(intervalText)
				.font(.system(size: 18, weight: .medium))
				.foregroundStyle(Color.white.opacity(0.72))
				.monospacedDigit()
				.multilineTextAlignment(.center)
		}
		.frame(maxWidth: .infinity, alignment: .center)
		.padding(.horizontal, 20)
		.padding(.vertical, 18)
		.background(WeatherSummaryCardShell())
	}
}

private func zynCountSummaryLabel(_ count: Int) -> String {
	if count == 1 {
		return "1 ZYN"
	}
	return "\(count) ZYN's"
}

private func trackerCountSummaryLabel(_ count: Int, tracker: TrackerKind) -> String {
	let base = tracker.displayName
	if tracker == .cannabis {
		return "\(count) \(base)"
	}
	if count == 1 {
		return "1 \(base)"
	}
	return "\(count) \(base)'s"
}

private struct ZynCenteredSummaryCard: View {
	let todayCount: Int
	let subtitle: String

	var body: some View {
		VStack(spacing: 8) {
			Text("Today")
				.font(.system(size: 14, weight: .semibold))
				.foregroundStyle(Color.white.opacity(0.62))

			Text(zynCountSummaryLabel(todayCount))
				.font(.system(size: 46, weight: .bold))
				.foregroundStyle(.white)
				.monospacedDigit()

			Text(subtitle)
				.font(.system(size: 18, weight: .medium))
				.foregroundStyle(Color.white.opacity(0.72))
				.monospacedDigit()
				.multilineTextAlignment(.center)
		}
		.frame(maxWidth: .infinity, alignment: .center)
		.padding(.horizontal, 20)
		.padding(.vertical, 18)
		.background(WeatherSummaryCardShell())
	}
}

private struct WeatherSummaryCardShell: View {
	var body: some View {
		RoundedRectangle(cornerRadius: 24, style: .continuous)
			.fill(
				LinearGradient(
					colors: [
						Color(red: 0.21, green: 0.30, blue: 0.44).opacity(0.74),
						Color(red: 0.15, green: 0.22, blue: 0.35).opacity(0.74)
					],
					startPoint: .topLeading,
					endPoint: .bottomTrailing
				)
			)
			.overlay(
				RoundedRectangle(cornerRadius: 24, style: .continuous)
					.stroke(Color(red: 0.65, green: 0.79, blue: 0.96).opacity(0.22), lineWidth: 1)
			)
			.shadow(color: Color.black.opacity(0.20), radius: 14, y: 8)
	}
}

private struct WeatherActionPill: View {
	let label: String
	var isActive: Bool = false

	var body: some View {
		Text(label)
			.font(.system(size: 17, weight: .semibold))
			.foregroundStyle(.white)
			.padding(.horizontal, 22)
			.padding(.vertical, 12)
			.background(
				Capsule()
					.fill(
						LinearGradient(
							colors: isActive
								? [Color(red: 0.31, green: 0.56, blue: 0.86), Color(red: 0.25, green: 0.47, blue: 0.77)]
								: [Color(red: 0.24, green: 0.33, blue: 0.47).opacity(0.78), Color(red: 0.18, green: 0.25, blue: 0.37).opacity(0.78)],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						)
					)
					.overlay(
						Capsule()
							.stroke(
								isActive
									? Color(red: 0.68, green: 0.84, blue: 1.0).opacity(0.55)
									: Color(red: 0.63, green: 0.78, blue: 0.97).opacity(0.22),
								lineWidth: 1
							)
					)
			)
	}
}

private struct BottomNavBar: View {
	let pages: [HomePagerPage]
	let selectedPageID: String
	let onSelectPage: (String) -> Void

	var body: some View {
		HStack(spacing: 0) {
			ForEach(pages) { page in
				BottomNavItem(
					label: navLabel(for: page),
					isActive: selectedPageID == page.id,
					icon: navIcon(for: page),
					onTap: { onSelectPage(page.id) }
				)
				.frame(maxWidth: .infinity)
			}
		}
		.padding(.horizontal, 16)
		.padding(.vertical, 8)
		.frame(height: 72)
		.frame(maxWidth: .infinity)
		.background(
			ZStack {
				Rectangle()
					.fill(Color.clear)
					.ignoresSafeArea(edges: .bottom)

				Capsule()
					.fill(
						LinearGradient(
							colors: [
								Color(red: 0.17, green: 0.25, blue: 0.37).opacity(0.92),
								Color(red: 0.12, green: 0.19, blue: 0.30).opacity(0.92)
							],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						)
					)
					.overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
					.shadow(color: Color.black.opacity(0.28), radius: 12, y: 5)
					.padding(.horizontal, 12)
					.padding(.vertical, 3)
			}
		)
	}

	private func navLabel(for page: HomePagerPage) -> String {
		switch page {
		case .sleep:
			return "Sleep"
		case .zyn:
			return "ZYN"
		case .insights:
			return "Insights"
		case .custom(let tracker):
			return tracker.displayName
		case .add:
			return "Add"
		}
	}

	private func navIcon(for page: HomePagerPage) -> BottomNavItem.Icon {
		switch page {
		case .sleep:
			return .systemName("bed.double.fill")
		case .zyn:
			return .systemName("pills.fill")
		case .insights:
			return .systemName("chart.bar.fill")
		case .custom(let tracker):
			return .tracker(tracker)
		case .add:
			return .systemName("plus.circle.fill")
		}
	}
}

private struct SleepButtonTheme {
	let glow: Color
	let outerGradient: [Color]
	let innerGradient: [Color]
	let ringColor: Color
	let iconName: String
}

private struct AddTrackerLogSheet: View {
	@Environment(\.dismiss) private var dismiss
	let title: String
	let onSave: (Date) -> Void

	@State private var timestamp: Date = Date()

	var body: some View {
		NavigationStack {
			VStack(alignment: .leading, spacing: 14) {
				VStack(alignment: .leading, spacing: 6) {
					Text("Date & Time")
						.font(.system(size: 15, weight: .semibold, design: .rounded))
						.foregroundStyle(Color.white.opacity(0.78))
					DatePicker(
						"",
						selection: $timestamp,
						displayedComponents: [.date, .hourAndMinute]
					)
					.datePickerStyle(.wheel)
					.labelsHidden()
					.frame(maxWidth: .infinity)
					.frame(height: 160)
					.clipped()
				}
				.padding(12)
				.background(
					RoundedRectangle(cornerRadius: 16, style: .continuous)
						.fill(Color(red: 0.20, green: 0.31, blue: 0.47).opacity(0.36))
						.overlay(
							RoundedRectangle(cornerRadius: 16, style: .continuous)
								.stroke(Color(red: 0.58, green: 0.74, blue: 0.92).opacity(0.26), lineWidth: 1)
						)
				)

				Spacer(minLength: 0)
			}
			.padding(.horizontal, 16)
			.padding(.top, 10)
			.background(
				LinearGradient(
					colors: [
						Color(red: 0.09, green: 0.16, blue: 0.26).opacity(0.94),
						Color(red: 0.08, green: 0.14, blue: 0.24).opacity(0.96)
					],
					startPoint: .topLeading,
					endPoint: .bottomTrailing
				)
				.ignoresSafeArea()
			)
			.navigationTitle(title)
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .topBarLeading) {
					Button("Cancel") {
						dismiss()
					}
					.foregroundStyle(Color.white.opacity(0.82))
				}
				ToolbarItem(placement: .topBarTrailing) {
					Button("Save") {
						onSave(timestamp)
						dismiss()
					}
					.font(.system(size: 16, weight: .bold, design: .rounded))
				}
			}
		}
		.preferredColorScheme(.dark)
		.presentationDetents([.fraction(0.52)])
		.presentationDragIndicator(.visible)
	}
}

private struct AddSleepLogSheet: View {
	@Environment(\.dismiss) private var dismiss
	let onSave: (Date, Date) throws -> Void

	@State private var startDate: Date
	@State private var endDate: Date
	@State private var errorMessage: String?

	init(onSave: @escaping (Date, Date) throws -> Void) {
		self.onSave = onSave
		let now = Date()
		let defaultStart = Calendar.current.date(byAdding: .hour, value: -8, to: now) ?? now
		_startDate = State(initialValue: defaultStart)
		_endDate = State(initialValue: now)
	}

	var body: some View {
		NavigationStack {
			VStack(alignment: .leading, spacing: 14) {
				VStack(alignment: .leading, spacing: 6) {
					Text("Sleep Start")
						.font(.system(size: 15, weight: .semibold, design: .rounded))
						.foregroundStyle(Color.white.opacity(0.78))
						DatePicker(
							"",
							selection: $startDate,
							displayedComponents: [.date, .hourAndMinute]
						)
						.datePickerStyle(.wheel)
						.labelsHidden()
						.frame(maxWidth: .infinity)
						.frame(height: 136)
						.clipped()
				}
				.padding(12)
				.background(
					RoundedRectangle(cornerRadius: 16, style: .continuous)
						.fill(Color(red: 0.20, green: 0.31, blue: 0.47).opacity(0.36))
						.overlay(
							RoundedRectangle(cornerRadius: 16, style: .continuous)
								.stroke(Color(red: 0.58, green: 0.74, blue: 0.92).opacity(0.26), lineWidth: 1)
						)
				)

				VStack(alignment: .leading, spacing: 6) {
					Text("Wake Time")
						.font(.system(size: 15, weight: .semibold, design: .rounded))
						.foregroundStyle(Color.white.opacity(0.78))
						DatePicker(
							"",
							selection: $endDate,
							in: startDate...,
							displayedComponents: [.date, .hourAndMinute]
						)
						.datePickerStyle(.wheel)
						.labelsHidden()
						.frame(maxWidth: .infinity)
						.frame(height: 136)
						.clipped()
				}
				.padding(12)
				.background(
					RoundedRectangle(cornerRadius: 16, style: .continuous)
						.fill(Color(red: 0.20, green: 0.31, blue: 0.47).opacity(0.36))
						.overlay(
							RoundedRectangle(cornerRadius: 16, style: .continuous)
								.stroke(Color(red: 0.58, green: 0.74, blue: 0.92).opacity(0.26), lineWidth: 1)
						)
				)

				if let errorMessage {
					Text(errorMessage)
						.font(.system(size: 13, weight: .semibold, design: .rounded))
						.foregroundStyle(Color.red.opacity(0.95))
				}

				Spacer(minLength: 0)
			}
			.padding(.horizontal, 16)
			.padding(.top, 10)
			.background(
				LinearGradient(
					colors: [
						Color(red: 0.09, green: 0.16, blue: 0.26).opacity(0.94),
						Color(red: 0.08, green: 0.14, blue: 0.24).opacity(0.96)
					],
					startPoint: .topLeading,
					endPoint: .bottomTrailing
				)
				.ignoresSafeArea()
			)
			.navigationTitle("Add Sleep Log")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .topBarLeading) {
					Button("Cancel") {
						dismiss()
					}
					.foregroundStyle(Color.white.opacity(0.82))
				}
				ToolbarItem(placement: .topBarTrailing) {
					Button("Save") {
						saveAndDismiss()
					}
					.font(.system(size: 16, weight: .bold, design: .rounded))
					.disabled(!isInputValid)
				}
			}
			}
			.preferredColorScheme(.dark)
			.presentationDetents([.fraction(0.58)])
			.presentationDragIndicator(.visible)
			.onChange(of: startDate) { newStart in
			if endDate <= newStart {
				endDate = Calendar.current.date(byAdding: .minute, value: 30, to: newStart) ?? newStart
			}
		}
	}

	private var isInputValid: Bool {
		endDate > startDate
	}

	private func saveAndDismiss() {
		guard isInputValid else {
			errorMessage = "Wake time must be after sleep start."
			return
		}

		do {
			try onSave(startDate, endDate)
			dismiss()
		} catch let error as AddSleepLogError {
			switch error {
			case .invalidRange:
				errorMessage = "Wake time must be after sleep start."
			case .overlapsExisting:
				errorMessage = "This overlaps an existing sleep log. Delete or adjust that log first."
			}
		} catch {
			errorMessage = "Could not save this sleep log."
		}
	}
}

private struct BottomNavItem: View {
	enum Icon {
		case systemName(String)
		case tracker(TrackerKind)
	}

	let label: String
	let isActive: Bool
	let icon: Icon
	let onTap: () -> Void

	var body: some View {
		Button(action: onTap) {
			VStack(spacing: 2) {
				iconView
					.frame(height: 20, alignment: .center)

				Text(label)
					.font(.system(size: 11, weight: .semibold))
					.lineLimit(1)
					.minimumScaleFactor(0.64)
					.frame(height: 12, alignment: .center)
					.frame(maxWidth: .infinity)

				Capsule()
					.fill(isActive ? Color(red: 0.67, green: 0.86, blue: 1.0) : Color.clear)
					.frame(width: 16, height: 2)
			}
			.frame(maxWidth: .infinity, minHeight: 46)
			.foregroundStyle(isActive ? Color(red: 0.67, green: 0.86, blue: 1.0) : Color.white.opacity(0.62))
		}
		.buttonStyle(.plain)
	}

	@ViewBuilder
	private var iconView: some View {
		let tint = isActive ? Color(red: 0.67, green: 0.86, blue: 1.0) : Color.white.opacity(0.62)
		switch icon {
		case .systemName(let name):
			Image(systemName: name)
				.font(.system(size: 19, weight: .semibold))
				.foregroundStyle(tint)
		case .tracker(let tracker):
			TrackerGlyphIcon(tracker: tracker, size: 20, tint: tint)
		}
	}
}

private struct InsightRow: Identifiable {
	var id: Date { dayStart }
	let dayStart: Date
	let dateLabel: String
	let sleepStartLabel: String
	let sleepEndLabel: String
	let sleepHours: Double
	let zynCount: Int
	let notes: String
}

private struct InsightsHeaderRow: View {
	var body: some View {
		HStack(spacing: 0) {
			tableText("Date", width: 92, isHeader: true, alignment: .leading)
			tableText("Start", width: 88, isHeader: true)
			tableText("End", width: 88, isHeader: true)
			tableText("Hours", width: 74, isHeader: true)
			tableText("Zyn", width: 58, isHeader: true)
			tableText("Notes", width: 150, isHeader: true, alignment: .leading)
		}
		.padding(.vertical, 10)
		.background(Color.white.opacity(0.07))
	}

	private func tableText(_ text: String, width: CGFloat, isHeader: Bool, alignment: Alignment = .center) -> some View {
		Text(text)
			.font(.system(size: isHeader ? 14 : 13, weight: .semibold, design: .rounded))
			.foregroundStyle(Color.white.opacity(0.7))
			.frame(width: width, alignment: alignment)
	}
}

private struct InsightsDataRow: View {
	let row: InsightRow

	var body: some View {
		HStack(spacing: 0) {
			tableText(
				row.dateLabel,
				width: 92,
				alignment: .leading,
				color: row.dateLabel == "Today" ? .blue : .white,
				weight: row.dateLabel == "Today" ? .bold : .medium
			)
			tableText(row.sleepStartLabel, width: 88, color: Color.white.opacity(0.76))
			tableText(row.sleepEndLabel, width: 88, color: Color.white.opacity(0.76))
			tableText(String(format: "%.1fh", row.sleepHours), width: 74, color: .green, weight: .semibold)
			tableText("\(row.zynCount)", width: 58, color: .orange, weight: .semibold)
			tableText(row.notes.isEmpty ? "-" : row.notes, width: 150, alignment: .leading, color: Color.white.opacity(0.76))
		}
		.padding(.vertical, 11)
		.background(row.dateLabel == "Today" ? Color.blue.opacity(0.15) : Color.clear)
		.overlay(alignment: .bottom) {
			Rectangle()
				.fill(Color.white.opacity(0.06))
				.frame(height: 1)
		}
	}

	private func tableText(
		_ text: String,
		width: CGFloat,
		alignment: Alignment = .center,
		color: Color,
		weight: Font.Weight = .regular
	) -> some View {
		Text(text)
			.lineLimit(1)
			.font(.system(size: 13, weight: weight, design: .rounded))
			.foregroundStyle(color)
			.frame(width: width, alignment: alignment)
	}
}

#Preview {
	HomeView()
		.environmentObject(ZynSleepStore())
}
