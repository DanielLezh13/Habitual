import SwiftUI

@main
struct ZynSleepApp: App {
	@StateObject private var store = ZynSleepStore()

	var body: some Scene {
		WindowGroup {
			HomeView()
				.environmentObject(store)
		}
	}
}
