// Tests/SailboatTests/Helpers/TestPages.swift
//
// Additional concrete Page types used by the render-pipeline tests.

import Testing
@testable import Sailboat

/// A text-like element: `ValueElement` children are the ones reconcile
/// replaces in place when their value changes (mirrors Sailor's `String`).
@MainActor
struct TestValueElement: ValueElement {

    var value: String

    var attributes: [String: () -> any AttributeValue] = [:]
    var events: [String: (EventResult) -> Void] = [:]
    var content: () -> any Fragment = { List() }
    var renderer: any Renderable

    var body: Never { .error() }

    init(_ value: String, renderer: any Renderable) {
        self.value = value
        self.renderer = renderer
    }
}

/// A custom (non-Element, non-Fragment) Page whose body is a single element,
/// the shape user-defined components take.
@MainActor
struct TestPage: Page {
    let element: TestElement

    var body: TestElement { element }
}

/// Minimal AttributeValue so tests don't depend on SailorShared's String conformance.
struct TestAttributeValue: AttributeValue {
    var description: String

    init(_ description: String) {
        self.description = description
    }
}
