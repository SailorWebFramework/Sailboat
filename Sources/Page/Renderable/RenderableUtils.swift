//
//  File.swift
//  
//
//  Created by Joshua Davis on 3/17/24.
//


@MainActor
public enum RenderableUtils {
    
    //TODO: remove? and just use the other build function with =nil default value
    ///
    public static func build(_ element: any Element) {
        build(page: element, parent: nil)
    }

    /// build a page to this renderer and add it to parent
    public static func build(page: any Page, parent: (any Element)?) {
        // if page is an Operator
        if let page = page as? any Fragment {
            
            // add children
            for child in page.children {
                build(page: child, parent: parent)
            }
            
            return
        }
        
        // if page is an HTMLElement
        if let page = page as? any Element {
            
            // run the page builder closure to create an operator node
            let operatorPage = page.content()
            
            SailboatGlobal.managedPages.registerElement(page, operatorPage)
            
            // render current page to parent
            page.renderer.renderAttributes(page.attributes)
            page.renderer.renderEvents(page.events)

            build(page: operatorPage, parent: page)
            
            if let parent = parent {
                page.renderer.addToParent(parent.renderer)
            }
            
            return
        }
        
        build(page: page.body, parent: parent)
        
    }
    
    public static func removeCache(with sailboatID: SailboatID) {
        SailboatGlobal.managedPages.bodies[sailboatID] = nil
        SailboatGlobal.managedPages.children[sailboatID] = nil
        SailboatGlobal.managedPages.renderers[sailboatID] = nil

        // Use reverse index to remove in O(state count of this element)
        // instead of the old O(total states × elements) nested iteration.
        let stateIDs = SailboatGlobal.managedPages.elementStates[sailboatID] ?? []
        for stateID in stateIDs {
            SailboatGlobal.managedPages.attributes[stateID] = SailboatGlobal.managedPages.attributes[stateID]?.filter {
                $0.sid != sailboatID
            }
            SailboatGlobal.managedPages.statefulElements[stateID]?.remove(sailboatID)
            if SailboatGlobal.managedPages.statefulElements[stateID]?.isEmpty == true {
                SailboatGlobal.managedPages.statefulElements.removeValue(forKey: stateID)
            }
        }
        SailboatGlobal.managedPages.elementStates.removeValue(forKey: sailboatID)

        IDGenerator.expireID(sailboatID)
    }
   
}
