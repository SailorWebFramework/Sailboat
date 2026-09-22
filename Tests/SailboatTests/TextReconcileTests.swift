// Tests/SailboatTests/TextReconcileTests.swift
//
// Text children are snapshotted with their rendered value so a re-render only
// touches the renderer when the text actually changed.

import Testing
@testable import Sailboat

@MainActor @Suite("TextReconcile")
struct TextReconcileTests {

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

    @Test("text children are snapshotted as .text with their rendered value")
    func snapshotIsText() {
        let (_, manager) = makeManager()
        let s = State(wrappedValue: "hi")
        let root = MockRenderable()
        let textRenderer = MockRenderable()
        var elem = TestElement(renderer: root)
        elem.content = { List([TestValueElement(s.wrappedValue, renderer: textRenderer)], hash: "") }
        manager.build(page: elem)

        guard let sid = root.sailboatID, case .text(let renderer, let value)? = manager.managedPages.children[sid]?.children.first else {
            Issue.record("expected a .text node"); return
        }
        #expect(renderer as AnyObject === textRenderer)
        #expect(value == "hi")
    }

    @Test("a re-render that leaves the text unchanged does not touch the renderer")
    func unchangedTextSkipsReplace() {
        let (scheduler, manager) = makeManager()
        let tick = State(wrappedValue: 0)
        let root = MockRenderable()
        var elem = TestElement(renderer: root)
        elem.content = {
            _ = tick.wrappedValue
            return List([TestValueElement("same", renderer: MockRenderable())], hash: "")
        }
        manager.build(page: elem)

        tick.wrappedValue = 1
        flush(manager, scheduler)

        #expect(root.replaceAtCalls.isEmpty)
    }

    @Test("changed text is replaced at its deep index and the snapshot takes the new value")
    func changedTextReplaced() {
        let (scheduler, manager) = makeManager()
        let s = State(wrappedValue: "a")
        let root = MockRenderable()
        var elem = TestElement(renderer: root)
        elem.content = {
            List([TestElement(renderer: MockRenderable()), TestValueElement(s.wrappedValue, renderer: MockRenderable())], hash: "")
        }
        manager.build(page: elem)
        guard let sid = root.sailboatID else { Issue.record("missing sid"); return }

        s.wrappedValue = "b"
        flush(manager, scheduler)

        #expect(root.replaceAtCalls.map { $0.0 } == [1])
        guard case .text(_, let value)? = manager.managedPages.children[sid]?.children.last else {
            Issue.record("expected a .text node"); return
        }
        #expect(value == "b")
    }

    @Test("only the texts that changed are replaced among several")
    func partialTextChange() {
        let (scheduler, manager) = makeManager()
        let a = State(wrappedValue: "a"), b = State(wrappedValue: "b")
        let root = MockRenderable()
        var elem = TestElement(renderer: root)
        elem.content = {
            List([
                TestValueElement(a.wrappedValue, renderer: MockRenderable()),
                TestValueElement(b.wrappedValue, renderer: MockRenderable())
            ], hash: "")
        }
        manager.build(page: elem)

        b.wrappedValue = "B"
        flush(manager, scheduler)

        #expect(root.replaceAtCalls.map { $0.0 } == [1])
    }

    @Test("clearing a conditional removes its text renderers")
    func clearRemovesText() {
        let (scheduler, manager) = makeManager()
        let gate = State(wrappedValue: true)
        let root = MockRenderable()
        let textRenderer = MockRenderable()
        var elem = TestElement(renderer: root)
        elem.content = {
            let branch: any Fragment = gate.wrappedValue
                ? List([TestValueElement("t", renderer: textRenderer)], hash: "on")
                : List([], hash: "off")
            return List([branch], hash: "")
        }
        manager.build(page: elem)

        gate.wrappedValue = false
        flush(manager, scheduler)

        #expect(textRenderer.removeCalls == 1)
    }
}
