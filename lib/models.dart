library models;

import 'dart:io';
import 'dart:async';
import 'dart:math';

import 'package:nip44/nip44.dart' as nip44;
import 'package:riverpod/riverpod.dart';
import 'package:meta/meta.dart';
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:bip340/bip340.dart' as bip340;
import 'package:bech32/bech32.dart';
import 'package:convert/convert.dart';
import 'package:pointycastle/export.dart' as pc;

// Relay classes are available as parts of this library

part 'src/utils/encoding.dart';
part 'src/core/model.dart';
part 'src/core/event.dart';
part 'src/core/internal_models.dart';
part 'src/core/relationship.dart';
part 'src/core/signer.dart';
part 'src/core/verifier.dart';

part 'src/models/app.dart';
part 'src/models/article.dart';
part 'src/models/blossom_authorization.dart';
part 'src/models/bunker_authorization.dart';
part 'src/models/chat_message.dart';
part 'src/models/community.dart';
part 'src/models/contact_list.dart';
part 'src/models/direct_message.dart';
part 'src/models/file_metadata.dart';
part 'src/models/highlight.dart';
part 'src/models/lists.dart';
part 'src/models/note.dart';
part 'src/models/profile.dart';
part 'src/models/reaction.dart';
part 'src/models/release.dart';
part 'src/models/comment.dart';
part 'src/models/asset.dart';
part 'src/models/targeted_publication.dart';
part 'src/models/verify_reputation_dvm.dart';
part 'src/models/zap.dart';
part 'src/models/custom_data.dart';
part 'src/models/repost.dart';
part 'src/models/generic_repost.dart';
part 'src/models/event_deletion.dart';
part 'src/models/picture.dart';
part 'src/models/video.dart';
part 'src/models/reporting.dart';
part 'src/models/calendar_events.dart';
part 'src/models/voice_message.dart';

part 'src/models/nwc.dart';
part 'src/nwc/nwc_connection.dart';
part 'src/nwc/nwc_commands.dart';

part 'src/request/request_notifier.dart';
part 'src/request/request.dart';

part 'src/storage/initialization.dart';
part 'src/storage/storage.dart';
part 'src/storage/dummy_storage.dart';

part 'src/utils/extensions.dart';
part 'src/utils/utils.dart';

// Removed: models.g.dart - mixins are now inline in individual model files

// Relay parts
part 'src/relay/nostr_relay.dart';
part 'src/relay/models/relay_info.dart';
part 'src/relay/handlers/message_handler.dart';
part 'src/relay/storage/memory_storage.dart';
