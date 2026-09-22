//
//  Renderable+Build.swift
//
//
//  Created by Joshua Davis on 3/15/24.
//

public extension Renderable {
    
    /// Builds `newContent` into this renderer after DOM index `index`.
    /// Returns the next index and the snapshot nodes for the new content.
    internal func build(_ newContent: any Page, after index: Int) -> (index: Int, nodes: [RenderedNode]) {
        let managed = SailboatGlobal.managedPages
        var newIndex = index
        
        if let element = newContent as? any Element {
            let nodes = RenderableUtils.build(page: element, parent: nil)

            if newIndex != -1 {
                element.renderer.insertAfter(newIndex, parent: self)
            } else {
                element.renderer.insertBefore(0, parent: self)
            }
            
            newIndex += 1
            return (newIndex, nodes)
            
        } else if let fragment = newContent as? any Fragment {
            var nodes: [RenderedNode] = []
            for child in fragment.children {
                let built = build(child, after: newIndex)
                newIndex = built.index
                nodes.append(contentsOf: built.nodes)
            }
            return (newIndex, [.fragment(RenderedFragment(of: fragment, children: nodes))])
            
        } else {
            let mark = managed.ownershipMark()
            let built = build(newContent.body, after: newIndex)
            return (built.index, [.page(children: built.nodes, owned: managed.owned(since: mark))])
        }
    }
    
    /// Renders attributes and records which signals each one read, replacing the
    /// previous dependency set so signals no longer read stop triggering updates.
    internal func renderAttributes(_ attributes: [String: () -> any AttributeValue]) {
        let managed = SailboatGlobal.managedPages

        for (name, value) in attributes {
            self.updateAttribute(name: name, value: value())
            
            let states = SailboatGlobal.manager.dump()
            let sailboatID: SailboatID

            if states.isEmpty {
                // nothing read: drop any dependencies this attribute had before
                guard let sid = self.sailboatID, let old = managed.attributeStates[sid]?[name], !old.isEmpty else { continue }
                sailboatID = sid
                unlink(sailboatID, name, from: old, in: managed)
                managed.attributeStates[sid]?.removeValue(forKey: name)
                continue
            }

            sailboatID = managed.assignID(to: self)
            let old = managed.attributeStates[sailboatID]?[name] ?? []

            unlink(sailboatID, name, from: old.subtracting(states), in: managed)
            for stateID in states.subtracting(old) {
                managed.attributes[stateID, default: []].insert(.init(sid: sailboatID, value: value, name: name))
            }
            managed.attributeStates[sailboatID, default: [:]][name] = states
        }
    }

    private func unlink(_ sailboatID: SailboatID, _ name: String, from states: Set<StateID>, in managed: ManagedPages) {
        for stateID in states {
            managed.attributes[stateID]?.remove(ElementAttribute(sid: sailboatID, value: { sailboatID }, name: name))
            if managed.attributes[stateID]?.isEmpty == true {
                managed.attributes.removeValue(forKey: stateID)
            }
        }
    }
    
    /// Attaches events to the renderer. Exit hooks are kept in Swift and run by
    /// `removeSubtreeCache`, so the renderer never has to discover them from the DOM.
    internal func renderEvents(_ events: [String: (EventResult) -> Void]) {
        let managed = SailboatGlobal.managedPages

        for (name, event) in events {
            if ManagedPages.exitEventNames.contains(name) {
                let sid = managed.assignID(to: self)
                managed.exitHandlers[sid, default: []].append(event)
            } else {
                self.addEvent(name: name, value: event)
            }
        }
    }

    
}
