# Sailboat

A signals based state management implementation built for Swift

## What is Sailboat

Sailboat is built for Sailor Frontend Web Framework, however this implementation can be used as a signals based state and update manager with SwiftUI-like libraries for any Swift application. 


## Getting Started


🔨 Working on instructions for how you can use Sailboat in your own projects 🔨 


## Components

The dom tree is composed of 3 different kinds of elements Custom Pages, Fragments, and Element Nodes.


### Page

Any component in the virtual dom conforms to the page protocol. This is used by the user to create custom pages.
Operators and Elements both implement Page

### Fragment

Fragment nodes contain a collection of Nodes and contain meta-data attached to the elements for rendering.
Custom Fragments nodes can be created with specific rendering constraints (example: a Sailor Route is an fragment node).

### Element

Element nodes are leaves of the DOM tree. A custom Page must have a root of exactly one Element node. In Sailor these are the DOM Elements.


## How it works

Sailboats Component model works a bit different then SwiftUI and adjacent libraries and does not have any maximum amount of PageBuilder elements.
This is due to Sailboats Component model. There are three main parts Custom Pages, Elements, and Operators. 


### Elements

(Subject to change, String may turn into a renderable element in Page Builder not needing the value option of element 🚧)

Elements contain either a value or an Operator. Elements are always the leaf nodes of the virtual DOM.
Elements also include attributes and events that can be used when rendering the Element outside of the DOM

```swift
public protocol Element: Page {
    /// attributes on tag
    var attributes: [String: () -> any AttributeValue] { get set }
    
    /// event names and values attached to this HTMLElement
    var events: [String: (EventResult) -> Void] { get set }
    
    /// content within HTML tags
    var content: () -> any Fragment { get set }
    
    /// used to render this element
    var renderer: any Renderable { get set }
        
}
```

In Sailor these elements are used as HTMLElements and contain either a List Fragment of children or string Fragments.


### Fragments

Fragments contain a list of children and define certain render characteristics. 
This component is not visually rendered but defines how the children it contains should be rendered.

Built in Fragment nodes
- List -> Defines a list of children
- Conditional -> Defines a conditional with children (if statement)


Nodes must not "switch" locations, and if content changes dynamically it must be wrapped in a Fragment. These fragments must have a unique hash so that Sailboat knows to update the Renderer. So the hashes must only be unique if to any other Fragment body at the same location (for example: if else statement the if body must have a different hash than the else body).

Fragments must have a unique 

```
public protocol Fragment: Page {
    var hash: String { get set }
    var children: [any Page] { get set }
}
```

## Target Manager

The target manager is stored globally in SailboatGlobal, it includes the virtual DOM body along with the environment.
It also contains the two functions needed for diffing, build(...) and update(...). 


## Stateful-Design

These property wrappers are how Sailboat manages state. 
At the end of an Event these property wrappers tell Sailboat to update the VirtualDOM


### State & Binding

Out of the box Sailboat has an implementation for State and Binding Variables are marked with the @State and @Binding property.


### Environment

Environment is designed to be extensible by the reconceliation libarary by conforming to SomeEnvironment, and include any enviroment properties desired by the wrapped framework.
These properties can be called by the @Environment using a KeyPath of the entire object.


### EnvironmentObjects


EnvironmentObjects are also work much like swiftUI using the @EnvironmentObject Property Wrapper


## Macros

In the future sailboat hopes to support a series of macros. 

## Diffing

This is my designed Diffing algorithm, inspired by other web frameworks and trail and error.
Currently not all parts are implemented but going to be.

### Basic Overview

Virtual DOM nodes of each "Component" are stored in memory (the heap), once a state variable or environment variable changes it triggers a rerender.
Any components that change based off the new state values get replaced in the DOM tree.

### Batched Updates

When an update event starts it modifies all the States until the update event is concluded.

For example in Sailor...

```swift
struct BatchedUpdatePage: Page {
    @State var age: Int = 0
    @State var name: String = "Josh"
    
    var body: some Page {
        Div{
            Span("\(name): \(age)")
        }
        .onClick {
            age += 1
            name += "!" 
        }
    }
}
```

Once age gets incremented instead of immediatly updating the DOM sailboat should wait until the full update event of OnClick is concluded to update the DOM.
In this example it is incrementing the age and changing the name


### Signals

Instead of updating the entire DOM or an entire custom page hirarchy that relies on a state. 
Sailboat should only update elements that include the actual state with @State or binded state with @Binding.

This is achieved by caching which states values map to each custom page

```
[
    CustomPage1: [1, 2, 3] // relies on states 1, 2, and 3
    CustomPage2: [3, 4, 5] // relies on states 3, 4, and 5
]

```

In the example above, theres no need to update CustomPage2 if only states 1 and 2 are modified, 
saving computation. Only when state 3 is modified do both pages need to be updated.
With many more custom pages and states the efficiency can be seen much more


This is achived on build by globally registering states when the DOM tree is created & modified.

```
Building Page 0 -> Contains states 0, 1 -> add to map
Building Page 1 -> Contains states 1, 2 -> add to map
Building Page 3 -> Contains states 3 -> add to map
Building Page 4 -> Contains no states 
Building Page 5 -> Contains states 4, 5, 6, 7 -> add to map
ect.
```

Upon re-rendering a page it will rerender all elements except Custom Pages if the states do not intersect.
Due to the way swift handles strings composition it is difficult to get any more granular updating.


### Events


Events added to Elements must never change for the lifetime of the elements and will not be diffed.


### Attributes


Attributes may change over the lifetime of elements and will be dependency tracked. They also can update independently of the elements body, and efficiently update only when neccisary.


### More In-Depth Dive


🔨 Working a more in depth design of Sailboat  🔨 


### Update Priorities

Some jobs should have more priority in an update than others .

(Under Construction 🚧)


## Extensible Design

Sailboat is lightweight and designed to be able to be used in a variety of codebases.
Sailboat does not include any Elements which can be created by the user to create a reactive framework.



