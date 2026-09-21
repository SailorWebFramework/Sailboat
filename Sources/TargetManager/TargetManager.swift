//
//  TargetManager.swift
//  
//
//  Created by Joshua Davis on 12/30/23.
//

/// Manager used for testing, does not render to DOM
@MainActor
open class TargetManager {

    /// the global environment stored here
    public var environment: (any SomeEnvironment)? = nil
    
    // TODO: state objects here, or inside of environment
    public var objects: [String: any ObservableObject] = [:]
    
    /// magages global data on a ran event
    public var eventScheduler: any EventScheduler

    /// the stored pages in memory rendered currently
    public var managedPages: ManagedPages = .init()

    public init(_ eventScheduler: any EventScheduler) { 
        self.eventScheduler = eventScheduler
    }
      
    open func build(page: any Element) {
        // ensure stateCallbackHistory is cleared
        _ = self.dump()
        
        eventScheduler.blockUpdates()
        
        RenderableUtils.build(page)
        managedPages.endOfRenderPass()
        
        eventScheduler.unblockUpdates()

        // TODO: i dont think i need this
//        _ = self.dump()
    }
    
    open func update() {
        for stateID in eventScheduler.states {
            let elements = managedPages.statefulElements[stateID] ?? []
            let attributes = managedPages.attributes[stateID] ?? []
            
            // body updates need a rerender of the body of the element
            for sailboatID in elements {
                if let renderer = managedPages.renderers[sailboatID],
                   let body = managedPages.bodies[sailboatID] {
                    print("UPDATING item: \(sailboatID)")
                    // builds the shallow content body and adds its state to the watchers
                    let content: any Fragment = body()
                             
                    let states = dump()

                    // replace the dependency set: signals this render did not read
                    // (e.g. behind a false conditional) stop triggering it
                    let previous = managedPages.elementStates[sailboatID] ?? []
                    for gone in previous.subtracting(states) {
                        managedPages.statefulElements[gone]?.remove(sailboatID)
                        if managedPages.statefulElements[gone]?.isEmpty == true {
                            managedPages.statefulElements.removeValue(forKey: gone)
                        }
                    }
                    for added in states.subtracting(previous) {
                        managedPages.statefulElements[added, default: []].insert(sailboatID)
                    }
                    managedPages.elementStates[sailboatID] = states
                    
                    renderer.reconcile(with: content)
                                        
                } else {
                    // remove elementID in states if it has been removed
                    managedPages.statefulElements[stateID]?.remove(sailboatID)
                }
            }
            
            // TODO: maybe consider batching these attribute updates somehow?
            for attribute in attributes {
                // a missing renderer means the element was removed; skip it, but keep
                // processing the remaining attributes and states in this pass
                guard let renderer = self.managedPages.renderers[attribute.sid] else { continue }

                renderer.renderAttributes([attribute.name: attribute.value])
            }
            
        }
    }
    
    // TODO: rename to like
    public func dumpDependency(state: any Stateful) {
        managedPages.stateHistory.insert(state.id)
    }
    
    // TODO: rename
    public func dump() -> Set<StateID> {
        let copy = managedPages.stateHistory
        managedPages.stateHistory.removeAll()
        return copy
    }
    
}
