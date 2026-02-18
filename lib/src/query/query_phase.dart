/// Explicit state machine phases for RequestNotifier.
///
/// Replaces boolean guards (_isRefreshing, _isProcessingRelationships, _eoseReceived)
/// with named states and transitions.
enum QueryPhase {
  /// Initial state. No data yet.
  initializing,

  /// Local data loaded, remote query in flight.
  awaitingRemote,

  /// All data loaded. Terminal for non-streaming queries.
  live,

  /// Live + receiving streaming updates.
  streaming,

  /// Error state (retryable).
  error,

  /// Disposed.
  disposed,
}

/// Validates that a phase transition is legal.
bool isValidTransition(QueryPhase from, QueryPhase to) {
  // disposed is terminal - no transitions from it
  if (from == QueryPhase.disposed) return false;

  // Any phase can transition to error or disposed
  if (to == QueryPhase.error || to == QueryPhase.disposed) return true;

  return switch ((from, to)) {
    // initializing → awaitingRemote (remote source)
    (QueryPhase.initializing, QueryPhase.awaitingRemote) => true,
    // initializing → live (local source, or remote with immediate data)
    (QueryPhase.initializing, QueryPhase.live) => true,
    // awaitingRemote → live (EOSE/timeout)
    (QueryPhase.awaitingRemote, QueryPhase.live) => true,
    // live → streaming (if stream=true)
    (QueryPhase.live, QueryPhase.streaming) => true,
    // error → awaitingRemote (retry)
    (QueryPhase.error, QueryPhase.awaitingRemote) => true,
    // error → live (retry succeeded)
    (QueryPhase.error, QueryPhase.live) => true,
    _ => false,
  };
}
