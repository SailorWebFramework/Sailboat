// Tests/SailboatTests/OwnershipTests.swift
//
// #23 stale dependencies are dropped on re-render
// #22 snapshots hold renderers and hashes, not Element structs
// #28 stateful descendants are tracked in Swift and freed on removal

import Testing
@testable import Sailboat

@MainActor
private struct TwoElementPage: Page {
    let first: TestElement
    let second: TestElement
    var body: List { List([first, second], hash: "") }
}

@MainActor @Suite("Ownership")
struct OwnershipTests {

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

    /// root (stateful on `gate`) → conditional → child element (stateless) → grandchild (stateful on `name`)
    private func nestedTree(gate: State<Bool>, name: State<String>, child: MockRenderable, grandchild: MockRenderable) -> TestElement {
        var elem = TestElement(renderer: MockRenderable())
        elem.content = {
            var inner = TestElement(renderer: child)
            inner.content = { List([TestValueElement(name.wrappedValue, renderer: grandchild)], hash: "") }
            let branch: any Fragment = gate.wrappedValue ? List([inner], hash: "on") : List([], hash: "off")
            return List([branch], hash: "")
        }
        return elem
    }

    // MARK: - #23 dependency removal

    @Test("a signal no longer read after a re-render stops triggering the element")
    func staleBodyDependencyDropped() {
        let (scheduler, manager) = makeManager()
        let toggle = State(wrappedValue: true)
        let name = State(wrappedValue: "n")
        let root = MockRenderable()
        var elem = TestElement(renderer: root)
        elem.content = {
            List([TestValueElement(toggle.wrappedValue ? name.wrappedValue : "hello", renderer: MockRenderable())], hash: "")
        }
        manager.build(page: elem)
        guard let sid = root.sailboatID else { Issue.record("missing sailboatID"); return }
        #expect(manager.managedPages.statefulElements[name.id]?.contains(sid) == true)

        toggle.wrappedValue = false
        flush(manager, scheduler)
        #expect(manager.managedPages.statefulElements[name.id] == nil)
        #expect(manager.managedPages.elementStates[sid] == [toggle.id])

        name.wrappedValue = "m"
        flush(manager, scheduler)
        #expect(root.replaceAtCalls.count == 1, "only the toggle change should have re-rendered")
    }

    @Test("a signal no longer read by an attribute stops triggering the attribute")
    func staleAttributeDependencyDropped() {
        let (scheduler, manager) = makeManager()
        let useA = State(wrappedValue: true)
        let a = State(wrappedValue: "a")
        let root = MockRenderable()
        var elem = TestElement(renderer: root)
        elem.attributes["title"] = { TestAttributeValue(useA.wrappedValue ? a.wrappedValue : "fixed") }
        manager.build(page: elem)
        guard let sid = root.sailboatID else { Issue.record("missing sailboatID"); return }
        #expect(manager.managedPages.attributeStates[sid]?["title"] == [useA.id, a.id])

        useA.wrappedValue = false
        flush(manager, scheduler)
        #expect(manager.managedPages.attributeStates[sid]?["title"] == [useA.id])
        #expect(manager.managedPages.attributes[a.id] == nil)

        a.wrappedValue = "b"
        flush(manager, scheduler)
        #expect(root.updatedAttributes.count == 2)
    }

    // MARK: - #22 snapshot shape

    @Test("the retained snapshot is renderers and hashes, not Element structs")
    func snapshotShape() {
        let (_, manager) = makeManager()
        let text = State(wrappedValue: "t")
        let root = MockRenderable()
        let childRenderer = MockRenderable()
        var elem = TestElement(renderer: root)
        elem.content = {
            List([
                TestElement(renderer: childRenderer),
                List([TestValueElement(text.wrappedValue, renderer: MockRenderable())], hash: "inner")
            ], hash: "outer")
        }
        manager.build(page: elem)
        guard let sid = root.sailboatID, let snapshot = manager.managedPages.children[sid] else {
            Issue.record("missing snapshot"); return
        }
        #expect(snapshot.hash == "outer")
        #expect(snapshot.children.count == 2)
        guard case .element(let renderer, let owned) = snapshot.children[0] else { Issue.record("expected element"); return }
        #expect(renderer as AnyObject === childRenderer)
        #expect(owned.isEmpty)
        guard case .fragment(let inner) = snapshot.children[1] else { Issue.record("expected fragment"); return }
        #expect(inner.hash == "inner")
        #expect(inner.domCount == 1)
    }

    // MARK: - #28 ownership tree

    @Test("nested stateful elements link to their nearest stateful ancestor, through stateless elements")
    func parentLinks() {
        let (_, manager) = makeManager()
        let gate = State(wrappedValue: true)
        let name = State(wrappedValue: "n")
        let child = MockRenderable(), grandchild = MockRenderable()
        let elem = nestedTree(gate: gate, name: name, child: child, grandchild: grandchild)
        manager.build(page: elem)

        guard let rootSID = elem.renderer.sailboatID else { Issue.record("root should be stateful"); return }
        // `child` reads nothing itself; `grandchild`'s text reads `name`, so the *child* element
        // (whose content closure ran the read) is the stateful one
        guard let childSID = child.sailboatID else { Issue.record("child should be stateful"); return }
        #expect(grandchild.sailboatID == nil)
        #expect(manager.managedPages.statefulParent[childSID] == rootSID)
        #expect(manager.managedPages.statefulChildren[rootSID] == [childSID])
        #expect(manager.managedPages.statefulParent[rootSID] == nil)
    }

    @Test("clearing a conditional frees the stateful elements under it and their links")
    func conditionalOffFreesSubtree() {
        let (scheduler, manager) = makeManager()
        let gate = State(wrappedValue: true)
        let name = State(wrappedValue: "n")
        let child = MockRenderable(), grandchild = MockRenderable()
        let elem = nestedTree(gate: gate, name: name, child: child, grandchild: grandchild)
        manager.build(page: elem)
        guard let rootSID = elem.renderer.sailboatID, let childSID = child.sailboatID else {
            Issue.record("expected stateful root and child"); return
        }

        gate.wrappedValue = false
        flush(manager, scheduler)

        #expect(child.removeCalls == 1)
        #expect(manager.managedPages.renderers[childSID] == nil)
        #expect(manager.managedPages.statefulParent[childSID] == nil)
        #expect(manager.managedPages.statefulChildren[rootSID] == nil)
        #expect(manager.managedPages.statefulElements[name.id] == nil)

        // a later change to the freed element's signal must not touch its renderer
        name.wrappedValue = "m"
        flush(manager, scheduler)
        #expect(child.replaceAtCalls.isEmpty)
    }

    @Test("elements added during a reconcile link to the reconciling element")
    func reconcileLinksNewChildren() {
        let (scheduler, manager) = makeManager()
        let gate = State(wrappedValue: false)
        let name = State(wrappedValue: "n")
        let child = MockRenderable(), grandchild = MockRenderable()
        let elem = nestedTree(gate: gate, name: name, child: child, grandchild: grandchild)
        manager.build(page: elem)
        guard let rootSID = elem.renderer.sailboatID else { Issue.record("root should be stateful"); return }
        #expect(manager.managedPages.statefulChildren[rootSID] == nil)

        gate.wrappedValue = true
        flush(manager, scheduler)
        guard let childSID = child.sailboatID else { Issue.record("child should be stateful after insert"); return }
        #expect(manager.managedPages.statefulParent[childSID] == rootSID)
        #expect(manager.managedPages.statefulChildren[rootSID] == [childSID])

        gate.wrappedValue = false
        flush(manager, scheduler)
        #expect(manager.managedPages.renderers[childSID] == nil)
        #expect(manager.managedPages.statefulChildren[rootSID] == nil)
    }

    @Test("exit handlers run from Swift when the element leaves, deepest first")
    func exitHandlersRun() {
        let (scheduler, manager) = makeManager()
        let gate = State(wrappedValue: true)
        var log: [String] = []
        let outer = MockRenderable(), inner = MockRenderable()
        var root = TestElement(renderer: MockRenderable())
        root.content = {
            var o = TestElement(renderer: outer)
            o.events["_disappear"] = { _ in log.append("outer") }
            var i = TestElement(renderer: inner)
            i.events["_disappear"] = { _ in log.append("inner") }
            o.content = { List([i], hash: "") }
            let branch: any Fragment = gate.wrappedValue ? List([o], hash: "on") : List([], hash: "off")
            return List([branch], hash: "")
        }
        manager.build(page: root)
        #expect(!outer.addedEvents.contains("_disappear"), "exit hooks are kept in Swift, not attached to the renderer")
        #expect(log.isEmpty)

        gate.wrappedValue = false
        flush(manager, scheduler)
        #expect(log == ["inner", "outer"])
        #expect(outer.removeCalls == 1)
        #expect(inner.removeCalls == 0, "only the subtree root is removed from the DOM")
    }

    @Test("removing a subtree frees every stateful descendant in O(k) without the renderer")
    func removeSubtreeCache() {
        let (_, manager) = makeManager()
        let a = State(wrappedValue: 0), b = State(wrappedValue: 0)
        let mid = MockRenderable(), leaf = MockRenderable()
        var root = TestElement(renderer: MockRenderable())
        root.content = {
            _ = a.wrappedValue
            var m = TestElement(renderer: mid)
            m.content = {
                _ = a.wrappedValue
                var l = TestElement(renderer: leaf)
                l.content = { List([TestValueElement("\(b.wrappedValue)", renderer: MockRenderable())], hash: "") }
                return List([l], hash: "")
            }
            return List([m], hash: "")
        }
        manager.build(page: root)
        guard let rootSID = root.renderer.sailboatID, let midSID = mid.sailboatID, let leafSID = leaf.sailboatID else {
            Issue.record("expected three stateful elements"); return
        }
        #expect(manager.managedPages.statefulChildren[rootSID] == [midSID])
        #expect(manager.managedPages.statefulChildren[midSID] == [leafSID])

        RenderableUtils.removeSubtreeCache(rootedAt: midSID)

        #expect(manager.managedPages.renderers[midSID] == nil)
        #expect(manager.managedPages.renderers[leafSID] == nil)
        #expect(manager.managedPages.statefulElements[b.id] == nil)
        #expect(manager.managedPages.statefulChildren[rootSID] == nil)
        #expect(manager.managedPages.renderers[rootSID] != nil)
        #expect(mid.removeCalls == 0)
    }

    @Test("a custom Page with several root elements advances the deep index by its DOM count")
    func pageDomCount() {
        let (scheduler, manager) = makeManager()
        let gate = State(wrappedValue: false)
        let inserted = MockRenderable()
        var root = TestElement(renderer: MockRenderable())
        root.content = {
            let branch: any Fragment = gate.wrappedValue ? List([TestElement(renderer: inserted)], hash: "on") : List([], hash: "off")
            return List([
                TwoElementPage(first: TestElement(renderer: MockRenderable()), second: TestElement(renderer: MockRenderable())),
                branch
            ], hash: "")
        }
        manager.build(page: root)

        gate.wrappedValue = true
        flush(manager, scheduler)
        // two DOM nodes precede the conditional, so the new element goes after index 1 (not 0)
        #expect(inserted.insertAfterCalls == [1])
    }

    @Test("setSailboatID never has to touch the renderer's attributes")
    func noAttributeForID() {
        let (_, manager) = makeManager()
        let s = State(wrappedValue: 0)
        let root = MockRenderable()
        var elem = TestElement(renderer: root)
        elem.content = { _ = s.wrappedValue; return List() }
        manager.build(page: elem)
        #expect(root.sailboatID != nil)
        #expect(root.updatedAttributes.isEmpty)
    }
}
