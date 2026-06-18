import Foundation
import SwiftUI

@Observable
final class AppState {
    var selectedTab: Tab = .dump
    var searchQuery = ""
    var counts: [String: Int] = [:]

    enum Tab: Hashable {
        case dump, items, tags, docs, guide
    }

    func refreshCounts() {
        Task {
            do {
                let final = try Queries.getCategoryCounts()
                await MainActor.run { self.counts = final }
            } catch {}
        }
    }
}
