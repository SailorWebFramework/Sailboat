// Tests/SailboatTests/BindingTests.swift

import Testing
@testable import Sailboat

@MainActor @Suite("Binding")
struct BindingTests {

    private func freshManager() {
        SailboatGlobal.initialize(TargetManager(MockEventScheduler()))
    }

    @Test("get closure returns current value")
    func getClosureReturnsValue() {
        freshManager()
        var stored = 7
        let b = Binding(get: { stored }, set: { stored = $0 }, id: 1)
        #expect(b.wrappedValue == 7)
    }

    @Test("set closure writes through to backing storage")
    func setClosureWritesThrough() {
        freshManager()
        var stored = 0
        let b = Binding(get: { stored }, set: { stored = $0 }, id: 2)
        b.wrappedValue = 42
        #expect(stored == 42)
    }

    @Test("Binding.constant read always returns the constant")
    func constantRead() {
        let b = Binding.constant(100)
        #expect(b.wrappedValue == 100)
    }

    @Test("Binding.constant write is a no-op")
    func constantWriteIsNoOp() {
        let b = Binding.constant("immutable")
        b.wrappedValue = "changed"
        #expect(b.wrappedValue == "immutable")
    }

    @Test("Binding.constant uses reserved ID 0")
    func constantReservedID() {
        let b = Binding<Int>.constant(0)
        #expect(b.id == 0)
    }

    @Test("projectedValue returns the same Binding instance")
    func projectedValueIsSelf() {
        let b = Binding(get: { 1 }, set: { _ in }, id: 42)
        #expect(b.projectedValue === b)
    }

    @Test("two Bindings sharing same ID reflect same logical state")
    func sharedID() {
        freshManager()
        var shared = 0
        let b1 = Binding(get: { shared }, set: { shared = $0 }, id: 99)
        let b2 = Binding(get: { shared }, set: { shared = $0 }, id: 99)
        b1.wrappedValue = 55
        #expect(b2.wrappedValue == 55)
        #expect(b1.id == b2.id)
    }
}
