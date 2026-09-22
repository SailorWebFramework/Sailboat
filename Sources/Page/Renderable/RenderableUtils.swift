//
//  RenderableUtils.swift
//  
//
//  Created by Joshua Davis on 3/17/24.
//


@MainActor
public enum RenderableUtils {
    
    /// build a root element (no parent renderer)
    public static func build(_ element: any Element) {
        _ = build(page: element, parent: nil)
    }

    /// Builds `page` into `parent`'s renderer and returns the snapshot nodes it produced.
    ///
    /// While a stateful element's children are built it is pushed on the ancestor
    /// stack, so stateful descendants link to it; ownership of stateful elements
    /// rooted under stateless children is recorded on the snapshot node instead.
    @discardableResult
    public static func build(page: any Page, parent: (any Element)?) -> [RenderedNode] {
        let managed = SailboatGlobal.managedPages

        // if page is an Operator
        if let fragment = page as? any Fragment {
            var nodes: [RenderedNode] = []
            for child in fragment.children {
                nodes.append(contentsOf: build(page: child, parent: parent))
            }
            return [.fragment(RenderedFragment(of: fragment, children: nodes))]
        }
        
        // if page is an HTMLElement
        if let element = page as? any Element {
            let mark = managed.ownershipMark()

            // run the page builder closure to create an operator node
            let operatorPage = element.content()
            
            managed.registerElement(element, operatorPage)
            
            // render current page to parent
            element.renderer.renderAttributes(element.attributes)
            element.renderer.renderEvents(element.events)

            let sid = element.renderer.sailboatID
            if let sid = sid { managed.ancestorStack.append(sid) }

            let inner = build(page: operatorPage, parent: element)

            if let sid = sid {
                managed.ancestorStack.removeLast()
                // only body-stateful elements reconcile, so only they keep a snapshot
                if managed.bodies[sid] != nil, case .fragment(let rendered)? = inner.first {
                    managed.children[sid] = rendered
                }
            }
            
            if let parent = parent {
                element.renderer.addToParent(parent.renderer)
            }
            
            if let value = element as? any ValueElement {
                return [.text(renderer: value.renderer, value: value.value.description)]
            }
            return [.element(renderer: element.renderer, owned: managed.owned(since: mark))]
        }
        
        // custom Page: transparent, flattened into whatever its body produces
        let mark = managed.ownershipMark()
        let nodes = build(page: page.body, parent: parent)
        return [.page(children: nodes, owned: managed.owned(since: mark))]
    }
    
    /// Forgets a single stateful element.
    public static func removeCache(with sailboatID: SailboatID) {
        let managed = SailboatGlobal.managedPages

        managed.bodies[sailboatID] = nil
        managed.children[sailboatID] = nil
        managed.renderers[sailboatID] = nil

        // body dependencies, via the reverse index
        for stateID in managed.elementStates[sailboatID] ?? [] {
            managed.statefulElements[stateID]?.remove(sailboatID)
            if managed.statefulElements[stateID]?.isEmpty == true {
                managed.statefulElements.removeValue(forKey: stateID)
            }
        }
        managed.elementStates.removeValue(forKey: sailboatID)

        // attribute dependencies
        for (name, states) in managed.attributeStates[sailboatID] ?? [:] {
            for stateID in states {
                managed.attributes[stateID]?.remove(ElementAttribute(sid: sailboatID, value: { sailboatID }, name: name))
                if managed.attributes[stateID]?.isEmpty == true {
                    managed.attributes.removeValue(forKey: stateID)
                }
            }
        }
        managed.attributeStates.removeValue(forKey: sailboatID)
        managed.exitHandlers.removeValue(forKey: sailboatID)

        // ownership links
        if let parent = managed.statefulParent.removeValue(forKey: sailboatID) {
            managed.statefulChildren[parent]?.remove(sailboatID)
            if managed.statefulChildren[parent]?.isEmpty == true {
                managed.statefulChildren.removeValue(forKey: parent)
            }
        }
        managed.statefulChildren.removeValue(forKey: sailboatID)

        IDGenerator.expireID(sailboatID)
    }

    /// Forgets `root` and every stateful element below it, running exit handlers
    /// deepest-first. O(stateful descendants); never touches the DOM.
    public static func removeSubtreeCache(rootedAt root: SailboatID) {
        let managed = SailboatGlobal.managedPages

        var order: [SailboatID] = []
        var stack = [root]
        while let sid = stack.popLast() {
            order.append(sid)
            stack.append(contentsOf: managed.statefulChildren[sid] ?? [])
        }

        for sid in order.reversed() {
            for handler in managed.exitHandlers[sid] ?? [] {
                handler(.none)
            }
            removeCache(with: sid)
        }
    }
   
}
