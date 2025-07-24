import 'dart:io';
import 'package:args/args.dart';
import 'package:riverpod/riverpod.dart';
import 'package:models/models.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'port',
      abbr: 'p',
      defaultsTo: '8080',
      help: 'Port to listen on',
    )
    ..addOption(
      'host',
      abbr: 'h',
      defaultsTo: '0.0.0.0',
      help: 'Host to bind to',
    )
    ..addFlag('help', negatable: false, help: 'Show usage information');

  try {
    final results = parser.parse(arguments);

    if (results['help'] as bool) {
      print('dart-relay - A simple, in-memory Nostr relay written in Dart\n');
      print('Usage: dart_relay [options]\n');
      print(parser.usage);
      return;
    }

    final port = int.parse(results['port'] as String);
    final host = results['host'] as String;

    final container = ProviderContainer();

    final relay = NostrRelay(
      port: port,
      host: host,
      ref: container.read(refProvider),
    );

    // Handle shutdown gracefully
    ProcessSignal.sigint.watch().listen((signal) async {
      print('\nShutting down relay...');
      await relay.stop();
      exit(0);
    });

    // Start the relay
    await relay.start();

    // Keep the process alive
    await ProcessSignal.sigint.watch().first;
    container.dispose();
  } catch (e) {
    print('Error: $e');
    print('\nUsage: dart_relay [options]');
    print(parser.usage);
    exit(1);
  }
}

final refProvider = Provider((ref) => ref);
