//
//  List.swift
//
//
//  Created by Joshua Davis on 10/12/23.
//

public struct List: Fragment {
    
    /// hash associated with which conditional this block is in
    public var hash: String
    
    public var children: [any Page]

    nonisolated public var description: String {
        "List"
    }
    
    public init() {
        self.init([], hash: "")
    }

    public init(_ children: [any Page], hash: String) {
        self.children = children
        self.hash = hash

    }

}
