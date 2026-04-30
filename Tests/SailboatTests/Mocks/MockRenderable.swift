// Tests/SailboatTests/Mocks/MockRenderable.swift
//
// A test-double Renderable that records every mutating call made to it.

import Testing
@testable import Sailboat

/// Records add/remove/update operations so tests can verify the rendering
/// pipeline issued the correct calls without needing a real DOM or HTML node.
@MainActor
final class MockRenderable: Renderable {

    var sailboatID: SailboatID?

    // Call counters
    var addToParentCalls: Int = 0
    var removeCalls: Int = 0
    var replaceAtCalls: [(Int, any Renderable)] = []

    // Attribute & event logs
    var updatedAttributes: [(name: String, value: any AttributeValue)] = []
    var addedEvents: [String] = []

    // MARK: - Renderable

    func addToParent(_ parent: any Renderable) {
        addToParentCalls += 1
    }

    func insertAfter(_ deepIndex: Int, parent: any Renderable) { }

    func insertBefore(_ deepIndex: Int, parent: any Renderable) { }

    func remove() {
        removeCalls += 1
    }

    func remove(at deepIndex: Int) { }

    func replace(at index: Int, with renderable: any Renderable) {
        replaceAtCalls.append((index, renderable))
    }

    func updateAttribute(name: String, value: any AttributeValue) {
        updatedAttributes.append((name: name, value: value))
    }

    func addEvent(name: String, value: @escaping (EventResult) -> Void) {
        addedEvents.append(name)
    }

    func setSailboatID(_ value: SailboatID?) {
        sailboatID = value
    }
}
