// Tests/SailboatTests/EnvironmentTests.swift
//
// Tests for the remaining property wrappers (Environment, EnvironmentObject,
// StateObject, ObservedObject), IDGenerator and the Element attribute helper.

import Testing
@testable import Sailboat

private struct TestEnv: SomeEnvironment {
    var title = "Sailor"
    var count = 3
}

private final class Counter {
    var n: Int
    init(_ n: Int) { self.n = n }
}

@MainActor @Suite("Environment")
struct EnvironmentTests {

    private func makeManager() -> TargetManager {
        let manager = TargetManager(MockEventScheduler())
        SailboatGlobal.initialize(manager)
        return manager
    }

    // MARK: - Environment

    @Test("Environment(keyPath) reads the value off the manager's environment")
    func environmentKeyPath() {
        let manager = makeManager()
        manager.environment = TestEnv()
        let title = Environment<TestEnv, String>(\.title)
        #expect(title.wrappedValue == "Sailor")
    }

    @Test("Environment() with no keyPath returns the whole environment")
    func environmentWhole() {
        let manager = makeManager()
        manager.environment = TestEnv(title: "t", count: 9)
        let env = Environment<TestEnv, TestEnv>()
        #expect(env.wrappedValue.count == 9)
    }

    @Test("Environment reflects later changes to the manager's environment")
    func environmentLive() {
        let manager = makeManager()
        manager.environment = TestEnv(title: "first", count: 0)
        let title = Environment<TestEnv, String>(\.title)
        manager.environment = TestEnv(title: "second", count: 0)
        #expect(title.wrappedValue == "second")
    }

    // MARK: - EnvironmentObject

    @Test("EnvironmentObject resolves the object registered under its type name")
    func environmentObjectLookup() {
        let manager = makeManager()
        let counter = Counter(1)
        manager.objects[String(describing: Counter.self)] = counter
        let wrapper = EnvironmentObject<Counter>()
        #expect(wrapper.wrappedValue === counter)
    }

    @Test("EnvironmentObject projectedValue reads the same instance")
    func environmentObjectProjected() {
        let manager = makeManager()
        let counter = Counter(2)
        manager.objects[String(describing: Counter.self)] = counter
        let wrapper = EnvironmentObject<Counter>()
        #expect(wrapper.projectedValue.wrappedValue === counter)
    }

    // MARK: - StateObject / ObservedObject

    @Test("StateObject stores and returns its object")
    func stateObjectRoundtrip() {
        _ = makeManager()
        let counter = Counter(0)
        let store = StateObject(wrappedValue: counter)
        #expect(store.wrappedValue === counter)
        store.wrappedValue.n = 5
        #expect(counter.n == 5)
    }

    @Test("StateObject projectedValue writes through to the StateObject")
    func stateObjectProjectedWrite() {
        _ = makeManager()
        let first = Counter(0)
        let second = Counter(1)
        let store = StateObject(wrappedValue: first)
        store.projectedValue.wrappedValue = second
        #expect(store.wrappedValue === second)
    }

    @Test("ObservedObject get/set closures back its wrappedValue")
    func observedObjectClosures() {
        var backing = Counter(0)
        let observed = ObservedObject(get: { backing }, set: { backing = $0 })
        #expect(observed.wrappedValue === backing)
        let replacement = Counter(7)
        observed.wrappedValue = replacement
        #expect(backing === replacement)
    }

    @Test("ObservedObject projectedValue is itself")
    func observedObjectProjected() {
        let observed = ObservedObject(get: { Counter(0) }, set: { _ in })
        #expect(observed.projectedValue === observed)
    }

    @Test("Published is an alias for State")
    func publishedAlias() {
        _ = makeManager()
        let published: Published<Int> = State(wrappedValue: 4)
        #expect(published.wrappedValue == 4)
    }

    // MARK: - IDGenerator

    @Test("IDGenerator hands out strictly increasing, non-zero IDs")
    func idGeneratorMonotonic() {
        let a = IDGenerator.generateID()
        let b = IDGenerator.generateID()
        let c = IDGenerator.generateID()
        #expect(a > 0)
        #expect(b > a)
        #expect(c > b)
    }

    @Test("distinct States receive distinct IDs")
    func stateIDsDistinct() {
        _ = makeManager()
        let ids = (0..<20).map { _ in State(wrappedValue: 0).id }
        #expect(Set(ids).count == ids.count)
        #expect(!ids.contains(0), "0 is reserved for Binding.constant")
    }

    // MARK: - Element.attribute(_:)

    @Test("attribute(_:) stores the group under its name on a copy")
    func attributeCopySemantics() {
        let original = TestElement(renderer: MockRenderable())
        let updated = original.attribute(.init(name: "id", value: { TestAttributeValue("x") }))
        #expect(updated.attributes["id"]?().description == "x")
        #expect(original.attributes["id"] == nil)
    }

    @Test("attribute(_:) with the same name replaces the previous value")
    func attributeReplace() {
        let elem = TestElement(renderer: MockRenderable())
            .attribute(.init(name: "id", value: { TestAttributeValue("a") }))
            .attribute(.init(name: "id", value: { TestAttributeValue("b") }))
        #expect(elem.attributes["id"]?().description == "b")
    }

    @Test("ElementAttributeGroup equality is by name and rendered value")
    func attributeGroupEquality() {
        let a = ElementAttributeGroup(name: "id", value: { TestAttributeValue("x") })
        let b = ElementAttributeGroup(name: "id", value: { TestAttributeValue("x") })
        let c = ElementAttributeGroup(name: "id", value: { TestAttributeValue("y") })
        #expect(a == b)
        #expect(a != c)
        #expect(a.description == "id:x")
    }
}
