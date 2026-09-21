//
//  ManagedPages.swift
//  
//
//  Created by Joshua Davis on 3/14/24.
//

public struct ElementAttribute: Hashable {
    /// the sailboat id of the element
    let sid: SailboatID
    /// the attribute build action
    let value: () -> any AttributeValue
    /// the name of the attribute
    let name: String
    
    public static func == (lhs: ElementAttribute, rhs: ElementAttribute) -> Bool {
        lhs.sid == rhs.sid && lhs.name == rhs.name
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(sid)
        hasher.combine(name)
    }
    
}

public typealias SailboatID = UniqueID // String

extension SailboatID: AttributeValue { }

/// Bookkeeping for every element that can change after it is built: elements whose
/// body or attributes read a signal, and elements with exit lifecycle hooks.
///
/// Stateless elements cost nothing here; the ownership tree below is keyed by
/// stateful elements only, which is what keeps removal O(stateful descendants)
/// without reading anything back from the DOM.
@MainActor
public final class ManagedPages {

    /// event names whose handlers run from Swift when the element leaves the tree
    public static let exitEventNames: Set<String> = ["_disappear", "_killEnvironmentObject"]

    ///
    public var renderers: [SailboatID: any Renderable] = [:]
    
    /// all bodies of stateful elements that could change throughout the lifecycle of the app
    public var bodies: [SailboatID: () -> any Fragment] = [:]

    /// snapshot of each stateful element's last-rendered shallow content
    public var children: [SailboatID: RenderedFragment] = [:]
    
    /// references to element attributes that are neccisary for state certian changes
    public var attributes: [StateID: Set<ElementAttribute>] = [:]
    
    /// map of states to the pages they include
    public var statefulElements: [StateID: Set<SailboatID>] = [:]

    /// reverse index: the states each element's *body* depends on
    /// kept in sync with statefulElements so removeCache is O(state count of element)
    public var elementStates: [SailboatID: Set<StateID>] = [:]

    /// the states each element's attributes depend on, by attribute name
    public var attributeStates: [SailboatID: [String: Set<StateID>]] = [:]

    /// handlers to run when the element leaves the tree (see `exitEventNames`)
    public var exitHandlers: [SailboatID: [(EventResult) -> Void]] = [:]

    // MARK: Ownership tree

    /// nearest stateful ancestor of each stateful element
    public var statefulParent: [SailboatID: SailboatID] = [:]

    /// stateful elements whose nearest stateful ancestor is the key
    public var statefulChildren: [SailboatID: Set<SailboatID>] = [:]

    /// the stateful elements currently being built or reconciled, innermost last
    public var ancestorStack: [SailboatID] = []

    /// the stateful element new registrations attach to
    public var currentAncestor: SailboatID? { ancestorStack.last }

    /// registrations made during the current render pass, used to work out which
    /// stateful elements a snapshot node owns
    private var registrationLog: [(sid: SailboatID, parent: SailboatID?)] = []

    /// the current callback history of changed state values, use dump to clear the history
    public var stateHistory: Set<StateID> = []

    /// Registers `element` as body-stateful if building its content read any signal.
    /// The snapshot stored here is provisional; `RenderableUtils.build` replaces it
    /// once the children are built and their ownership is known.
    public func registerElement(_ element: any Element, _ operatorPage: any Fragment) {
        let states = SailboatGlobal.manager.dump()

        if states.isEmpty { return }

        let sid = assignID(to: element.renderer)

        self.bodies[sid] = element.content
        self.children[sid] = RenderedFragment.provisional(operatorPage)

        for state in states {
            self.statefulElements[state, default: []].insert(sid)
            self.elementStates[sid, default: []].insert(state)
        }
    }

    /// Gives the renderer a SailboatID if it has none, records it and links it to the
    /// current stateful ancestor.
    @discardableResult
    public func assignID(to renderer: any Renderable) -> SailboatID {
        if let sid = renderer.sailboatID, renderers[sid] != nil { return sid }

        let sid = IDGenerator.generateID()
        renderer.setSailboatID(sid)
        renderers[sid] = renderer

        if let parent = currentAncestor {
            statefulParent[sid] = parent
            statefulChildren[parent, default: []].insert(sid)
        }
        registrationLog.append((sid, currentAncestor))
        return sid
    }

    /// A position in the registration log; pair with `owned(since:)`.
    public func ownershipMark() -> Int { registrationLog.count }

    /// Stateful elements registered since `mark` whose nearest stateful ancestor is the
    /// current one — i.e. the ones a snapshot node built in that window must free.
    public func owned(since mark: Int) -> [SailboatID] {
        guard mark < registrationLog.count else { return [] }
        let ancestor = currentAncestor
        return registrationLog[mark...].filter { $0.parent == ancestor }.map { $0.sid }
    }

    /// Drops the registration log once no build or reconcile is in progress.
    public func endOfRenderPass() {
        if ancestorStack.isEmpty { registrationLog.removeAll(keepingCapacity: true) }
    }

}

extension RenderedFragment {
    /// Snapshot of a fragment before its children are built (no ownership info yet).
    @MainActor static func provisional(_ fragment: any Fragment) -> RenderedFragment {
        RenderedFragment(of: fragment, children: fragment.children.map { child in
            if let element = child as? any Element { return .element(renderer: element.renderer, owned: []) }
            if let nested = child as? any Fragment { return .fragment(provisional(nested)) }
            return .page(children: [], owned: [])
        })
    }
}
