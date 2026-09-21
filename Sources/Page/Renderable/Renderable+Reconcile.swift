//
//  Renderable+Reconcile.swift
//
//
//  Created by Joshua Davis on 3/15/24.
//

public extension Renderable {
    
    /// Reconciles this stateful element's rendered children with its freshly built body.
    func reconcile(with newContent: any Fragment) {
        let managed = SailboatGlobal.managedPages

        guard let sid = self.sailboatID, let oldContent = managed.children[sid] else {
            fatalError("old content doesnt exist or is stateless")
        }
        
        guard oldContent.fragmentType == ObjectIdentifier(type(of: newContent)) else {
            fatalError("reconciling two different node types")
        }
        
        managed.ancestorStack.append(sid)
        let (rendered, _) = reconcileFragment(old: oldContent, new: newContent, index: -1)
        managed.ancestorStack.removeLast()

        managed.children[sid] = rendered
        managed.endOfRenderPass()
    }
    
    private func reconcileFragment(old: RenderedFragment, new: any Fragment, index: Int) -> (RenderedFragment, Int) {
        guard old.children.count == new.children.count else {
            fatalError("TWO OPERATORS SHOULD NOT HAVE SAME HASH AND DIFFERENT AMOUNT OF ELEMENTS")
        }

        var deepindex = index
        var nodes: [RenderedNode] = []
        nodes.reserveCapacity(old.children.count)
                        
        for (oldNode, newChild) in zip(old.children, new.children) {
            switch oldNode {
            case .element(let renderer, let owned):
                deepindex += 1

                // keeps the old renderer, or replaces a value-element ex: String
                if let newValue = newChild as? any ValueElement {
                    self.replace(at: deepindex, with: newValue.renderer)
                    nodes.append(.element(renderer: newValue.renderer, owned: owned))
                } else {
                    nodes.append(.element(renderer: renderer, owned: owned))
                }

            case .fragment(let oldFragment):
                guard let newFragment = newChild as? any Fragment else {
                    fatalError("reconciling a fragment against a non-fragment")
                }

                if oldFragment.hash == newFragment.hash {
                    let (rendered, next) = reconcileFragment(old: oldFragment, new: newFragment, index: deepindex)
                    deepindex = next
                    nodes.append(.fragment(rendered))
                } else {
                    // clear and build new children if hash differs
                    // TODO: instead of clear children and rebuild consider diffing
                    clear(oldFragment)

                    let built = build(newFragment, after: deepindex)
                    deepindex = built.index
                    nodes.append(contentsOf: built.nodes)
                }

            case .page(let children, let owned):
                // custom pages are opaque here; their own stateful elements update themselves
                deepindex += oldNode.domCount
                nodes.append(.page(children: children, owned: owned))
            }
        }
        
        return (RenderedFragment(of: new, children: nodes), deepindex)
    }
    
    /// Frees every stateful element under the fragment and removes its DOM nodes.
    private func clear(_ fragment: RenderedFragment) {
        for node in fragment.children {
            clear(node)
        }
    }

    private func clear(_ node: RenderedNode) {
        switch node {
        case .element(let renderer, let owned):
            for sid in owned { RenderableUtils.removeSubtreeCache(rootedAt: sid) }
            renderer.remove()

        case .fragment(let fragment):
            clear(fragment)

        case .page(let children, let owned):
            for sid in owned { RenderableUtils.removeSubtreeCache(rootedAt: sid) }
            for child in children { removeDOM(child) }
        }
    }

    /// DOM removal only — ownership under a page is freed by the page node itself.
    private func removeDOM(_ node: RenderedNode) {
        switch node {
        case .element(let renderer, _): renderer.remove()
        case .fragment(let fragment): fragment.children.forEach(removeDOM)
        case .page(let children, _): children.forEach(removeDOM)
        }
    }
}
