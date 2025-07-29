# Changelog

## [0.3.3] - 2025-07-28

We are starting Changelogs today, so this release shows more than it actually covers.

### Added
- **NostrWalletConnect (NWC)** - Complete NIP-47 implementation for Lightning wallet integration
  - `NwcInfo`, `NwcRequest`, `NwcResponse` models for wallet communication
  - Connection management with secure storage (`setNWCString`, `getNWCString`, `clearNWCString`)
  - Support for all major NWC commands: `pay_invoice`, `get_balance`, `make_invoice`, `lookup_invoice`, `list_transactions`, `get_info`
  - Encrypted storage of connection strings using NIP-44
  - Complete test suite for NWC functionality
- **Built-in Nostr Relay Server** - Production-ready relay implementation
  - Standalone `dart_relay` binary for running relay servers
  - Full WebSocket support with Nostr protocol compliance
  - In-memory event storage for development and testing
  - Real-time subscription management
  - Support for core NIPs (1, 2, 9, 10, 11, 42, 50)
  - Command-line interface with configurable port and host
- **New Query Providers**:
  - `queryKinds()` - Query events across multiple kinds without type constraints
  - `query<E>()` - Type-safe queries for specific model types
  - `model<E>()` - Watch specific model instances for updates
- **Enhanced Authentication & Signer System**:
  - `Signer.activeSignerProvider` - Get currently active signer
  - `Signer.activePubkeyProvider` - Get active user's public key
  - `Signer.signedInPubkeysProvider` - Get all signed-in users
  - `Signer.signerProvider(pubkey)` - Get signer by public key
  - `Signer.activeProfileProvider(source)` - Get active user's profile
  - Advanced authentication management with `signIn()`, `signOut()`, `setAsActivePubkey()`, `removeAsActivePubkey()`
  - Multi-user support with separate active/signed-in states
- **New Models**:
  - `Highlight` (kind 9802) - For highlighting portions of content
  - `CustomData` (kind 30078) - Arbitrary application data storage
  - `BlossomAuthorization` (kind 24242) - File upload authorization
  - `BunkerAuthorization` (kind 24133) - Remote signer authorization  
  - `Comment` (kind 1111) - Structured comment events
  - `GenericRepost` (kind 16) - Generic event reposts
  - `Asset` (kind 30064) - Software asset metadata
  - `VerifyReputationDvm` (kind 65002) - DVM reputation verification
- **Event Verification System**:
  - `verifierProvider` - Configurable event signature verification
  - `DartVerifier` - Default BIP-340 signature verification implementation
  - Custom verifier support with override capability
  - Configurable verification (can be disabled for performance)
- **Documentation**:
  - `CONTEXT.md` - Comprehensive development guide for model creation
  - `ARCHITECTURE.md` - System architecture documentation

### Changed
- Enhanced relationship system with `HasMany<E>` and `BelongsTo<E>`
- Optimized model registration system
- Improved error handling and state management
- Better memory management with configurable limits
- Enhanced deduplication and sorting
- Complete thread support for Notes with `root`, `replyTo`, `replies`, `allReplies`
- Enhanced Profile relationships with `notes` and `contactList`
- Automatic relationship resolution with the `and` parameter
- Lazy loading of relationships for better performance
- Improved error messages and debugging information
- Better TypeScript-like type safety in Dart
- Enhanced documentation with usage examples

### Removed
- `requestNotifierProvider` in favor of `query<E>()` and `queryKinds()`
- `merge_request_filter.dart` and `request_filter.dart` files

### Fixed
- Issue with model state management when not mounted
- NIP-04 and NIP-44 encryption/decryption handling
- Handling of replaceable event IDs
- Race conditions in relationship loading
- Error handling in storage operations

## [0.1.2] - 2025-06-10

### Changed
- Bug fixes and stability improvements
- Enhanced model serialization
- Improved error handling

## [0.1.1] - 2025-05-06

### Added
- Minor feature additions
- Documentation improvements

### Changed
- Performance optimizations

## [0.1.0] - 2025-04-22

### Added
- Basic Nostr protocol implementation
- Core model classes (Note, Profile, Reaction, Zap, etc.)
- Local storage with Riverpod integration
- Request/response system for Nostr events
- Basic relationship system between models
- NIP-01, NIP-02, NIP-04, NIP-05 support
- Simple query interface
- Dummy storage implementation for testing
- Core Models:
  - `Profile` (kind 0) - User metadata
  - `Note` (kind 1) - Text notes/posts  
  - `ContactList` (kind 3) - Following lists
  - `DirectMessage` (kind 4) - Encrypted DMs
  - `Reaction` (kind 7) - Likes/reactions
  - `Zap` (kind 9735) - Lightning payments
  - `Article` (kind 30023) - Long-form content
  - `Community` (kind 34550) - Community definitions
  - `App` (kind 32267) - Application metadata
  - `Release` (kind 30063) - Software releases
  - `FileMetadata` (kind 1063) - File information
- Foundation Features:
  - Riverpod-based reactive state management
  - Local-first architecture with remote sync
  - Event signing and verification
  - Basic encryption support (NIP-04)
  - Extensible model system
  - Request filtering and querying
  - Storage abstraction layer