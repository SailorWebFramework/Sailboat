// Tests/SailboatTests/FragmentTests.swift

import Testing
@testable import Sailboat

@MainActor @Suite("Fragment")
struct FragmentTests {

    // MARK: - List (concrete Fragment)

    @Test("List() has empty children and empty hash")
    func listDefaultEmpty() {
        let list = List()
        #expect(list.children.isEmpty)
        #expect(list.hash == "")
    }

    @Test("List(children:hash:) stores children and hash")
    func listWithChildren() {
        let elem = TestElement(renderer: MockRenderable())
        let list = List([elem], hash: "abc123")
        #expect(list.children.count == 1)
        #expect(list.hash == "abc123")
    }

    // MARK: - Element helpers

    @Test("Element attributes are empty on default init")
    func elementEmptyAttributes() {
        let elem = TestElement(renderer: MockRenderable())
        #expect(elem.attributes.isEmpty)
    }

    @Test("Element events are empty on default init")
    func elementEmptyEvents() {
        let elem = TestElement(renderer: MockRenderable())
        #expect(elem.events.isEmpty)
    }

    @Test("withEvent adds closure to a copy, leaving original unchanged")
    func withEventCopySemantic() {
        let original = TestElement(renderer: MockRenderable())
        let updated = original.withEvent(name: "click") { _ in }
        #expect(updated.events["click"] != nil)
        #expect(original.events["click"] == nil)
    }

    @Test("withEvent closure is invoked with the supplied EventResult")
    func withEventClosureInvoked() {
        let elem = TestElement(renderer: MockRenderable())
        var received: EventResult?
        let updated = elem.withEvent(name: "click") { result in
            received = result
        }
        updated.events["click"]?(EventResult.none)
        // received should be EventResult.none, not nil
        if case .none? = received { } else {
            #expect(Bool(false), "expected EventResult.none")
        }
    }

    @Test("two withEvent calls on same name chain both closures")
    func withEventChains() {
        let elem = TestElement(renderer: MockRenderable())
        var count = 0
        let step1 = elem.withEvent(name: "input") { _ in count += 1 }
        let step2 = step1.withEvent(name: "input") { _ in count += 1 }
        step2.events["input"]?(.none)
        #expect(count == 2)
    }

    // MARK: - EventResult

    @Test("EventResult.string wraps and unwraps correctly")
    func eventResultString() {
        let r = EventResult.string("hello")
        if case .string(let v) = r {
            #expect(v == "hello")
        } else {
            #expect(Bool(false), "Expected .string case")
        }
    }

    @Test("EventResult.bool wraps and unwraps correctly")
    func eventResultBool() {
        let r = EventResult.bool(true)
        if case .bool(let v) = r {
            #expect(v == true)
        } else {
            #expect(Bool(false), "Expected .bool case")
        }
    }

    @Test("EventResult.int wraps and unwraps correctly")
    func eventResultInt() {
        let r = EventResult.int(42)
        if case .int(let v) = r {
            #expect(v == 42)
        } else {
            #expect(Bool(false), "Expected .int case")
        }
    }

    @Test("EventResult.none is pattern-matchable")
    func eventResultNone() {
        let r = EventResult.none
        if case .none = r { } else {
            #expect(Bool(false), "Expected .none case")
        }
    }
}
