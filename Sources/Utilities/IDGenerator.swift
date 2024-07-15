//
//  IDGenerator.swift
//  
//
//  Created by Joshua Davis on 5/19/24.
//

public typealias UniqueID = UInt64

public enum IDGenerator {
    private static var currentID: UniqueID = 0
    
    public static func generateID() -> UniqueID {
        currentID += 1
        return currentID
    }
    
    // TODO: should this do anything
    public static func expireID(_ id: UniqueID) {
        return
    }
}
