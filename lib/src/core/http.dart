import 'package:http/http.dart' as http;
import 'package:riverpod/riverpod.dart';

/// Global HTTP client provider for dependency injection.
final httpClientProvider = Provider<http.Client>((ref) {
  return http.Client();
});
