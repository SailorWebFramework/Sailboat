// Tests/SailboatTests/UpdatePassTests.swift
//
// One update pass must do each piece of work once, however many of the signals
// it reads changed in that frame. Before this, `update()` walked the changed
// states and re-rendered every dependent of each, so an element reading N
// signals that all changed ran its body N times.

import Testing
@testable import Sailboat

@MainActor @Suite("UpdatePass")
struct UpdatePassTests {

    private func makeManager() -> (MockEventScheduler, TargetManager) {
        let scheduler = MockEventScheduler()
        let manager = TargetManager(scheduler)
        SailboatGlobal.initialize(manager)
        return (scheduler, manager)
    }

    private func flush(_ manager: TargetManager, _ scheduler: MockEventScheduler) {
        manager.update()
        scheduler.states.removeAll()
    }

    @Test("a body reading two changed signals runs once per frame, not once per signal")
    func bodyRendersOncePerFrame() {
        let (scheduler, manager) = makeManager()
        let a = State(wrappedValue: "a")
        let b = State(wrappedValue: "b")
        let root = MockRenderable()
        var bodyRuns = 0

        var elem = TestElement(renderer: root)
        elem.content = {
            bodyRuns += 1
            return List([TestValueElement(a.wrappedValue + b.wrappedValue, renderer: MockRenderable())], hash: "")
        }
        manager.build(page: elem)
        #expect(bodyRuns == 1)

        // both signals change before the frame is flushed
        a.wrappedValue = "A"
        b.wrappedValue = "B"
        flush(manager, scheduler)

        #expect(bodyRuns == 2)
        // and the one render it did saw both new values
        #expect(root.replaceAtCalls.count == 1)
    }

    @Test("an attribute reading two changed signals is rendered once per frame")
    func attributeRendersOncePerFrame() {
        let (scheduler, manager) = makeManager()
        let hue = State(wrappedValue: "red")
        let weight = State(wrappedValue: "bold")
        let root = MockRenderable()

        var elem = TestElement(renderer: root)
        elem.attributes["style"] = { TestAttributeValue(hue.wrappedValue + " " + weight.wrappedValue) }
        manager.build(page: elem)
        #expect(root.updatedAttributes.count == 1)

        hue.wrappedValue = "blue"
        weight.wrappedValue = "light"
        flush(manager, scheduler)

        #expect(root.updatedAttributes.map { $0.value.description } == ["red bold", "blue light"])
    }

    @Test("two elements sharing one changed signal both still render")
    func dedupeIsPerElement() {
        let (scheduler, manager) = makeManager()
        let shared = State(wrappedValue: "x")
        let rootA = MockRenderable()
        let rootB = MockRenderable()
        var runsA = 0
        var runsB = 0

        var elemA = TestElement(renderer: rootA)
        elemA.content = {
            runsA += 1
            return List([TestValueElement(shared.wrappedValue, renderer: MockRenderable())], hash: "")
        }
        var elemB = TestElement(renderer: rootB)
        elemB.content = {
            runsB += 1
            return List([TestValueElement(shared.wrappedValue, renderer: MockRenderable())], hash: "")
        }
        manager.build(page: elemA)
        manager.build(page: elemB)

        shared.wrappedValue = "y"
        flush(manager, scheduler)

        #expect(runsA == 2)
        #expect(runsB == 2)
    }

    @Test("registerElement records the body without building a provisional snapshot")
    func noProvisionalSnapshot() {
        let (_, manager) = makeManager()
        let text = State(wrappedValue: "x")
        let root = MockRenderable()
        var elem = TestElement(renderer: root)
        elem.content = { List([TestValueElement(text.wrappedValue, renderer: MockRenderable())], hash: "") }

        // seed the state history the way running a body closure would
        manager.dumpDependency(state: text)
        manager.managedPages.registerElement(elem)

        guard let sid = root.sailboatID else {
            Issue.record("registerElement should have assigned a sailboatID"); return
        }
        #expect(manager.managedPages.bodies[sid] != nil)
        // the snapshot is written by RenderableUtils.build once the children exist
        #expect(manager.managedPages.children[sid] == nil)
    }

    @Test("the snapshot after a full build is the one build produced")
    func buildWritesTheSnapshot() {
        let (_, manager) = makeManager()
        let text = State(wrappedValue: "x")
        let root = MockRenderable()
        var elem = TestElement(renderer: root)
        elem.content = { List([TestValueElement(text.wrappedValue, renderer: MockRenderable())], hash: "") }

        manager.build(page: elem)

        guard let sid = root.sailboatID, let snapshot = manager.managedPages.children[sid] else {
            Issue.record("build should have stored a snapshot"); return
        }
        #expect(snapshot.children.count == 1)
        guard case .text(_, let value) = snapshot.children[0] else {
            Issue.record("expected a text node"); return
        }
        #expect(value == "x")
    }
}
