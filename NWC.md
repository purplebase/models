# Nostr Wallet Connect (NWC) Integration

This library provides complete NWC (Nostr Wallet Connect) support following NIP-47 specification for Lightning wallet operations through Nostr relays.

## Overview

NWC enables Lightning wallet operations (payments, invoices, balance checks) through encrypted Nostr events. The wallet service listens on a relay and responds to encrypted requests from authorized clients.

## Quick Start

### 1. Setup Connection

```dart
import 'package:models/models.dart';
import 'package:riverpod/riverpod.dart';

// Initialize storage
final container = ProviderContainer();
final config = StorageConfiguration(keepSignatures: false);
await container.read(initializationProvider(config).future);

// Parse NWC connection URI (from wallet like GetAlby)
final nwcUri = 'nostr+walletconnect://pubkey?relay=wss://...&secret=...';
final connection = NwcConnection.fromUri(nwcUri);

// Setup signer and storage
final signer = yourSignerInstance;
final storage = container.read(storageNotifierProvider.notifier);
```

### 2. Make Payments

```dart
// Create payment request
final payCommand = PayInvoiceCommand(
  invoice: 'lnbc1000n1...', // BOLT11 invoice
  amount: 1000, // Optional: override amount in sats
);

// Create and sign request
final request = payCommand.toRequest(
  walletPubkey: connection.walletPubkey,
  expiration: DateTime.now().add(Duration(minutes: 5)),
);

final connectionSigner = Bip340PrivateKeySigner(
  connection.secret,
  signer.ref,
);
await connectionSigner.signIn(setAsActive: false);

final signedRequest = await request.signWith(connectionSigner);

// Publish request
await storage.publish(
  {signedRequest},
  source: RemoteSource(group: 'nwc'),
);

// Listen for response
final responses = storage.watch(
  query<NwcResponse>(
    authors: {connection.walletPubkey},
    #kinds: {23195}, // NWC Response kind
    #tags: {
      '#e': {signedRequest.event.id},
      '#p': {connectionSigner.pubkey},
    },
  ).toRequest(),
);

// Handle response
await for (final state in responses) {
  if (state is StorageData<NwcResponse> && state.models.isNotEmpty) {
    final response = state.models.first;
    
    if (await response.hasError(connectionSigner)) {
      final error = await response.getError(connectionSigner);
      print('Payment failed: ${error?.message}');
    } else {
      final result = payCommand.parseResponse(
        await response.getResult(connectionSigner) ?? {},
      );
      print('Payment successful! Preimage: ${result.preimage}');
    }
    break;
  }
}

await connectionSigner.signOut();
```

### 3. Check Balance

```dart
final balanceCommand = GetBalanceCommand();
final request = balanceCommand.toRequest(
  walletPubkey: connection.walletPubkey,
);

// Follow same pattern as payment...
// Result: balanceResult.balance (in sats)
```

### 4. Create Invoices

```dart
final invoiceCommand = MakeInvoiceCommand(
  amount: 1000, // sats
  description: 'Payment for services',
  expiry: 3600, // seconds
);

// Follow same pattern...
// Result: invoiceResult.invoice (BOLT11 string)
```

## Connection Management

### Secure Storage

Use `NwcConnectionManager` for secure storage of connection data:

```dart
final manager = ref.read(nwcConnectionManagerProvider);

// Store connection
await manager.storeConnection('my-wallet', connection);

// Set as active
await manager.setActiveConnection('my-wallet');

// Retrieve active connection
final activeConnection = await manager.getActiveConnection();

// List all connections
final allConnections = await manager.getAllConnections();
```

### Connection URI Format

```
nostr+walletconnect://WALLET_PUBKEY?relay=RELAY_URL&secret=CLIENT_SECRET&lud16=LIGHTNING_ADDRESS
```

Example:
```
nostr+walletconnect://f01087d574ae2e9d1040e63171b3a9f5731b470bba08712a102f0c48e972e8bc?relay=wss://relay.getalby.com/v1&secret=2b4d51c2f0e21bc7ea599b29fe87025f09ad93925de2e0e5b96100d4bf59697a&lud16=user@getalby.com
```

## Available Commands

### Payment Commands

| Command | Description | Parameters |
|---------|-------------|------------|
| `PayInvoiceCommand` | Pay Lightning invoice | `invoice` (BOLT11), optional `amount` |
| `GetBalanceCommand` | Get wallet balance | None |
| `MakeInvoiceCommand` | Create invoice | `amount`, optional `description`, `expiry` |
| `GetInfoCommand` | Get wallet capabilities | None |
| `LookupInvoiceCommand` | Check invoice status | `paymentHash` or `invoice` |

### Response Types

```dart
// Payment result
class PayInvoiceResult {
  final String preimage;
  final int? feesPaid;
}

// Balance result  
class GetBalanceResult {
  final int balance; // sats
}

// Invoice result
class MakeInvoiceResult {
  final String? invoice; // BOLT11
  final String paymentHash;
  final int amount;
  // ... other fields
}
```

## Error Handling

```dart
// Check for errors in response
if (await response.hasError(signer)) {
  final error = await response.getError(signer);
  
  switch (error?.code) {
    case 'INSUFFICIENT_BALANCE':
      print('Not enough funds');
      break;
    case 'INVOICE_EXPIRED':
      print('Invoice has expired');
      break;
    case 'INVALID_INVOICE':
      print('Invalid BOLT11 invoice');
      break;
    default:
      print('Error: ${error?.message}');
  }
}
```

## Payment Notifications

Listen for real-time payment notifications:

```dart
// Watch for payment notifications
final notifications = storage.watch(
  query<NwcNotification>(
    authors: {connection.walletPubkey},
    #kinds: {23196}, // NWC Notification kind
    #tags: {'#p': {connectionSigner.pubkey}},
  ).toRequest(),
);

await for (final state in notifications) {
  if (state is StorageData<NwcNotification> && state.models.isNotEmpty) {
    final notification = state.models.first;
    
    if (await notification.isPaymentReceived(signer)) {
      print('Payment received!');
    } else if (await notification.isPaymentSent(signer)) {
      print('Payment sent!');
    }
  }
}
```

## Integration Examples

### Simple Payment Function

```dart
Future<bool> payInvoice(String invoice, NwcConnection connection) async {
  try {
    final command = PayInvoiceCommand(invoice: invoice);
    final request = command.toRequest(walletPubkey: connection.walletPubkey);
    
    final signer = Bip340PrivateKeySigner(connection.secret, ref);
    await signer.signIn(setAsActive: false);
    
    final signedRequest = await request.signWith(signer);
    await storage.publish({signedRequest}, source: RemoteSource(group: 'nwc'));
    
    // Wait for response with timeout
    final response = await waitForNwcResponse(signedRequest.event.id, signer);
    
    if (await response.hasError(signer)) {
      return false;
    }
    
    final result = command.parseResponse(
      await response.getResult(signer) ?? {},
    );
    
    print('Payment successful: ${result.preimage}');
    return true;
    
  } catch (e) {
    print('Payment failed: $e');
    return false;
  }
}
```

### Wallet Balance Widget

```dart
class WalletBalanceWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<int?>(
      future: getWalletBalance(ref),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Text('${snapshot.data} sats');
        }
        return CircularProgressIndicator();
      },
    );
  }
}

Future<int?> getWalletBalance(WidgetRef ref) async {
  final manager = ref.read(nwcConnectionManagerProvider);
  final connection = await manager.getActiveConnection();
  
  if (connection == null) return null;
  
  final command = GetBalanceCommand();
  // ... implement request/response pattern
  
  return balanceResult.balance;
}
```

## Security Considerations

1. **Connection Secrets**: NWC connection secrets are stored encrypted using NIP-44
2. **Temporary Signers**: Each request uses a temporary signer that's disposed after use  
3. **Request Expiration**: All requests include expiration timestamps
4. **Permission Scoping**: Connections can be limited to specific methods and amounts

## Supported Wallets

- **GetAlby**: Full NWC support with web interface
- **LNDHub**: Basic NWC implementation
- **Custom**: Any wallet implementing NIP-47

## Troubleshooting

### Common Issues

1. **Timeout Errors**: Check relay connectivity and wallet authorization
2. **Invalid Invoice**: Verify BOLT11 format and expiration
3. **Insufficient Balance**: Check wallet balance before payments
4. **Permission Denied**: Verify connection is authorized in wallet settings

### Debug Tips

1. Check wallet dashboard for connection authorization
2. Verify relay URL is accessible
3. Ensure connection secret hasn't expired
4. Test with small amounts first

## Event Kinds Reference

| Kind | Description | Model |
|------|-------------|-------|
| 13194 | Wallet Info | `NwcInfo` |
| 23194 | Request | `NwcRequest` |
| 23195 | Response | `NwcResponse` |
| 23196 | Notification | `NwcNotification` |

---

For more details, see [NIP-47: Wallet Connect](https://github.com/nostr-protocol/nips/blob/master/47.md). 