// Tests/SailboatTests/StateTests.swift

import Testing
@testable import Sailboat

@MainActor @Suite("State")
struct StateTests {

    // Each test starts with a fresh global manager so State's side effects
    // (dumpDependency, observe) go to a clean MockEventScheduler.
    private func freshScheduler() -> MockEventScheduler {
        let scheduler = MockEventScheduler()
        SailboatGlobal.initialize(TargetManager(scheduler))
        return scheduler
    }

    @Test("initial wrappedValue is preserved")
    func initialValue() {
        _ = freshScheduler()
        let s = State(wrappedValue: 42)
        #expect(s.wrappedValue == 42)
    }

    @Test("set then get roundtrip stores new value")
    func setGetRoundtrip() {
        _ = freshScheduler()
        let s = State(wrappedValue: "hello")
        s.wrappedValue = "world"
        #expect(s.wrappedValue == "world")
    }

    @Test("setting identical value does not call observe")
    func equalityGuardSkipsObserve() {
        let scheduler = freshScheduler()
        let s = State(wrappedValue: 10)
        s.wrappedValue = 10          // same value — equality guard must prevent observe
        #expect(scheduler.observedStateIDs.isEmpty)
    }

    @Test("setting different value calls observe exactly once")
    func differentValueCallsObserveOnce() {
        let scheduler = freshScheduler()
        let s = State(wrappedValue: 0)
        s.wrappedValue = 1
        #expect(scheduler.observedStateIDs.count == 1)
        #expect(scheduler.observedStateIDs.first == s.id)
    }

    @Test("projectedValue Binding has matching ID")
    func projectedValueBindingID() {
        _ = freshScheduler()
        let s = State(wrappedValue: true)
        #expect(s.projectedValue.id == s.id)
    }

    @Test("Binding from projectedValue reads current value")
    func projectedValueRead() {
        _ = freshScheduler()
        let s = State(wrappedValue: 99)
        #expect(s.projectedValue.wrappedValue == 99)
    }

    @Test("Binding from projectedValue writes back through State")
    func projectedValueWrite() {
        _ = freshScheduler()
        let s = State(wrappedValue: 5)
        s.projectedValue.wrappedValue = 77
        #expect(s.wrappedValue == 77)
    }
}
