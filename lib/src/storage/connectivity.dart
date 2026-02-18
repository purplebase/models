import 'package:riverpod/riverpod.dart';

/// Connectivity state — online or offline.
enum ConnectivityStatus { online, offline }

/// No-op notifier that always reports online.
/// Apps override this provider with their own connectivity detection.
class ConnectivityNotifier extends StateNotifier<ConnectivityStatus> {
  ConnectivityNotifier() : super(ConnectivityStatus.online);

  void goOnline() => state = ConnectivityStatus.online;
  void goOffline() => state = ConnectivityStatus.offline;
}

final connectivityProvider =
    StateNotifierProvider<ConnectivityNotifier, ConnectivityStatus>(
  (ref) => ConnectivityNotifier(),
);
