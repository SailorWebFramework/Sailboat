// Tests/SailboatTests/Mocks/MockEventScheduler.swift
//
// A test-double EventScheduler that records every call made to it.

import Testing
@testable import Sailboat

/// Records all interactions so tests can assert on observed state IDs,
/// block/unblock counts, and update calls.
@MainActor
final class MockEventScheduler: EventScheduler {

    // Protocol requirement — the set of state IDs the scheduler has seen.
    var states: Set<StateID> = []

    // Ordered log of state IDs passed to observe().
    var observedStateIDs: [StateID] = []

    // How many times blockUpdates() / unblockUpdates() were called.
    var blockCount: Int = 0
    var unblockCount: Int = 0

    // How many times update() was called.
    var updateCount: Int = 0

    func registerEvent() { }

    func observe(state: some Stateful) {
        states.insert(state.id)
        observedStateIDs.append(state.id)
    }

    func blockUpdates() {
        blockCount += 1
    }

    func unblockUpdates() {
        unblockCount += 1
    }

    func update() {
        updateCount += 1
    }
}
