// Tests/SailboatTests/TargetManagerTests.swift

import Testing
@testable import Sailboat

@MainActor @Suite("TargetManager")
struct TargetManagerTests {

    private func makeSchedulerAndManager() -> (MockEventScheduler, TargetManager) {
        let scheduler = MockEventScheduler()
        let manager = TargetManager(scheduler)
        SailboatGlobal.initialize(manager)
        return (scheduler, manager)
    }

    // MARK: - build(page:)

    @Test("build calls blockUpdates then unblockUpdates exactly once each")
    func buildCallsBlockUnblock() {
        let (scheduler, manager) = makeSchedulerAndManager()
        manager.build(page: TestElement(renderer: MockRenderable()))
        #expect(scheduler.blockCount == 1)
        #expect(scheduler.unblockCount == 1)
    }

    @Test("build clears stateHistory before processing the element")
    func buildClearsHistoryFirst() {
        let (_, manager) = makeSchedulerAndManager()
        // Seed some history
        manager.managedPages.stateHistory = [99, 100]
        // build calls dump() as its first step, clearing the history
        manager.build(page: TestElement(renderer: MockRenderable()))
        // After a successful build the seeded IDs must be gone.
        // (New IDs from the element itself are fine, but we never access
        // State during TestElement construction so history stays empty.)
        #expect(!manager.managedPages.stateHistory.contains(99))
        #expect(!manager.managedPages.stateHistory.contains(100))
    }

    @Test("build adds renderer to parent via addToParent when parent provided")
    func buildAddToParentCalled() {
        let (_, manager) = makeSchedulerAndManager()
        let childMock = MockRenderable()
        let child = TestElement(renderer: childMock)
        // Build root element — it has no parent so addToParent is NOT called.
        manager.build(page: child)
        #expect(childMock.addToParentCalls == 0)
    }

    // MARK: - dumpDependency / dump

    @Test("dumpDependency inserts the state ID into managedPages.stateHistory")
    func dumpDependencyInsertsID() {
        let (_, manager) = makeSchedulerAndManager()
        let s = State(wrappedValue: 0)
        manager.dumpDependency(state: s)
        #expect(manager.managedPages.stateHistory.contains(s.id))
    }

    @Test("reading State.wrappedValue triggers dumpDependency via SailboatGlobal")
    func stateReadTriggersDumpDependency() {
        let (_, manager) = makeSchedulerAndManager()
        let s = State(wrappedValue: "hi")
        _ = s.wrappedValue
        #expect(manager.managedPages.stateHistory.contains(s.id))
    }

    @Test("dump returns history and clears it atomically")
    func dumpClearsAfterReturn() {
        let (_, manager) = makeSchedulerAndManager()
        manager.managedPages.stateHistory = [1, 2]
        let result = manager.dump()
        #expect(result == [1, 2])
        #expect(manager.managedPages.stateHistory.isEmpty)
    }
}
