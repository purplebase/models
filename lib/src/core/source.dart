import 'package:equatable/equatable.dart';

/// Base class for query source configuration.
abstract class Source extends Equatable {
  const Source();

  @override
  List<Object?> get props => [];
}

/// Query from local storage only.
final class LocalSource extends Source {
  const LocalSource();
}
