// Tests/SailboatTests/EventSchedulerTests.swift

import Testing
@testable import Sailboat

@MainActor @Suite("EventScheduler")
struct EventSchedulerTests {

    @Test("observe inserts state ID into states set")
    func observeInsertsID() {
        let scheduler = MockEventScheduler()
        SailboatGlobal.initialize(TargetManager(scheduler))
        let s = State(wrappedValue: 0)
        scheduler.observe(state: s)
        #expect(scheduler.states.contains(s.id))
    }

    @Test("observe accumulates multiple state IDs")
    func observeAccumulates() {
        let scheduler = MockEventScheduler()
        SailboatGlobal.initialize(TargetManager(scheduler))
        let s1 = State(wrappedValue: 0)
        let s2 = State(wrappedValue: 0)
        scheduler.observe(state: s1)
        scheduler.observe(state: s2)
        #expect(scheduler.states.count == 2)
        #expect(scheduler.states.contains(s1.id))
        #expect(scheduler.states.contains(s2.id))
    }

    @Test("observe appends to observedStateIDs in call order")
    func observeOrder() {
        let scheduler = MockEventScheduler()
        SailboatGlobal.initialize(TargetManager(scheduler))
        let s1 = State(wrappedValue: "a")
        let s2 = State(wrappedValue: "b")
        scheduler.observe(state: s1)
        scheduler.observe(state: s2)
        #expect(scheduler.observedStateIDs.first == s1.id)
        #expect(scheduler.observedStateIDs.last == s2.id)
    }

    @Test("blockUpdates increments blockCount")
    func blockUpdatesCount() {
        let scheduler = MockEventScheduler()
        scheduler.blockUpdates()
        scheduler.blockUpdates()
        #expect(scheduler.blockCount == 2)
    }

    @Test("unblockUpdates increments unblockCount")
    func unblockUpdatesCount() {
        let scheduler = MockEventScheduler()
        scheduler.unblockUpdates()
        #expect(scheduler.unblockCount == 1)
    }

    @Test("update increments updateCount")
    func updateCount() {
        let scheduler = MockEventScheduler()
        scheduler.update()
        scheduler.update()
        #expect(scheduler.updateCount == 2)
    }

    @Test("state mutation routes observe through the scheduler")
    func stateMutationRoutesToScheduler() {
        let scheduler = MockEventScheduler()
        SailboatGlobal.initialize(TargetManager(scheduler))
        let s = State(wrappedValue: 0)
        s.wrappedValue = 1    // triggers observe(state:)
        #expect(scheduler.observedStateIDs.contains(s.id))
    }
}
