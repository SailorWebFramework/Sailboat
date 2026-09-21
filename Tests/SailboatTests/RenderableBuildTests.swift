// Tests/SailboatTests/RenderableBuildTests.swift
//
// Tests for the initial tree build (RenderableUtils.build / Renderable.build):
// parent attachment, fragment flattening, custom Page unwrapping, attribute and
// event forwarding, and deep-index bookkeeping for insertions.

import Testing
@testable import Sailboat

@MainActor @Suite("RenderableBuild")
struct RenderableBuildTests {

    private func makeManager() -> TargetManager {
        let manager = TargetManager(MockEventScheduler())
        SailboatGlobal.initialize(manager)
        return manager
    }

    // MARK: - Parent attachment

    @Test("children are attached to the root renderer; the root itself is not attached")
    func childrenAttached() {
        let manager = makeManager()
        let root = MockRenderable()
        let c1 = MockRenderable()
        let c2 = MockRenderable()
        var elem = TestElement(renderer: root)
        elem.content = { List([TestElement(renderer: c1), TestElement(renderer: c2)], hash: "") }

        manager.build(page: elem)

        #expect(root.addToParentCalls == 0)
        #expect(c1.addToParentTargets == [ObjectIdentifier(root)])
        #expect(c2.addToParentTargets == [ObjectIdentifier(root)])
    }

    @Test("nested fragments are flattened into the same parent")
    func nestedFragmentsFlattened() {
        let manager = makeManager()
        let root = MockRenderable()
        let c1 = MockRenderable()
        let c2 = MockRenderable()
        var elem = TestElement(renderer: root)
        elem.content = {
            List([
                List([TestElement(renderer: c1)], hash: "inner"),
                TestElement(renderer: c2)
            ], hash: "")
        }

        manager.build(page: elem)

        #expect(c1.addToParentTargets == [ObjectIdentifier(root)])
        #expect(c2.addToParentTargets == [ObjectIdentifier(root)])
    }

    @Test("grandchildren attach to their immediate parent, not the root")
    func grandchildrenAttachToParent() {
        let manager = makeManager()
        let root = MockRenderable()
        let child = MockRenderable()
        let grandchild = MockRenderable()
        var inner = TestElement(renderer: child)
        inner.content = { List([TestElement(renderer: grandchild)], hash: "") }
        var elem = TestElement(renderer: root)
        elem.content = { List([inner], hash: "") }

        manager.build(page: elem)

        #expect(child.addToParentTargets == [ObjectIdentifier(root)])
        #expect(grandchild.addToParentTargets == [ObjectIdentifier(child)])
    }

    @Test("a custom Page is unwrapped to its body element")
    func customPageUnwrapped() {
        let manager = makeManager()
        let root = MockRenderable()
        let c1 = MockRenderable()
        var elem = TestElement(renderer: root)
        elem.content = { List([TestPage(element: TestElement(renderer: c1))], hash: "") }

        manager.build(page: elem)

        #expect(c1.addToParentTargets == [ObjectIdentifier(root)])
    }

    // MARK: - Attributes & events

    @Test("events are forwarded to the renderer at build time")
    func eventsForwarded() {
        let manager = makeManager()
        let root = MockRenderable()
        var elem = TestElement(renderer: root)
        elem.events["click"] = { _ in }
        elem.events["input"] = { _ in }

        manager.build(page: elem)

        #expect(Set(root.addedEvents) == ["click", "input"])
    }

    @Test("attributes are rendered on the renderer at build time")
    func attributesRendered() {
        let manager = makeManager()
        let root = MockRenderable()
        var elem = TestElement(renderer: root)
        elem.attributes["id"] = { TestAttributeValue("main") }

        manager.build(page: elem)

        #expect(root.updatedAttributes.count == 1)
        #expect(root.updatedAttributes.first?.name == "id")
        #expect(root.updatedAttributes.first?.value.description == "main")
    }

    @Test("a stateful attribute registers the renderer and an ElementAttribute for that State")
    func statefulAttributeRegistered() {
        let manager = makeManager()
        let label = State(wrappedValue: "x")
        let root = MockRenderable()
        var elem = TestElement(renderer: root)
        elem.attributes["title"] = { TestAttributeValue(label.wrappedValue) }

        manager.build(page: elem)

        guard let sid = root.sailboatID else { Issue.record("expected a sailboatID"); return }
        #expect(manager.managedPages.renderers[sid] != nil)
        let entries = manager.managedPages.attributes[label.id] ?? []
        #expect(entries.count == 1)
        #expect(entries.first?.name == "title")
        #expect(entries.first?.sid == sid)
    }

    // MARK: - Deep-index bookkeeping (Renderable.build(_:after:))

    @Test("build(after: -1) inserts the first element before 0, then after each predecessor")
    func deepIndexFromStart() {
        _ = makeManager()
        let root = MockRenderable()
        let a = MockRenderable(), b = MockRenderable(), c = MockRenderable()
        let fragment = List([
            TestElement(renderer: a), TestElement(renderer: b), TestElement(renderer: c)
        ], hash: "")

        let last = root.build(fragment, after: -1)

        #expect(a.insertBeforeCalls == [0])
        #expect(b.insertAfterCalls == [0])
        #expect(c.insertAfterCalls == [1])
        #expect(last == 2)
    }

    @Test("build(after: n) counts elements through nested fragments and custom pages")
    func deepIndexThroughNesting() {
        _ = makeManager()
        let root = MockRenderable()
        let a = MockRenderable(), b = MockRenderable()
        let fragment = List([
            List([TestElement(renderer: a)], hash: "inner"),
            TestPage(element: TestElement(renderer: b))
        ], hash: "")

        let last = root.build(fragment, after: 4)

        #expect(a.insertAfterCalls == [4])
        #expect(b.insertAfterCalls == [5])
        #expect(last == 6)
    }

    @Test("build of an empty fragment returns the starting index unchanged")
    func deepIndexEmpty() {
        _ = makeManager()
        let root = MockRenderable()
        #expect(root.build(List(), after: 3) == 3)
    }
}
