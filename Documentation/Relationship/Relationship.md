# Retrieving Relationship Information

This proposal describes how relationship information can be generated from the DSL, introduces some concepts
to give hints for relationship retrieval and adds mechanisms to manually define hints.

* A **REST** Interface Exporter will use such relationship information to generate Hypermedia information.
Specifically it will generate hyperlinks which SHOULD be placed in a designated `_links` section.
A REST exporter MAY also inline those links if it can ensure that no name collisions occur.  
This document proposes that [RFC 6570 URI Template](https://tools.ietf.org/html/rfc6570) SHOULD be used to encode those links.
Alternatively there are also more extensive JSON schemas which allow to provide more information about the structure of
the endpoint (e.g. [JSON API](https://jsonapi.org),
[JSON Hyper-Schema](https://json-schema.org/draft/2019-09/json-schema-hypermedia.html),
[Siren](https://github.com/kevinswiber/siren), [HAL](http://stateless.co/hal_specification.html)).

* A **GraphQL** exporter will use such relationship information - additionally to the structure given by `PathComponent`s -
to generate the query schema.

The following chapters explain how such relationship information is retrieved.

## 1. Using the DSL "structure"

The path structure of the Webservice can be used to infer relationship information.  

Given the following rather extensive example of a webservice:
```swift
@PathParameter var userId: User.ID
@PathParameter var postId: Post.ID

var content: some Component {
  Group("user", $userId) {
    UserHandler(userId: $userId)
    Group("post", $postId) {
      PostHandler(userId: $userId, postId: $postId)
    }
    Group("static-info") {
      StaticInfoHandler(userId: $userId)
      Group("detailed") {
        DetailedStaticInfoHandler(userId: $userId)
      }
    }
    Group("a") {
      Group("a") {
        AAHandler()
      }
      Group("b") {
        ABHandler()
      }
      Group("c") {
        Group("a") {
          ACAHandler()
        }
      }
    }
  }
}
```

To create Relationships for a Endpoint, Apodini will go through all subpath for the current path. A relationship is then
created to all Endpoints located under that subpath. Should it be the case, that there aren't any Endpoints registered
under that subpath, Apodini will recursively search for endpoints in subpaths of the subpath.

To make this more understandable consider the following pseudo code:
```swift
for child in children {
  child.collectRelationships()
}
func collectRelationships() { 
  if !endpoints.isEmpty {
    // adding endpoint to relationships
    return 
  } 

  for child in children { 
   child.collectRelationships() 
  } 
} 
```

<br> 

Not explicitly created, but specifically important for the REST Interface Exporter: An Endpoint will always maintain a
Relationship to itself with the name `self` (thus `self` is a reserved relationship name).  
In the case that there is also a subroute with the `PathComponent` named `self` a name conflict would occur.
As such a name conflict problem is unique to the REST exporter this proposal suggest that such a Relationship SHOULD
be shadowed by the self referencing hyperlink.  
The REST exporter SHOULD print a warning on startup on such occasions. 

**REST:**  
For the above example a `GET /user/532` request would return the following response:
```json
{
  "id": "532",
  "name": "Rudi",
  "lastname": "Raser",
  "email": "rudi@raser.de",
  "_links": {
    "self": "https://example.api/user/532",
    "post": "https://example.api/user/532/post/{postId}",
    "static-info": "https://example.api/user/532/static-info",
    "a_a": "https://example.api/user/532/a/a",
    "a_b": "https://example.api/user/532/a/b",
    "a_c_a": "https://example.api/user/532/a/c/a"
  }
}
```

One of the core concepts of REST (with HATEOAS) is, that a client does not need to know anything about the path structure.
Instead, just like a web browser, a client follows hyperlinks returned from the web service.  
This allows you to change the path structure of your REST service - keeping the same named links at the same places -
without breaking compatibility for your clients.    
To support such scenarios, chapter [3.](#3-manually-defining-relationship-information) illustrates some ways
to manually define or modify relationship information.

**GraphQL:**  
For the above example a GraphQL query could look like the following:
```graphql
query {
  user(id: "532") {
    name
    lastname
    post(id: "123") {
      title
    }
    static-information {
      info0
      detailed {
        detailedInfo0
      }
    }
  }
}
```

## 2. Using Type Information

Checking the structure of the web service ([1.](#1-using-the-dsl-structure)) is already pretty powerful,
but doesn't allow for relationships between handlers which are on the same level or on different paths of the path component tree.  
This chapter highlights how we can nonetheless retrieve relationship information by looking at type information
(and without the need for the user to specify everything manually).

### 2.1 Indexing Endpoints by their `Handler` return type

In order to derive relationships from type information, we first need to collect type information of all Endpoints. 

The process of creating the return type Index is demonstrated using the following example web service:

```swift
struct User: Identifiable {
  var id: String
  var name: String
  var lastname: String
  var email: String
}

struct StatusInformation {
  var uptime: UInt64
  // ...
}

struct TestService: WebService {
  @PathParameter var userId: User.ID

  var content: some Component {
    Group("status") {
      StatusInformationHandler()
    }
    Group("user", $userId) {
      UserHandler(userId: $userId)
    }
  }
}
```

It can be observed that the `StatusInformationHandler` returns instances of type `StatusInformation`.
This information is saved, so that we can for a certain type list all Endpoints which return that exact type.  
The goal is then, that the user can annotate endpoints or data structures with type information (e.g. `StatusInformation.self`)
 to indicate relationships. This is explained in the following chapters.

If we detect, that the return type of a `Handler` conforms to the `Identifiable` protocol, there are some
additional steps we need to check. 
* If we can match the type of the `.id` property to any `@PathParameter` (with the same type) contained in the path,
    we save that return type to our index (Though: see note below).
* We we can't match the `.id` property to any `@PathParameter` the `Handler` will be ignored and not indexed.
Instead such endpoints can be used as a source of relationship information
(see [2.3.](#231-implicitly)).

Some special cases:
* Endpoints containing a `@PathParameter` in their path, but not returning a type
 conforming `Identifiable` in their `handle()` (meaning we can't match a property to the path parameter), will not be indexed.
* In a case where multiple `Handler` return the same type (e.g. multiple handlers returning `StatusInformation`)
non of them are added to the index. Instead we rely on the user to mark the appropriate `Handler`,
see [2.2.](#22-using-defaultrelationship-to-resolve-ambiguous-return-type-information).

_Note: As the type of a `@PathParameter` is a `LosslessStringConvertible` it most certainly is either a 
`String` or an `Int`. Meaning, checking if the type of the `User.id` property is equal to `User.ID` type might
not be strong enough.
Thus it could be necessary for `@PathParemeter`s to specify the type: e.g. `@PathParameter(type: User.self)` where
the `type` argument must conform to the `Identifiable` protocol (or something similar, as `Identifiable.ID` conforms 
to `Hashable` and we actually need `LosslessStringConvertible`).
This would also need to be addressed for `@Parameter(.http(.path))` declarations._

### 2.2. Using `.defaultRelationship` to resolve ambiguous return type information

As describe in [2.1.](#21-indexing-endpoints-by-their-handler-return-type) Apodini won't index type information
if it isn't unambiguous.

In such cases where there are multiple `Handler` returning the same type, the user can use `.defaultRelationship` to
explicitly mark which Endpoint should be indexed for the given return type.  

```swift
struct StatusInformation {
  var uptime: UInt64
  // ...
}
// ...
var content: some Component {
  Group("status") {
    StatusInformationHandler()
      .defaultRelationship()
  }
  Group("status-information") {
    StatusInformationHandler()
  }
}
```

### 2.3. Creating Relationships by referencing type information

After the last few chapters have shown how endpoints can be indexed by their return type.
This chapter describes how we can create relationships to those endpoints by referencing those indexed return types.

#### 2.3.1 Implicitly

In [2.1](#21-indexing-endpoints-by-their-handler-return-type) we already talked about `Handlers` which return
a type conforming to `Identifiable`, but don't have a matching `@PathParameter`.

The `MeUserHandler` of the following example falls into this category:
```swift
struct TestService: WebService {
  @PathParameter var userId: User.ID

  var content: some Component {
    Group("user", $userId) {
      UserHandler(userId: $userId)
      // could contain other routes giving more information for the given user, e.g. ./posts/:postId
    }
    Group("me") {
      MeUserHandler() // returns type `User`
    }
  }
}
```

In such a case we can contact our type index we built in [2.1](#21-indexing-endpoints-by-their-handler-return-type)
and search for any endpoints responsible for this type.  
In the example above we would find `UserHandler`. Thus `MeUserHandler` will inherit any relationship information
from `UserHandler` (most importantly the `self` relationship for the REST Interface Exporter).

This approach heavily relies on the fact that the `MeUserHandler` returns the same type as the `UserHandler`.
As this might not always be given, one can also annotate that explicitly using the mechanism described in
[2.3.2.2](#2322-relationship-definition-inherits).

#### 2.3.2 Explicitly

##### 2.3.2.1 Relationship Metadata: `References`

For this chapter we consider the following example:

```swift
struct Article: Content, Identifiable {
  var id: String
  var heading: String
  var content: String

  var writtenBy: String

  static var metadata: Metadata {
    References<User>(as: "author", identifiedBy: \.writtenBy)
  }
}
// ...
var content: some Component {
  Group("user", $userId) {
    UserHandler(userId: $userId)
  }
  Group("article", $articleId) {
    ArticleHandler(articleId: $articleId)
  }
}
```

The idea is, that every `Article` is written by a certain `User` (aka the author).
As querying `User` instances is handled by the `UserHandler`, the `Article` must be able to reference
that somehow. This can be done by creating a relationship `References` definition for a property which holds a unique
identifier for some type (conforming to `Identifiable`).

In the example, the user indicates that the `Article` struct references a `User` instance with the `.writtenBy` property
(meaning that property hold the value for the `.id` property of the `User` type) and additionally specifies
that the relationship is called `author`.  
With the specified type information we can search for the endpoint as describe in
[2.1.](#21-indexing-endpoints-by-their-handler-return-type).

Exporters which make use of relationship information (REST and GraphQL) MUST NOT incorporate the property
(in the example`writtenBy`) into the response or the query schema. Instead it is replaced by the defined relationship.    
Other exporters should ideally rename such fields by adding a `Id` suffix (e.g. `writtenById`).

**REST:**  
Below is a example response generated from a REST exporter for such a `ArticleHandler`:

```json
{
  "id": "3826",
  "heading": "Retrieving Relationship Information",
  "content": "...",
  "_links": {
    "author": "https://example.api/user/472",
    "self": "https://example.api/article/3826"
  }
}
```

**GraphQL:**  
A graphql query could look like the following:
```graphql
query {
  article(id: "3826") {
    heading
    content
    author {
      id
      name
      lastname
    }
  }
}
```

##### 2.3.2.2 Relationship Metadata: `Inherits`

A special case to the previous chapter is when you want to create a Relationship definition for the primary identifier
of the data structure (e.g. the `.id` property of an `Identifiable`).  

We have seen how this can work automatically in [2.3.1](#231-implicitly), when the return type of two `Handler` is the same.  
But as explained, this isn't possible if the return types don't match up.

Instead the user can explicitly define a `self` relationship. As we don't want the user to rely on any magic string constant
(e.g. by defining `References<User>(as: "self", identifiedBy: \.id)`) we introduce another relationship definition
type `Inherits<User>(identifiedBy: \.id)`. 
Additionally a `References` definition MUST NOT have the reserved name `self`.  
Similar to [2.3.1](#231-implicitly) such a `Inherits` definition will inherit all relationship information from the
destination.

The example below illustrates such a definition.

```swift
struct MeUser: Content, Identifiable {
  var id: String
  var loginToken: String

  static var metadata: Metadata {
    Inherits<User>(identifiedBy: \.id)
  }
}
// ...
var content: some Component {
  Group("user", $userId) {
    UserHandler(userId: $userId)
    // could contain other routes giving more information for the given user, e.g. ./posts/:postId
  }
  Group("me") {
    MeUserHandler()
  }
}
```

**REST:**  

A REST exporter will inherit the `_links` section from `/user/:userId`, any relationships of that route but also
overwriting the `self` link.

A request to the `me` endpoint would then generate a response like the following:
```json5
{
  "id": "532",
  "loginToken": "rik0O1YK5wKjUY6CASjVRik0O1YK5wKjUY6CASjV",
  "_links": {
    "self": "https://example.api/user/532",
    "post": "https://example.api/user/532/post/{postId}"
  }
}
```

**GraphQL:**  

In order for the querier to be able to access properties of `User`, the GraphQL exporter would need to
inline properties contained in `User` but not contained in `MeUser`.

A graphql query for the given example might look like the following:

```graphql
query {
  me {
    id
    loginToken
    name
    lastname
    post(postId: "123") {
      title
    }
  }
}
```

## 3. Manually defining Relationship Information

This chapter imagines ways how a user could manually override or make modifications to relationship information.

To provide such functionality the proposal introduces multiple `PathComponentModifiers`, similar to the already
existing `ComponentModifiers`. As the `PathComponents` are passed as arguments to a `Group` instance,
this could quickly get messy in terms of code readability.

Thus this proposal additionally introduces a `PathComponentFunctionBuilder` with a corresponding initializer for the `Group` struct.
Examples are shown in the following sub chapters.

### 3.1. Overriding the relationship name

The in chapter [1.](#1-using-the-dsl-structure) described inference approach uses the string 
description of the `PathComponent` as the relationship name. This may not fit everybody's needs.

Such a customization mechanism is provided with the `.relationship` modifier (with the external parameter `name`):

```swift
var content: some Component {
  Group {
    "test".relationship(name: "new-name")
  } content: {
    Handler()
  }
}
```

The same `PathComponent` name cannot be used multiple times on the same depth in the `PathComponent` tree.
Similarly the renamed Relationship MUST NOT collide with any other relationship name on the same depth.

### 3.2. Adding new relationships

To support rearranging components without breaking HATEOAS linking information or the GraphQL query schema,
a user can also **add** their own relationship definitions.

#### 3.2.1. Providing type hints

By using the information gained in [2.1.](#21-indexing-endpoints-by-their-handler-return-type) and
[2.2.](#22-using-defaultrelationship-to-resolve-ambiguous-return-type-information), the user can create manual relationships
just be specifying the return type of the destination and the relationship name using the `.relationship(name:to:)` modifier.

Such a definition might look like the following:

```swift
struct TestService: WebService {
  @PathParameter var userId: User.ID

  var content: some Component {
    Group {
      "user"
      $userId
        .relationship(name: "greeter", to: Greeting.self)
    } content: {
      Handler()
    }
    Group("greeting", $userId) {
      Greeter() // returns Greeting
    }
  }
}
```

**REST:**  
A request to the `/user/:userId` endpoint would look like the following:

```json
{
  "id": "123",
  "name": "Rudi",
  "lastname": "Raser",
  "_links": {
    "self": "https://example.api/user/123",
    "greeter": "https://example.api/greeting"
  }
}
```

**GraphQL:**  
A graphql endpoint could receive the following query:

```graphql
query {
  user(id: "123") {
    id
    name
    lastname
    greeter {
      ...
    }
  }
}
```

#### 3.2.2. Creating `Relationship` instances 

As we don't want users to manually list every `PathComponent` for the destination of the relationship, the user can create
instances of `Relationship` which are then referenced with `.destination(of:)` and
`.relationship(to:)` modifiers.

Those `Relationship` instances can be defined anywhere, preferably as a property of a `Component`.

The example below showcases the use of a `Relationship` instance:

```swift
struct TestService: WebService {
  @PathParameter var userId: User.ID

  let greeterRelationship = Relationship("greeter") 

  var content: some Component {
    Group {
      "user"
      $userId
        .relationship(to: greeterRelationship)
    } content: {
      Handler()
    }
    Group("greeting", $userId) {
      Greeter()
        .destination(of: greeterRelationship)
    }
  }
}
```

### 3.3. Hiding Relationships

Specifically for the REST Interface Exporter it may be a sensible decision for a user to hide relationship information
generated by Apodini.

This is made possible by introducing a `.hideLink` modifier.

The GraphQL Interface Exporter MUST ignore the `hidden` flag and treat it like any other relationship.

<br>

Considering the example below, a REST exporter would not include the `test` relationship when serving a request to `/`.
But a request directly made to `/test` will nonetheless be answered.

If GraphQL would not ignore the `hidden` flag, the endpoint `/test` would no longer be accessible.  
Thus GraphQL will ignore the `hidden` flag and the modifier is specifically named `hideLink` (and not `hideRelationship`)
to indicate this behavior.

```swift
var content: some Component {
  Group {
    "test".hideLink()
  } content: {
    Handler()
  }
}
```

## 4. Appendix

### 4.1. Discussion: DSL vs. Property Wrapper

The draft version of this document proposed that instead of using a DSL approach for the two relationship definitions
`References` and `Inherits` we could use property wrappers to annotate those properties which hold the `Identifiable.ID`
value for the referenced type.  
This would be for one pretty elegant, but we could also treat Fluents `@Parent` the same way as a `@References`.

However this approach doesn't meet our requirements.  
Relationship information must be available at startup, so e.g. GraphQL can create its query schema.
Information stored in property wrappers can only be inspected when having a instance of that type
(and experiments (ab)using `createInstance` of the Runtime frame have failed).  
Consequentially we can't use Property Wrappers.

### 4.2. Thought experiment: Reverse lookup for relationship definitions

Given the example web service from [2.3.2.1](#2321-relationship-definition-references):
```swift
@PathParameter var userId: User.ID

var content: some Component {
  Group("user", $userId) {
    UserHandler(userId: $userId)
  }
  Group("article", $articleId) {
    ArticleHandler(articleId: $articleId)
  }
}
```

_Background: One could imagine that in the future a REST exporter could automatically generate
Pagination handlers for collection endpoints like `/user` and `/article`. At this point the pagination
generator could be extended to also incorporate some relationship functionality._

As describe in [2.3.2.1](#2321-relationship-definition-references) we can already add a relationship to the `.author` in every response
returned on the `/article/:articleId` endpoint.
What we currently can't do is the reverse lookup, retrieve all articles written by a certain `User`.
Right now the user would need to manually support that by supplying an appropriate `Handler`.  
Provided that the REST exporter is able to generate such a pagination route, this feature could be extended
to incorporate relationship information and add support for a `author` query parameter.  
A request to `/article?author={userId}` would then return a array of articles written by the specified `User`.
