import 'package:flutter/foundation.dart';
import 'package:neoauth/neoauth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// One [NeoAuthClient] per instance, created on first use and kept for the
/// app's lifetime, so switching back to an instance finds its session as it
/// was. Each client stores its tokens under the instance's own
/// [ConsoleInstance.storageKey].
class NeoAuthClients {
  NeoAuthClients(this._create);

  /// Clients for the console: [deviceName] is what the user's session list
  /// shows on every instance.
  factory NeoAuthClients.console({required String deviceName}) => NeoAuthClients(
    (i) => NeoAuthClient(
      NeoAuthConfig(issuer: i.issuer, clientId: i.clientId, deviceName: deviceName, storageKey: i.storageKey),
    ),
  );

  final NeoAuthClient Function(ConsoleInstance instance) _create;
  final _clients = <String, NeoAuthClient>{};
  final _restores = <String, Future<void>>{};

  NeoAuthClient clientFor(ConsoleInstance instance) => _clients.putIfAbsent(instance.id, () => _create(instance));

  /// Loads the instance's stored session once. An unreadable keychain entry
  /// just means signing in again there.
  Future<void> restore(ConsoleInstance instance) => _restores.putIfAbsent(instance.id, () async {
    try {
      await clientFor(instance).restore();
    } catch (e) {
      debugPrint('neoauth_console: could not restore the ${instance.label} session: $e');
    }
  });
}

/// Remembers the last chosen instance on this device.
abstract interface class InstanceSelectionStore {
  Future<String?> load();
  Future<void> save(String instanceId);
}

class SharedPreferencesInstanceStore implements InstanceSelectionStore {
  const SharedPreferencesInstanceStore();

  static const _key = 'console.instance';

  @override
  Future<String?> load() => SharedPreferencesAsync().getString(_key);

  @override
  Future<void> save(String instanceId) => SharedPreferencesAsync().setString(_key, instanceId);
}
