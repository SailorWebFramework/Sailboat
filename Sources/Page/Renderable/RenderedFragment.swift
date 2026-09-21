//
//  RenderedFragment.swift
//
//  Lightweight snapshot of a stateful element's last-rendered shallow content.
//  Reconcile only needs fragment hashes, child counts and renderers, so this is
//  what ManagedPages retains instead of the Element structs (and their closures).
//

/// The rendered shape of one Fragment level.
public struct RenderedFragment {
    /// hash of the fragment (conditional / loop identity)
    public var hash: String
    /// dynamic type of the fragment, checked before reconciling
    public var fragmentType: ObjectIdentifier
    /// one node per child page of the fragment
    public var children: [RenderedNode]

    public init(hash: String, fragmentType: ObjectIdentifier, children: [RenderedNode]) {
        self.hash = hash
        self.fragmentType = fragmentType
        self.children = children
    }

    @MainActor public init(of fragment: any Fragment, children: [RenderedNode]) {
        self.init(hash: fragment.hash, fragmentType: ObjectIdentifier(type(of: fragment)), children: children)
    }

    /// number of DOM nodes this fragment contributes to its parent renderer
    public var domCount: Int { children.reduce(0) { $0 + $1.domCount } }
}

/// One child of a rendered fragment.
public enum RenderedNode {
    /// an element and the stateful elements rooted under it whose nearest stateful
    /// ancestor is the snapshot's owner (so clearing this node can free them)
    case element(renderer: any Renderable, owned: [SailboatID])
    /// a nested fragment (conditional / loop body)
    case fragment(RenderedFragment)
    /// a custom Page, flattened into the nodes its body produced
    case page(children: [RenderedNode], owned: [SailboatID])

    /// number of DOM nodes this node contributes to its parent renderer
    public var domCount: Int {
        switch self {
        case .element: return 1
        case .fragment(let fragment): return fragment.domCount
        case .page(let children, _): return children.reduce(0) { $0 + $1.domCount }
        }
    }
}
