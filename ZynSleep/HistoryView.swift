import SwiftUI

struct HistoryView: View {
	@EnvironmentObject private var store: ZynSleepStore

	var body: some View {
		List {
			Section("Sleep events") {
				if store.sleepEvents.isEmpty {
					Text("No sleep events yet.")
						.foregroundStyle(.secondary)
				} else {
					ForEach(store.sleepEvents.sorted(by: { $0.start > $1.start })) { event in
						VStack(alignment: .leading, spacing: 4) {
							Text("Start: \(event.start.formatted(date: .abbreviated, time: .standard))")
								.monospacedDigit()
							if let end = event.end {
								Text("End: \(end.formatted(date: .abbreviated, time: .standard))")
									.monospacedDigit()
									.foregroundStyle(.secondary)
							} else {
								Text("End: (ongoing)")
									.foregroundStyle(.secondary)
							}
						}
						.padding(.vertical, 4)
					}
				}
			}

			Section("Zyn events") {
				if store.zynEvents.isEmpty {
					Text("No zyn events yet.")
						.foregroundStyle(.secondary)
				} else {
					ForEach(store.zynEvents.sorted(by: { $0.timestamp > $1.timestamp })) { event in
						NavigationLink {
							ZynEventDetailView(zynId: event.id)
						} label: {
							VStack(alignment: .leading, spacing: 4) {
								Text(event.timestamp.formatted(date: .abbreviated, time: .standard))
									.monospacedDigit()
								if let note = event.note, !note.isEmpty {
									Text(note)
										.foregroundStyle(.secondary)
										.lineLimit(2)
								} else {
									Text("No note")
										.foregroundStyle(.secondary)
								}
							}
							.padding(.vertical, 4)
						}
					}
				}
			}
		}
		.navigationTitle("History")
	}
}

private struct ZynEventDetailView: View {
	@EnvironmentObject private var store: ZynSleepStore
	let zynId: UUID

	@State private var noteText: String = ""

	var body: some View {
		Form {
			if let event = store.zynEvents.first(where: { $0.id == zynId }) {
				Section("Timestamp") {
					Text(event.timestamp.formatted(date: .abbreviated, time: .standard))
						.monospacedDigit()
				}
			} else {
				Section {
					Text("Event not found.")
						.foregroundStyle(.secondary)
				}
			}

			Section("Note") {
				TextField("Optional note", text: $noteText, axis: .vertical)
					.lineLimit(3, reservesSpace: true)
			}
		}
		.navigationTitle("Zyn")
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				Button("Save") {
					store.updateZynNote(zynId: zynId, note: noteText)
				}
				.disabled(store.zynEvents.first(where: { $0.id == zynId }) == nil)
			}
		}
		.onAppear {
			noteText = store.zynEvents.first(where: { $0.id == zynId })?.note ?? ""
		}
	}
}

#Preview {
	NavigationStack { HistoryView() }
		.environmentObject(ZynSleepStore())
}

