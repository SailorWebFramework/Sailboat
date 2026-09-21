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

    // MARK: - elementStates reverse index

    @Test("registerElement populates elementStates reverse index")
    func registerElementPopulatesReverseIndex() {
        let manager = makeManager()
        let stateA: StateID = 100
        let stateB: StateID = 101
        manager.managedPages.stateHistory = [stateA, stateB]
        let elem = TestElement(renderer: MockRenderable())
        manager.managedPages.registerElement(elem, List())
        // Recover the assigned SailboatID from statefulElements
        guard let sid = manager.managedPages.statefulElements[stateA]?.first else {
            Issue.record("statefulElements[stateA] should not be empty")
            return
        }
        #expect(manager.managedPages.elementStates[sid] == [stateA, stateB])
    }

    @Test("removeCache using reverse index removes element from all relevant states")
    func removeCacheReverseIndexConsistent() {
        let manager = makeManager()

        // Register 3 elements spanning 5 states
        // elem1 → states {1,2,3}
        manager.managedPages.stateHistory = [1, 2, 3]
        let elem1 = TestElement(renderer: MockRenderable())
        manager.managedPages.registerElement(elem1, List())

        // elem2 → states {2,3,4}
        manager.managedPages.stateHistory = [2, 3, 4]
        let elem2 = TestElement(renderer: MockRenderable())
        manager.managedPages.registerElement(elem2, List())

        // elem3 → states {4,5}
        manager.managedPages.stateHistory = [4, 5]
        let elem3 = TestElement(renderer: MockRenderable())
        manager.managedPages.registerElement(elem3, List())

        // Resolve SailboatIDs: elem1 owns the ID that appears in state 1 only
        guard let sid1 = manager.managedPages.statefulElements[1]?.first else {
            Issue.record("elem1 should be in state 1"); return
        }
        guard let sid3 = manager.managedPages.statefulElements[5]?.first else {
            Issue.record("elem3 should be in state 5"); return
        }

        // Remove elem1 via RenderableUtils
        RenderableUtils.removeCache(with: sid1)

        // elementStates[sid1] must be cleared
        #expect(manager.managedPages.elementStates[sid1] == nil)

        // sid1 must be absent from states 1, 2, 3
        #expect(!(manager.managedPages.statefulElements[1]?.contains(sid1) ?? false))
        #expect(!(manager.managedPages.statefulElements[2]?.contains(sid1) ?? false))
        #expect(!(manager.managedPages.statefulElements[3]?.contains(sid1) ?? false))

        // states 4 and 5 (not owned by elem1) must be untouched
        #expect(manager.managedPages.statefulElements[4] != nil)
        #expect(manager.managedPages.statefulElements[5]?.contains(sid3) == true)
    }

    @Test("removeCache does not touch states unrelated to the removed element")
    func removeCacheDoesNotTouchUnrelatedStates() {
        let manager = makeManager()

        // elemA → state 10 only
        manager.managedPages.stateHistory = [10]
        let elemA = TestElement(renderer: MockRenderable())
        manager.managedPages.registerElement(elemA, List())

        // elemB → state 20 only
        manager.managedPages.stateHistory = [20]
        let elemB = TestElement(renderer: MockRenderable())
        manager.managedPages.registerElement(elemB, List())

        guard let sidA = manager.managedPages.statefulElements[10]?.first else {
            Issue.record("elemA should be in state 10"); return
        }
        guard let sidB = manager.managedPages.statefulElements[20]?.first else {
            Issue.record("elemB should be in state 20"); return
        }

        // Remove elemA
        RenderableUtils.removeCache(with: sidA)

        // state 20 / elemB must be completely unaffected
        #expect(manager.managedPages.statefulElements[20]?.contains(sidB) == true)
        #expect(manager.managedPages.elementStates[sidB] == [20])

        // state 10 should be gone (no more elements)
        #expect(manager.managedPages.statefulElements[10] == nil)
    }

    @Test("removeCache removes empty state buckets from statefulElements")
    func removeCacheClearsEmptyStateBuckets() {
        let manager = makeManager()

        // Single element in state 99 — removing it should also remove the bucket
        manager.managedPages.stateHistory = [99]
        let elem = TestElement(renderer: MockRenderable())
        manager.managedPages.registerElement(elem, List())

        guard let sid = manager.managedPages.statefulElements[99]?.first else {
            Issue.record("element should be in state 99"); return
        }

        RenderableUtils.removeCache(with: sid)

        // The bucket for state 99 must be removed, not left as an empty Set
        #expect(manager.managedPages.statefulElements[99] == nil)
    }
}
