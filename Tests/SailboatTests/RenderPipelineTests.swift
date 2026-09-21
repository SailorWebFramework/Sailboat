// Tests/SailboatTests/RenderPipelineTests.swift
//
// End-to-end tests of the reactive render loop:
//
//   build(page:) → State mutation → scheduler.observe → TargetManager.update()
//   → renderer.reconcile(with:) → Renderable calls (replace / insert / remove)
//
// These drive the real TargetManager, ManagedPages, Renderable+Build and
// Renderable+Reconcile code; only the Renderable sink is mocked.

import Testing
@testable import Sailboat

@MainActor @Suite("RenderPipeline")
struct RenderPipelineTests {

    private func makeManager() -> (MockEventScheduler, TargetManager) {
        let scheduler = MockEventScheduler()
        let manager = TargetManager(scheduler)
        SailboatGlobal.initialize(manager)
        return (scheduler, manager)
    }

    /// Runs one update pass and clears the scheduler's pending states, the way a
    /// real scheduler does once a frame has been flushed.
    private func flush(_ manager: TargetManager, _ scheduler: MockEventScheduler) {
        manager.update()
        scheduler.states.removeAll()
    }

    // MARK: - Registration

    @Test("element whose body reads no State is not registered as stateful")
    func staticBodyNotRegistered() {
        let (_, manager) = makeManager()
        let root = MockRenderable()
        var elem = TestElement(renderer: root)
        elem.content = { List([TestValueElement("static", renderer: MockRenderable())], hash: "") }

        manager.build(page: elem)

        #expect(root.sailboatID == nil)
        #expect(manager.managedPages.bodies.isEmpty)
        #expect(manager.managedPages.statefulElements.isEmpty)
    }

    @Test("element whose body reads a State is registered against that State")
    func statefulBodyRegistered() {
        let (_, manager) = makeManager()
        let text = State(wrappedValue: "a")
        let root = MockRenderable()
        var elem = TestElement(renderer: root)
        elem.content = { List([TestValueElement(text.wrappedValue, renderer: MockRenderable())], hash: "") }

        manager.build(page: elem)

        guard let sid = root.sailboatID else {
            Issue.record("root should have been assigned a sailboatID"); return
        }
        #expect(manager.managedPages.statefulElements[text.id] == [sid])
        #expect(manager.managedPages.elementStates[sid] == [text.id])
        #expect(manager.managedPages.renderers[sid] != nil)
        #expect(manager.managedPages.bodies[sid] != nil)
        #expect(manager.managedPages.children[sid] != nil)
    }

    // MARK: - ValueElement replacement

    @Test("changing a State read by a text child replaces that child in place")
    func valueElementReplaced() {
        let (scheduler, manager) = makeManager()
        let text = State(wrappedValue: "before")
        let root = MockRenderable()
        var elem = TestElement(renderer: root)
        elem.content = { List([TestValueElement(text.wrappedValue, renderer: MockRenderable())], hash: "") }
        manager.build(page: elem)

        text.wrappedValue = "after"
        flush(manager, scheduler)

        #expect(root.replaceAtCalls.count == 1)
        #expect(root.replaceAtCalls.first?.0 == 0)
        // a same-shape update must not touch structure
        #expect(root.insertBeforeCalls.isEmpty)
        #expect(root.insertAfterCalls.isEmpty)
        #expect(root.removeAtCalls.isEmpty)
    }

    @Test("replacement targets the correct deep index among siblings")
    func valueElementReplacedAtCorrectIndex() {
        let (scheduler, manager) = makeManager()
        let text = State(wrappedValue: "x")
        let root = MockRenderable()
        var elem = TestElement(renderer: root)
        elem.content = {
            List([
                TestElement(renderer: MockRenderable()),                        // deep index 0
                TestValueElement(text.wrappedValue, renderer: MockRenderable()) // deep index 1
            ], hash: "")
        }
        manager.build(page: elem)

        text.wrappedValue = "y"
        flush(manager, scheduler)

        #expect(root.replaceAtCalls.map { $0.0 } == [1])
    }

    @Test("the stored children snapshot is updated to the newly rendered fragment")
    func childrenSnapshotUpdated() {
        let (scheduler, manager) = makeManager()
        let text = State(wrappedValue: "before")
        let root = MockRenderable()
        var elem = TestElement(renderer: root)
        elem.content = { List([TestValueElement(text.wrappedValue, renderer: MockRenderable())], hash: "") }
        manager.build(page: elem)
        guard let sid = root.sailboatID else { Issue.record("missing sailboatID"); return }

        text.wrappedValue = "after"
        flush(manager, scheduler)

        let snapshot = manager.managedPages.children[sid]?.children.first as? TestValueElement
        #expect(snapshot?.value == "after")
    }

    @Test("updating a State with no dependents issues no renderer calls")
    func unrelatedStateIsNoOp() {
        let (scheduler, manager) = makeManager()
        let text = State(wrappedValue: "a")
        let other = State(wrappedValue: 0)
        let root = MockRenderable()
        var elem = TestElement(renderer: root)
        elem.content = { List([TestValueElement(text.wrappedValue, renderer: MockRenderable())], hash: "") }
        manager.build(page: elem)

        other.wrappedValue = 1
        flush(manager, scheduler)

        #expect(root.replaceAtCalls.isEmpty)
    }

    // MARK: - Conditional fragments

    @Test("toggling a conditional on inserts the new element before index 0")
    func conditionalInsert() {
        let (scheduler, manager) = makeManager()
        let toggle = State(wrappedValue: false)
        let root = MockRenderable()
        let child = MockRenderable()
        var elem = TestElement(renderer: root)
        elem.content = {
            let inner: any Fragment = toggle.wrappedValue
                ? List([TestElement(renderer: child)], hash: "on")
                : List([], hash: "off")
            return List([inner], hash: "")
        }
        manager.build(page: elem)
        #expect(child.insertBeforeCalls.isEmpty)

        toggle.wrappedValue = true
        flush(manager, scheduler)

        #expect(child.insertBeforeCalls == [0])
        #expect(child.insertAfterCalls.isEmpty)
    }

    @Test("toggling a conditional off removes the previously rendered element")
    func conditionalRemove() {
        let (scheduler, manager) = makeManager()
        let toggle = State(wrappedValue: true)
        let root = MockRenderable()
        let child = MockRenderable()
        var elem = TestElement(renderer: root)
        elem.content = {
            let inner: any Fragment = toggle.wrappedValue
                ? List([TestElement(renderer: child)], hash: "on")
                : List([], hash: "off")
            return List([inner], hash: "")
        }
        manager.build(page: elem)
        #expect(child.addToParentCalls == 1)
        #expect(child.removeCalls == 0)

        toggle.wrappedValue = false
        flush(manager, scheduler)

        #expect(child.removeCalls == 1)
    }

    @Test("a conditional after a static sibling is inserted after that sibling's index")
    func conditionalInsertAfterSibling() {
        let (scheduler, manager) = makeManager()
        let toggle = State(wrappedValue: false)
        let root = MockRenderable()
        let child = MockRenderable()
        var elem = TestElement(renderer: root)
        elem.content = {
            let inner: any Fragment = toggle.wrappedValue
                ? List([TestElement(renderer: child)], hash: "on")
                : List([], hash: "off")
            return List([TestElement(renderer: MockRenderable()), inner], hash: "")
        }
        manager.build(page: elem)

        toggle.wrappedValue = true
        flush(manager, scheduler)

        #expect(child.insertAfterCalls == [0])
        #expect(child.insertBeforeCalls.isEmpty)
    }

    @Test("a re-render with an unchanged conditional hash reuses the existing renderers")
    func unchangedHashReusesRenderers() {
        let (scheduler, manager) = makeManager()
        let toggle = State(wrappedValue: true)
        let tick = State(wrappedValue: 0)
        let root = MockRenderable()
        let child = MockRenderable()
        var elem = TestElement(renderer: root)
        elem.content = {
            _ = tick.wrappedValue   // unrelated dependency that forces a re-render
            let inner: any Fragment = toggle.wrappedValue
                ? List([TestElement(renderer: child)], hash: "on")
                : List([], hash: "off")
            return List([inner], hash: "")
        }
        manager.build(page: elem)

        tick.wrappedValue = 1
        flush(manager, scheduler)

        #expect(child.insertBeforeCalls.isEmpty)
        #expect(child.insertAfterCalls.isEmpty)
        #expect(child.removeCalls == 0)
        #expect(root.replaceAtCalls.isEmpty)
    }

    // MARK: - Attribute reactivity

    @Test("an attribute closure that reads a State is re-rendered when the State changes")
    func reactiveAttribute() {
        let (scheduler, manager) = makeManager()
        let color = State(wrappedValue: "red")
        let root = MockRenderable()
        var elem = TestElement(renderer: root)
        elem.attributes["style"] = { TestAttributeValue(color.wrappedValue) }
        manager.build(page: elem)

        #expect(root.updatedAttributes.map { $0.value.description } == ["red"])
        #expect(root.sailboatID != nil)

        color.wrappedValue = "blue"
        flush(manager, scheduler)

        #expect(root.updatedAttributes.map { $0.value.description } == ["red", "blue"])
        #expect(root.updatedAttributes.last?.name == "style")
    }

    @Test("a static attribute registers neither the element nor a dependency")
    func staticAttributeNotRegistered() {
        let (_, manager) = makeManager()
        let root = MockRenderable()
        var elem = TestElement(renderer: root)
        elem.attributes["id"] = { TestAttributeValue("fixed") }

        manager.build(page: elem)

        #expect(root.updatedAttributes.map { $0.value.description } == ["fixed"])
        #expect(root.sailboatID == nil)
        #expect(manager.managedPages.attributes.isEmpty)
    }

    // MARK: - Stale entries

    @Test("update prunes stateful entries whose renderer has been removed")
    func staleElementPruned() {
        let (scheduler, manager) = makeManager()
        let text = State(wrappedValue: "a")
        let root = MockRenderable()
        var elem = TestElement(renderer: root)
        elem.content = { List([TestValueElement(text.wrappedValue, renderer: MockRenderable())], hash: "") }
        manager.build(page: elem)
        guard let sid = root.sailboatID else { Issue.record("missing sailboatID"); return }

        manager.managedPages.renderers[sid] = nil   // element torn down out-of-band
        text.wrappedValue = "b"
        flush(manager, scheduler)

        #expect(manager.managedPages.statefulElements[text.id]?.contains(sid) != true)
        #expect(root.replaceAtCalls.isEmpty)
    }

    @Test("a dangling attribute renderer does not abort updates for other states")
    func danglingAttributeDoesNotAbortPass() {
        // Regression: update() used `return` instead of `continue` when an attribute's
        // renderer was missing, silently skipping every remaining state in the pass.
        let (scheduler, manager) = makeManager()
        let color = State(wrappedValue: "red")
        let text = State(wrappedValue: "a")

        let rootA = MockRenderable()
        var elemA = TestElement(renderer: rootA)
        elemA.attributes["style"] = { TestAttributeValue(color.wrappedValue) }

        let rootB = MockRenderable()
        var elemB = TestElement(renderer: rootB)
        elemB.content = { List([TestValueElement(text.wrappedValue, renderer: MockRenderable())], hash: "") }

        manager.build(page: elemA)
        manager.build(page: elemB)
        guard let sidA = rootA.sailboatID else { Issue.record("elemA should be stateful"); return }
        manager.managedPages.renderers[sidA] = nil   // A is gone, its attribute entry lingers

        color.wrappedValue = "blue"
        text.wrappedValue = "b"
        flush(manager, scheduler)

        #expect(rootB.replaceAtCalls.count == 1)
    }

    // MARK: - Dynamic dependencies

    @Test("dependencies discovered during a re-render are tracked for later updates")
    func newDependenciesTracked() {
        let (scheduler, manager) = makeManager()
        let gate = State(wrappedValue: false)
        let name = State(wrappedValue: "n")
        let root = MockRenderable()
        var elem = TestElement(renderer: root)
        elem.content = {
            let inner: any Fragment = gate.wrappedValue
                ? List([TestValueElement(name.wrappedValue, renderer: MockRenderable())], hash: "on")
                : List([], hash: "off")
            return List([inner], hash: "")
        }
        manager.build(page: elem)
        guard let sid = root.sailboatID else { Issue.record("missing sailboatID"); return }
        #expect(manager.managedPages.statefulElements[name.id] == nil)

        gate.wrappedValue = true
        flush(manager, scheduler)
        #expect(manager.managedPages.statefulElements[name.id]?.contains(sid) == true)
        #expect(manager.managedPages.elementStates[sid]?.contains(name.id) == true)

        name.wrappedValue = "m"
        flush(manager, scheduler)
        #expect(root.replaceAtCalls.map { $0.0 } == [0])
    }
}
