// Re-export from new location for backwards compatibility
// TODO: Update imports in existing tests to use 'helpers/helpers.dart' directly
export 'helpers/helpers.dart';

// Legacy pubkey constants for backwards compatibility
// New tests should use Pubkeys.niel, Pubkeys.franzap, etc.
const nielPubkey =
    'a9434ee165ed01b286becfc2771ef1705d3537d051b387288898cc00d5c885be';
const verbirichaPubkey =
    '7fa56f5d6962ab1e3cd424e758c3002b8665f7b0d8dcee9fe9e288d7751ac194';
const franzapPubkey =
    '726a1e261cc6474674e8285e3951b3bb139be9a773d1acf49dc868db861a1c11';
