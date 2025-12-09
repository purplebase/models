part of models;

/// Global HTTP client provider for dependency injection
/// Can be overridden in tests
final httpClientProvider = Provider<http.Client>((ref) {
  return http.Client();
});


