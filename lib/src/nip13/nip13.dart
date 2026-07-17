import '../core/event.dart';
import '../core/model.dart';
import '../utils/utils.dart';

/// Executes NIP-13 mining for a prepared event.
///
/// Implementations must mutate [event] only after mining succeeds. This seam
/// lets applications move CPU-bound mining to a worker isolate while models
/// retains signing-order and proof-validation ownership.
abstract interface class ProofOfWorkExecutor {
  Future<ProofOfWorkResult> mine<E extends Model<dynamic>>(
    PartialEvent<E> event, {
    required String pubkey,
    required ProofOfWorkOptions options,
  });
}

/// Options for bounded NIP-13 proof-of-work mining.
final class ProofOfWorkOptions {
  ProofOfWorkOptions({
    required this.difficulty,
    this.timeout = const Duration(seconds: 30),
    this.maxAttempts = 1 << 24,
    this.batchSize = 2048,
    this.startNonce = 0,
    this.executor,
  }) {
    RangeError.checkValueInInterval(difficulty, 0, 256, 'difficulty');
    RangeError.checkValueInInterval(
      startNonce,
      0,
      0x7fffffffffffffff,
      'startNonce',
    );
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(timeout, 'timeout', 'Must be positive');
    }
    if (maxAttempts <= 0) {
      throw ArgumentError.value(maxAttempts, 'maxAttempts', 'Must be positive');
    }
    if (batchSize <= 0) {
      throw ArgumentError.value(batchSize, 'batchSize', 'Must be positive');
    }
  }

  /// Desired number of leading zero bits in the event ID.
  final int difficulty;

  /// Maximum wall-clock time spent mining.
  final Duration timeout;

  /// Maximum number of event IDs to try.
  final int maxAttempts;

  /// Number of attempts between event-loop yields.
  final int batchSize;

  /// First nonce value to try.
  final int startNonce;

  /// Optional execution adapter for moving mining off the caller's isolate.
  final ProofOfWorkExecutor? executor;
}

/// Details of a successfully mined NIP-13 event.
final class ProofOfWorkResult {
  const ProofOfWorkResult({
    required this.id,
    required this.nonce,
    required this.difficulty,
    required this.attempts,
    required this.elapsed,
  });

  final String id;
  final int nonce;
  final int difficulty;
  final int attempts;
  final Duration elapsed;
}

/// Thrown when proof-of-work cannot be found within its configured bounds.
final class ProofOfWorkLimitExceeded implements Exception {
  const ProofOfWorkLimitExceeded({
    required this.targetDifficulty,
    required this.attempts,
    required this.elapsed,
  });

  final int targetDifficulty;
  final int attempts;
  final Duration elapsed;

  @override
  String toString() {
    return 'ProofOfWorkLimitExceeded('
        'targetDifficulty: $targetDifficulty, '
        'attempts: $attempts, '
        'elapsed: $elapsed'
        ')';
  }
}

/// Thrown when a signer returns an event that no longer has the mined proof.
final class ProofOfWorkInvalidated implements Exception {
  const ProofOfWorkInvalidated({
    required this.expectedId,
    required this.actualId,
  });

  final String expectedId;
  final String actualId;

  @override
  String toString() {
    return 'ProofOfWorkInvalidated('
        'expectedId: $expectedId, '
        'actualId: $actualId'
        ')';
  }
}

/// Thrown when an external proof-of-work executor is cancelled.
final class ProofOfWorkCancelled implements Exception {
  const ProofOfWorkCancelled();

  @override
  String toString() => 'ProofOfWorkCancelled()';
}

/// NIP-13 proof-of-work helpers and miner.
abstract final class Nip13 {
  static final RegExp _eventIdPattern = RegExp(r'^[0-9a-fA-F]{64}$');

  /// Counts leading zero bits in a 32-byte hexadecimal NIP-01 event ID.
  static int difficultyForId(String id) {
    if (!_eventIdPattern.hasMatch(id)) {
      throw FormatException(
        'NIP-13 difficulty requires a 64-character hexadecimal event ID',
        id,
      );
    }

    var difficulty = 0;
    for (final codeUnit in id.codeUnits) {
      final nibble = int.parse(String.fromCharCode(codeUnit), radix: 16);
      if (nibble == 0) {
        difficulty += 4;
        continue;
      }
      difficulty += 4 - nibble.bitLength;
      break;
    }
    return difficulty;
  }

  /// Returns the target committed by the first `nonce` tag, if valid.
  static int? committedDifficulty(Iterable<List<String>> tags) {
    for (final tag in tags) {
      if (tag.isEmpty || tag.first != 'nonce') continue;
      if (tag.length < 3) return null;
      final target = int.tryParse(tag[2]);
      if (target == null || target < 0 || target > 256) return null;
      return target;
    }
    return null;
  }

  /// Whether an ID and its tags satisfy the requested NIP-13 difficulty.
  ///
  /// The caller must first perform normal NIP-01 event ID and signature
  /// validation. This method validates only the proof and target commitment.
  static bool isValidProof({
    required String id,
    required Iterable<List<String>> tags,
    int minimumDifficulty = 0,
    bool requireCommitment = true,
  }) {
    RangeError.checkValueInInterval(
      minimumDifficulty,
      0,
      256,
      'minimumDifficulty',
    );

    late final int actualDifficulty;
    try {
      actualDifficulty = difficultyForId(id);
    } on FormatException {
      // Relay/database data is untrusted. Invalid event IDs simply do not
      // satisfy proof of work; callers must not crash while inspecting them.
      return false;
    }
    if (actualDifficulty < minimumDifficulty) return false;

    final committed = committedDifficulty(tags);
    if (committed == null) return !requireCommitment;

    return committed >= minimumDifficulty && actualDifficulty >= committed;
  }

  /// Whether an immutable event satisfies the requested NIP-13 difficulty.
  static bool isValid<E extends Model<dynamic>>(
    ImmutableEvent<E> event, {
    int minimumDifficulty = 0,
    bool requireCommitment = true,
  }) {
    return isValidProof(
      id: event.id,
      tags: event.tags,
      minimumDifficulty: minimumDifficulty,
      requireCommitment: requireCommitment,
    );
  }

  /// Mines [event] in place using its final prepared fields.
  ///
  /// Existing `nonce` tags are replaced. If either work limit is reached, the
  /// original tags are restored before [ProofOfWorkLimitExceeded] is thrown.
  static Future<ProofOfWorkResult> mine<E extends Model<dynamic>>(
    PartialEvent<E> event, {
    required String pubkey,
    required ProofOfWorkOptions options,
  }) async {
    final originalTags = [for (final tag in event.tags) List<String>.of(tag)];
    final stopwatch = Stopwatch()..start();
    var attempts = 0;

    try {
      event.removeTag('nonce');

      for (var nonce = options.startNonce; ; nonce++) {
        event.setTag('nonce', [
          nonce.toString(),
          options.difficulty.toString(),
        ]);
        attempts++;

        final id = Utils.getEventId(event, pubkey);
        final difficulty = difficultyForId(id);
        if (difficulty >= options.difficulty) {
          stopwatch.stop();
          return ProofOfWorkResult(
            id: id,
            nonce: nonce,
            difficulty: difficulty,
            attempts: attempts,
            elapsed: stopwatch.elapsed,
          );
        }

        if (attempts >= options.maxAttempts ||
            stopwatch.elapsed >= options.timeout) {
          throw ProofOfWorkLimitExceeded(
            targetDifficulty: options.difficulty,
            attempts: attempts,
            elapsed: stopwatch.elapsed,
          );
        }

        if (attempts % options.batchSize == 0) {
          await Future<void>.delayed(Duration.zero);
        }
      }
    } catch (_) {
      stopwatch.stop();
      event.tags = originalTags;
      rethrow;
    }
  }
}
