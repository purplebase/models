# Architecture Overview

This document provides a technical overview of the Models library - a fast, local-first Nostr framework for Dart applications.

## What is Models?

Models is a Dart library that provides a high-level, domain-driven interface for working with the Nostr protocol. It abstracts away the complexity of raw Nostr events and provides type-safe, reactive access to social media data with built-in relationships and local storage.

## Core Design Principles

1. **Domain-First**: Work with `Note`, `Profile`, `Reaction` objects instead of raw JSON events
2. **Local-First**: Data is stored locally and synchronized with relays in the background
3. **Reactive**: Built on Riverpod for reactive state management
4. **Type-Safe**: Full Dart type safety with compile-time guarantees
5. **Extensible**: Easy to add new Nostr event kinds and customize behavior

## High-Level Architecture

```mermaid
graph TB
    App[Flutter/Dart App] --> Models[Models Library]
    
    subgraph "Models Library"
        Domain[Domain Models<br/>Note, Profile, Reaction, etc.]
        Storage[Storage Layer<br/>Abstract Interface]
        Signer[Signer System<br/>Event Signing]
        Relay[Relay System<br/>WebSocket Communication]
        Query[Query System<br/>Reactive Queries]
    end
    
    subgraph "Storage Implementations"
        Dummy[Dummy Storage<br/>In-Memory]
        SQLite[SQLite Storage<br/>Persistent]
    end
    
    subgraph "External Systems"
        NostrRelays[Nostr Relays<br/>WebSocket]
        LocalDB[(Local Database)]
    end
    
    Models --> Storage
    Storage --> Dummy
    Storage --> SQLite
    Storage --> LocalDB
    Relay --> NostrRelays
    
    Domain -.-> Query
    Query -.-> Storage
    Signer -.-> Domain
```

## Core Components

### 1. Event System

The library uses a two-phase event system:

```mermaid
graph LR
    PartialEvent[PartialEvent<br/>Mutable, Unsigned] --> |sign| ImmutableEvent[ImmutableEvent<br/>Immutable, Signed]
    
    subgraph "Event Types"
        Regular[Regular Events<br/>Kind 1, 7, etc.]
        Replaceable[Replaceable Events<br/>Kind 0, 3, etc.]
        Parameterized[Parameterized<br/>Kind 30000+]
        Ephemeral[Ephemeral Events<br/>Kind 20000+]
    end
    
    ImmutableEvent --> Regular
    ImmutableEvent --> Replaceable
    ImmutableEvent --> Parameterized
    ImmutableEvent --> Ephemeral
```

**Key Classes:**
- `PartialEvent<E>`: Mutable, unsigned events ready for signing
- `ImmutableEvent<E>`: Signed, immutable events from storage/relays
- `EventBase<E>`: Common interface with tag utilities

### 2. Domain Models

Models wrap events and provide domain-specific interfaces:

```mermaid
graph TD
    Model[Model&lt;E&gt;] --> |extends| RegularModel[RegularModel<br/>Notes, Reactions, etc.]
    Model --> |extends| ReplaceableModel[ReplaceableModel<br/>Profiles, Contact Lists]
    Model --> |extends| ParameterizableModel[ParameterizableReplaceableModel<br/>Articles, Apps, etc.]
    Model --> |extends| EphemeralModel[EphemeralModel<br/>Auth events, etc.]
    
    subgraph "Example Models"
        Note[Note<br/>kind: 1]
        Profile[Profile<br/>kind: 0]
        Reaction[Reaction<br/>kind: 7]
        Article[Article<br/>kind: 30023]
    end
    
    RegularModel --> Note
    RegularModel --> Reaction
    ReplaceableModel --> Profile
    ParameterizableModel --> Article
```

**Key Features:**
- **Type Safety**: Each model corresponds to a specific Nostr event kind
- **Relationships**: Built-in `author`, `reactions`, `zaps` relationships
- **Metadata Processing**: Lazy parsing of complex data (e.g., zap amounts)
- **Storage Integration**: Direct `save()` and `publish()` methods

### 3. Storage Layer

The storage layer provides a unified interface for local and remote data:

```mermaid
graph TB
    StorageNotifier[StorageNotifier<br/>Abstract Interface] --> |implements| DummyStorage[DummyStorage<br/>In-Memory]
    StorageNotifier --> |implements| SQLiteStorage[SQLiteStorage<br/>Persistent]
    
    subgraph "Data Sources"
        LocalSource[LocalSource<br/>Local DB Only]
        RemoteSource[RemoteSource<br/>Relays Only]
        LocalAndRemote[LocalAndRemoteSource<br/>Both]
    end
    
    Query[Query System] --> StorageNotifier
    StorageNotifier --> LocalSource
    StorageNotifier --> RemoteSource
    StorageNotifier --> LocalAndRemote
    
    subgraph "Storage Operations"
        QueryOp[query&lt;T&gt;]
        SaveOp[save]
        PublishOp[publish]
        ClearOp[clear]
    end
    
    StorageNotifier --> QueryOp
    StorageNotifier --> SaveOp
    StorageNotifier --> PublishOp
    StorageNotifier --> ClearOp
```

**Key Features:**
- **Source Control**: Choose between local-only, remote-only, or hybrid queries
- **Reactive**: Built on Riverpod StateNotifier for reactive updates
- **Pluggable**: Easy to implement custom storage backends
- **Streaming**: Background synchronization with configurable batching

### 4. Signer System

The signer system handles event creation and signing:

```mermaid
graph TB
    Signer[Signer<br/>Abstract Base] --> |extends| PrivateKeySigner[Bip340PrivateKeySigner<br/>Local Private Key]
    Signer --> |extends| DummySigner[DummySigner<br/>Testing/Development]
    Signer --> |extends| ExternalSigner[External Signers<br/>Amber, etc.]
    
    subgraph "Signing Process"
        PartialModel[PartialModel] --> |signWith| SignedModel[Model]
        PartialModel --> |dummySign| DummyModel[Model]
    end
    
    subgraph "Signer Management"
        ActiveSigner[Active Signer Provider]
        SignedInUsers[Signed In Users]
        ActiveProfile[Active Profile Provider]
    end
    
    Signer --> ActiveSigner
    Signer --> SignedInUsers
    Signer --> ActiveProfile
```

**Key Features:**
- **Multiple Signers**: Support for different signing methods
- **User Management**: Track signed-in users and active profiles
- **Encryption**: NIP-04 and NIP-44 message encryption
- **Reactive**: Riverpod providers for authentication state

### 5. Relationship System

Models can reference other models through relationships:

```mermaid
graph LR
    Note[Note] --> |BelongsTo| Author[Profile]
    Note --> |HasMany| Reactions["List&lt;Reaction&gt;"]
    Note --> |HasMany| Zaps["List&lt;Zap&gt;"]
    Note --> |BelongsTo| RootNote[Note]
    Note --> |HasMany| Replies["List&lt;Note&gt;"]
    
    subgraph "Relationship Types"
        BelongsTo[BelongsTo&lt;T&gt;<br/>Single Related Model]
        HasMany[HasMany&lt;T&gt;<br/>Collection of Models]
    end
    
    subgraph "Loading Strategies"
        Sync[Synchronous<br/>querySync]
        Async[Asynchronous<br/>valueAsync/toListAsync]
        Reactive[Reactive<br/>Watch relationships]
    end
    
    BelongsTo --> Sync
    BelongsTo --> Async
    HasMany --> Sync
    HasMany --> Async
    HasMany --> Reactive
```

**Key Features:**
- **Lazy Loading**: Relationships are loaded on demand
- **Type Safety**: Compile-time guarantees for relationship types
- **Caching**: Efficient caching of relationship queries
- **Reactive**: Can be watched for changes

### 6. Query System

Reactive queries provide a familiar interface similar to Nostr filters:

```mermaid
graph TB
    QueryFunction[query&lt;T&gt;] --> RequestFilter[RequestFilter&lt;T&gt;]
    
    subgraph "Filter Options"
        Authors[authors: Set&lt;String&gt;]
        Kinds[kinds: Set&lt;int&gt;]
        Tags[tags: Map&lt;String, Set&lt;String&gt;&gt;]
        TimeRange[since/until: DateTime]
        Limit[limit: int]
        Search[search: String]
    end
    
    subgraph "Advanced Options"
        Where[where: Function]
        And[and: Function<br/>Preload relationships]
        Source[source: Source]
    end
    
    RequestFilter --> Authors
    RequestFilter --> Kinds
    RequestFilter --> Tags
    RequestFilter --> TimeRange
    RequestFilter --> Limit
    RequestFilter --> Search
    RequestFilter --> Where
    RequestFilter --> And
    RequestFilter --> Source
    
    subgraph "State Management"
        StorageLoading[StorageLoading]
        StorageData[StorageData]
        StorageError[StorageError]
    end
    
    QueryFunction --> StorageLoading
    QueryFunction --> StorageData
    QueryFunction --> StorageError
```

**Usage Example:**
```dart
final notesState = ref.watch(
  query<Note>(
    authors: {userPubkey},
    limit: 20,
    since: DateTime.now().subtract(Duration(days: 7)),
    and: (note) => {note.author, note.reactions, note.zaps},
  ),
);
```

## Data Flow

### 1. Reading Data

```mermaid
sequenceDiagram
    participant App
    participant Query
    participant Storage
    participant LocalDB
    participant Relay
    
    App->>Query: query<Note>(authors: {...})
    Query->>Storage: query(request, source)
    
    alt LocalAndRemoteSource
        Storage->>LocalDB: querySync()
        LocalDB-->>Storage: Local results
        Storage->>Relay: subscribe(filters)
        Relay-->>Storage: Stream events
        Storage-->>Query: Reactive updates
    else LocalSource
        Storage->>LocalDB: querySync()
        LocalDB-->>Storage: Local results
    else RemoteSource
        Storage->>Relay: subscribe(filters)
        Relay-->>Storage: Stream events
    end
    
    Query-->>App: StorageState<Note>
```

### 2. Creating Data

```mermaid
sequenceDiagram
    participant App
    participant PartialNote
    participant Signer
    participant Storage
    participant LocalDB
    participant Relay
    
    App->>PartialNote: new PartialNote(content)
    App->>Signer: partialNote.signWith(signer)
    Signer->>Signer: sign(event)
    Signer-->>App: Note (signed)
    
    App->>Storage: note.save()
    Storage->>LocalDB: save(note)
    LocalDB-->>Storage: success
    
    App->>Storage: note.publish()
    Storage->>Relay: publish(note)
    Relay-->>Storage: OK/NOTICE
    Storage-->>App: PublishResponse
```

### 3. Reactive Updates

```mermaid
sequenceDiagram
    participant Widget
    participant Riverpod
    participant Storage
    participant LocalDB
    participant Relay
    
    Widget->>Riverpod: ref.watch(query<Note>())
    Riverpod->>Storage: subscribe to changes
    
    loop Background Sync
        Relay->>Storage: new event
        Storage->>LocalDB: save event
        Storage->>Riverpod: notifyListeners()
        Riverpod->>Widget: rebuild with new data
    end
```

## Key Design Patterns

### 1. Domain-Driven Design
- **Models**: Rich domain objects with behavior
- **Value Objects**: Immutable data structures (Events)
- **Repositories**: Storage abstraction layer
- **Services**: Signers, verifiers, utilities

### 2. CQRS (Command Query Responsibility Segregation)
- **Commands**: `save()`, `publish()`, `sign()`
- **Queries**: `query<T>()`, relationship navigation
- **Separate Models**: `PartialModel` for commands, `Model` for queries

### 3. Event Sourcing
- **Immutable Events**: All changes represented as events
- **Append-Only**: Events are never modified, only added
- **Replay**: Models can be reconstructed from events

### 4. Reactive Programming
- **Streams**: Continuous data flow from relays
- **Observables**: Riverpod providers for state management
- **Declarative**: UI declares what data it needs

## Extension Points

### 1. Custom Event Kinds

```dart
@GeneratePartialModel()
class CustomEvent extends RegularModel<CustomEvent> {
  CustomEvent.fromMap(super.map, super.ref) : super.fromMap();
  
  String get customField => event.getFirstTagValue('custom') ?? '';
}

// Register in storage initialization
Model.register(kind: 40000, constructor: CustomEvent.fromMap);
```

### 2. Custom Storage Backend

```dart
class CustomStorage extends StorageNotifier {
  @override
  Future<void> initialize(StorageConfiguration config) async {
    super.initialize(config); // Register built-in types
    // Custom initialization
  }
  
  @override
  Future<List<E>> query<E extends Model<dynamic>>(
    Request<E> req, {Source source = const LocalAndRemoteSource()}
  ) async {
    // Custom query implementation
  }
  
  // Implement other abstract methods...
}
```

### 3. Custom Signer

```dart
class CustomSigner extends Signer {
  @override
  Future<List<E>> sign<E extends Model<dynamic>>(
    List<PartialModel<Model<dynamic>>> partialModels
  ) async {
    // Custom signing logic
  }
  
  // Implement encryption methods...
}
```

## Performance Considerations

1. **Lazy Loading**: Relationships are loaded on demand
2. **Caching**: Local storage acts as a cache layer
3. **Streaming**: Background sync with configurable batching
4. **Memory Management**: Configurable limits on stored models
5. **Signature Optimization**: Optional signature stripping for space

## Testing Strategy

1. **Dummy Implementation**: Built-in in-memory storage for testing
2. **Dummy Signer**: No-op signer for development
3. **Fake Data**: Built-in faker integration for generating test data
4. **Mocking**: Easy to mock storage and signer interfaces

---

This architecture provides a solid foundation for building Nostr applications in Dart while maintaining flexibility for customization and extension. 