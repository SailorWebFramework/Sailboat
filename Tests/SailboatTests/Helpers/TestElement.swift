// Tests/SailboatTests/Helpers/TestElement.swift
//
// Minimal concrete Element for use in Sailboat unit tests.

import Testing
@testable import Sailboat

/// A simple Element whose renderer can be swapped in, used wherever tests
/// need a concrete Element without pulling in the full Sailor stack.
@MainActor
struct TestElement: Element {

    var attributes: [String: () -> any AttributeValue] = [:]
    var events: [String: (EventResult) -> Void] = [:]
    var content: () -> any Fragment = { List() }
    var renderer: any Renderable

    var body: Never { .error() }

    init(renderer: any Renderable) {
        self.renderer = renderer
    }
}
