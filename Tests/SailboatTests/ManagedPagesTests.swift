// Tests/SailboatTests/ManagedPagesTests.swift

import Testing
@testable import Sailboat

@MainActor @Suite("ManagedPages")
struct ManagedPagesTests {

    private func makeManager() -> TargetManager {
        let manager = TargetManager(MockEventScheduler())
        SailboatGlobal.initialize(manager)
        return manager
    }

    // MARK: - dump

    @Test("dump returns a copy of stateHistory and then clears it")
    func dumpClearsHistory() {
        let manager = makeManager()
        manager.managedPages.stateHistory = [1, 2, 3]
        let dumped = manager.dump()
        #expect(dumped == [1, 2, 3])
        #expect(manager.managedPages.stateHistory.isEmpty)
    }

    @Test("dump called twice returns empty set the second time")
    func dumpTwiceSecondEmpty() {
        let manager = makeManager()
        manager.managedPages.stateHistory = [7]
        _ = manager.dump()
        let second = manager.dump()
        #expect(second.isEmpty)
    }

    // MARK: - dumpDependency

    @Test("dumpDependency inserts state ID into stateHistory")
    func dumpDependencyInsertsID() {
        let manager = makeManager()
        let s = State(wrappedValue: 0)
        manager.dumpDependency(state: s)
        #expect(manager.managedPages.stateHistory.contains(s.id))
    }

    @Test("reading State.wrappedValue calls dumpDependency automatically")
    func stateReadTriggersDumpDependency() {
        let manager = makeManager()
        let s = State(wrappedValue: 42)
        _ = s.wrappedValue    // should call manager.dumpDependency(state: s)
        #expect(manager.managedPages.stateHistory.contains(s.id))
    }

    // MARK: - registerElement

    @Test("registerElement is a no-op when stateHistory is empty")
    func registerElementSkipsWhenNoStates() {
        let manager = makeManager()
        // stateHistory is empty — registerElement should bail early
        let elem = TestElement(renderer: MockRenderable())
        let op = List()
        manager.managedPages.registerElement(elem, op)
        #expect(manager.managedPages.bodies.isEmpty)
        #expect(manager.managedPages.renderers.isEmpty)
    }

    @Test("registerElement stores body, children, and renderer when states are present")
    func registerElementStoresWhenStatesPresent() {
        let manager = makeManager()
        // Seed the stateHistory so registerElement doesn't bail
        manager.managedPages.stateHistory = [42]
        let mock = MockRenderable()
        let elem = TestElement(renderer: mock)
        let op = List()
        manager.managedPages.registerElement(elem, op)
        #expect(!manager.managedPages.bodies.isEmpty)
        #expect(!manager.managedPages.renderers.isEmpty)
    }

    @Test("registerElement links element to the seeded state ID")
    func registerElementLinksState() {
        let manager = makeManager()
        let stateID: StateID = 77
        manager.managedPages.stateHistory = [stateID]
        let elem = TestElement(renderer: MockRenderable())
        manager.managedPages.registerElement(elem, List())
        #expect(manager.managedPages.statefulElements[stateID] != nil)
        #expect(!(manager.managedPages.statefulElements[stateID]?.isEmpty ?? true))
    }
}
