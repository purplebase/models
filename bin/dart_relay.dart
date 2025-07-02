import 'dart:io';
import 'package:args/args.dart';
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

    // Create and configure the relay
    final relayInfo = RelayInfoData(
      name: 'dart-relay',
      description: 'A simple, in-memory Nostr relay written in Dart',
      supportedNips: [1, 2, 9, 10, 11, 42, 50], // Basic NIPs we support
      software: 'dart-relay',
      version: '1.0.0',
      contact: 'admin@example.com',
    );

    final relay = NostrRelay(port: port, host: host, relayInfo: relayInfo);

    // Handle shutdown gracefully
    ProcessSignal.sigint.watch().listen((signal) async {
      print('\nShutting down relay...');
      await relay.stop();
      exit(0);
    });

    // Start the relay
    await relay.start();

    // Print some helpful information
    print('\n🚀 Relay is running!');
    print('📊 Supported NIPs: ${relayInfo.supportedNips.join(', ')}');
    print('🔍 Features:');
    print('   • Basic protocol (NIP-01)');
    print('   • Contact lists (NIP-02)');
    print('   • Event deletion (NIP-09)');
    print('   • Text note references (NIP-10)');
    print('   • Relay information (NIP-11)');
    print('   • Authentication (NIP-42)');
    print('   • Search capability (NIP-50)');
    print('\n📝 Connect your Nostr client to: ws://$host:$port');
    print('🌐 View relay info at: http://$host:$port');
    print('\n💡 Press Ctrl+C to stop');

    // Keep the process alive
    await ProcessSignal.sigint.watch().first;
  } catch (e) {
    print('Error: $e');
    print('\nUsage: dart_relay [options]');
    print(parser.usage);
    exit(1);
  }
}
