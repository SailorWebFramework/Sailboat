// Tests/SailboatTests/RafBlockingTests.swift
//
// Regression tests for Design 006 Option 1 — rAF re-entrancy guard.
//
// WebEventScheduler (SailorWeb, WASI-only) cannot be imported here, so we use a
// TestBlockingScheduler that replicates its blocking contract without the JS runtime.
// These tests verify the two invariants that make Option 1 correct:
//
//   1. update() is a no-op when areUpdatesBlocked is true.
//   2. observe() during a blocked reconcile tracks state IDs into pendingStates so
//      the follow-up rAF can flush them.

import Testing
@testable import Sailboat

// MARK: - TestBlockingScheduler

/// A concrete EventScheduler that mirrors the blocking logic of WebEventScheduler
/// (Design 006 Option 1), minus the JS requestAnimationFrame calls.
///
/// In tests, call `simulateRafCallback(duringUpdate:)` instead of waiting for a real
/// rAF to fire. The `duringUpdate` closure injects re-entrant calls (simulating
/// synchronous onAppear dispatch during reconcile).
@MainActor
private final class TestBlockingScheduler: EventScheduler {

    var states: Set<StateID> = []
    var pendingStates: Set<StateID> = []
    var areUpdatesBlocked: Bool = false
    var updateFrame: Bool = false

    // How many times manager.update() would have been called (immediate path only).
    var immediateManagerUpdateCount: Int = 0

    func registerEvent() { updateFrame = true }

    func observe(state: some Stateful) {
        states.insert(state.id)
        if areUpdatesBlocked {
            pendingStates.insert(state.id)
        }
    }

    func blockUpdates() { areUpdatesBlocked = true }
    func unblockUpdates() { areUpdatesBlocked = false }

    func update() {
        if areUpdatesBlocked || states.isEmpty { return }
        blockUpdates()
        if updateFrame {
            // Immediate path — just count; tests drive reconcile explicitly.
            immediateManagerUpdateCount += 1
            states = []
        }
        // Lazy (rAF) path: tests call simulateRafCallback() manually.
        updateFrame = false
        unblockUpdates()
    }

    /// Simulates the rAF callback body as implemented in WebEventScheduler (Option 1).
    /// Returns the set of pending states captured during the blocked reconcile.
    ///
    /// - Parameter duringUpdate: Closure run in place of `SailboatGlobal.manager.update()`.
    ///   Inject re-entrant calls here (e.g. simulate an onAppear firing).
    @discardableResult
    func simulateRafCallback(duringUpdate: () -> Void = {}) -> Set<StateID> {
        pendingStates = []
        blockUpdates()
        duringUpdate()           // stands in for SailboatGlobal.manager.update()
        let pending = pendingStates
        states = []
        unblockUpdates()
        return pending
    }
}

// MARK: - Tests

@MainActor @Suite("RafBlocking (Design 006 Option 1)")
struct RafBlockingTests {

    // MARK: - Invariant 1: update() is blocked during rAF reconcile

    @Test("update() is a no-op when areUpdatesBlocked is true")
    func updateIsNoOpWhenBlocked() {
        let scheduler = TestBlockingScheduler()
        SailboatGlobal.initialize(TargetManager(scheduler))

        let s = State(wrappedValue: 0)
        scheduler.observe(state: s)       // seed states = {s.id}
        #expect(scheduler.states.contains(s.id))

        // Simulate rAF callback blocking updates.
        scheduler.blockUpdates()
        scheduler.update()                // should return early — areUpdatesBlocked == true

        // States must be preserved (re-entrant update() must NOT clear them).
        #expect(scheduler.states.contains(s.id), "states preserved when update() is blocked")
        // manager.update() must NOT have been called via the re-entrant path.
        #expect(scheduler.immediateManagerUpdateCount == 0,
                "manager.update() not called via re-entrant update()")
    }

    // MARK: - Invariant 2: observe() during blocked reconcile populates pendingStates

    @Test("observe() while blocked tracks state into pendingStates for follow-up rAF")
    func observeDuringBlockPopulatesPendingStates() {
        let scheduler = TestBlockingScheduler()
        SailboatGlobal.initialize(TargetManager(scheduler))

        let s = State(wrappedValue: false)

        // Simulate the rAF callback: during reconcile an onAppear fires and changes s.
        let pending = scheduler.simulateRafCallback {
            // This models: onAppear fires synchronously during reconcile,
            // sets s.wrappedValue, which calls observe(state: s).
            scheduler.observe(state: s)
            // The re-entrant update() call is blocked:
            scheduler.update()  // no-op — areUpdatesBlocked == true
        }

        // pending must contain s.id so the follow-up rAF can reconcile the new value.
        #expect(pending.contains(s.id),
                "onAppear-triggered state captured in pendingStates for follow-up rAF")

        // Main states must be cleared (outer reconcile pass is complete).
        #expect(scheduler.states.isEmpty,
                "states cleared after rAF callback completes")

        // areUpdatesBlocked must be false after the callback (unblockUpdates called).
        #expect(!scheduler.areUpdatesBlocked,
                "updates unblocked after rAF callback")
    }
}
