import SwiftUI

struct SevenDayTimelineView: View {
	@EnvironmentObject private var store: ZynSleepStore
	let referenceDate: Date

	private let calendar = Calendar.current

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack {
				Text("Last 7 days")
					.font(.headline)
				Spacer()
				legend
			}

			VStack(spacing: 10) {
				ForEach(dayStarts, id: \.self) { dayStart in
					DayTimelineRow(dayStart: dayStart, referenceDate: referenceDate)
				}
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding()
		.background(.thinMaterial)
		.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
	}

	private var legend: some View {
		HStack(spacing: 10) {
			HStack(spacing: 4) {
				RoundedRectangle(cornerRadius: 3, style: .continuous)
					.fill(.blue.opacity(0.25))
					.frame(width: 14, height: 10)
				Text("Sleep")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			HStack(spacing: 4) {
				Circle()
					.fill(.orange)
					.frame(width: 7, height: 7)
				Text("Zyn")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
		}
	}

	private var dayStarts: [Date] {
		let todayStart = calendar.startOfDay(for: referenceDate)
		return (0..<7).compactMap { offset in
			calendar.date(byAdding: .day, value: -offset, to: todayStart)
		}
	}

	private struct DayTimelineRow: View {
		@EnvironmentObject private var store: ZynSleepStore
		let dayStart: Date
		let referenceDate: Date

		private let calendar = Calendar.current

		var body: some View {
			HStack(spacing: 10) {
				Text(dayLabel(for: dayStart))
					.font(.caption)
					.foregroundStyle(.secondary)
					.frame(width: 44, alignment: .leading)

				GeometryReader { geo in
					let width = geo.size.width
					let height: CGFloat = 18
					ZStack(alignment: .leading) {
						RoundedRectangle(cornerRadius: 6, style: .continuous)
							.fill(.gray.opacity(0.15))
							.frame(height: height)

						ForEach(Array(sleepSegments(for: dayStart).enumerated()), id: \.offset) { _, segment in
							RoundedRectangle(cornerRadius: 6, style: .continuous)
								.fill(.blue.opacity(0.25))
								.frame(width: max(1, (segment.upperBound - segment.lowerBound) * width), height: height)
								.offset(x: segment.lowerBound * width)
						}

						ForEach(zynDots(for: dayStart), id: \.event.id) { dot in
							Circle()
								.fill(.orange)
								.frame(width: 7, height: 7)
								.offset(x: min(max(0, dot.fraction * width - 3.5), width - 7))
						}
					}
				}
				.frame(height: 18)
			}
		}

		private func dayLabel(for date: Date) -> String {
			if calendar.isDateInToday(date) { return "Today" }
			let fmt = DateFormatter()
			fmt.locale = .current
			fmt.setLocalizedDateFormatFromTemplate("E")
			return fmt.string(from: date)
		}

		private func sleepSegments(for dayStart: Date) -> [ClosedRange<Double>] {
			let intervals = store.sleepIntervalsOverlapping(dayStart: dayStart)
			return intervals.compactMap { interval in
				guard let secondsInDay = calendar.date(byAdding: .day, value: 1, to: dayStart)?.timeIntervalSince(dayStart) else {
					return nil
				}
				let startSeconds = interval.start.timeIntervalSince(dayStart)
				let endSeconds = interval.end.timeIntervalSince(dayStart)
				let lower = max(0, min(1, startSeconds / secondsInDay))
				let upper = max(0, min(1, endSeconds / secondsInDay))
				if upper <= lower { return nil }
				return lower...upper
			}
		}

		private func zynDots(for dayStart: Date) -> [(event: ZynEvent, fraction: Double)] {
			let zyns = store.zynEvents(inDayStarting: dayStart)
			guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
			let dayLength = dayEnd.timeIntervalSince(dayStart)
			guard dayLength > 0 else { return [] }
			return zyns.compactMap { event in
				guard !store.isAsleep(at: event.timestamp) else { return nil }
				let seconds = event.timestamp.timeIntervalSince(dayStart)
				let fraction = seconds / dayLength
				guard fraction.isFinite else { return nil }
				return (event: event, fraction: max(0, min(1, fraction)))
			}
		}
	}
}

#Preview {
	SevenDayTimelineView(referenceDate: .init())
		.environmentObject(ZynSleepStore())
		.padding()
}
