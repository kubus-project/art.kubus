import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_gating_service.dart';

class CredentialCleanupResult {
  const CredentialCleanupResult(
      {required this.complete, required this.restartBlocked});
  final bool complete;
  final bool restartBlocked;
}

/// Authentication persistence only. Native credentials use the OS-backed
/// plugin; browser sessions are memory-only. No preference contains a new token.
/// The non-secret logout marker prevents restoring a credential whose deletion
/// failed. All secret IO is serialized, including late platform completions.
class AuthCredentialStore {
  AuthCredentialStore({
    bool? web,
    FlutterSecureStorage? secureStorage,
    Future<SharedPreferences> Function()? preferences,
  })  : _web = web ?? kIsWeb,
        _secure = secureStorage ?? const FlutterSecureStorage(),
        _preferences = preferences ?? SharedPreferences.getInstance;

  static const revokedKey = 'auth_credentials_revoked_v1';
  final bool _web;
  final FlutterSecureStorage _secure;
  final Future<SharedPreferences> Function() _preferences;
  Future<void>? _tail;
  int _generation = 0;
  bool _revoked = false;
  final Map<String, String> _memory = {};
  // Separate from login authority: a closure status receipt must survive logout.
  // Browser capabilities remain memory-only; users can explicitly save a copy.
  String? _closureReceiptMemory;
  static const closureReceiptKey = 'account_closure_status_receipt_v1';

  Future<void> saveClosureReceipt(String receipt) => _run((_) async {
        if (_web) {
          _closureReceiptMemory = receipt;
        } else {
          await _secure.write(key: closureReceiptKey, value: receipt);
          if (await _secure.read(key: closureReceiptKey) != receipt) {
            throw StateError('Closure receipt storage unavailable');
          }
        }
      });

  Future<String?> readClosureReceipt() => _run((_) async =>
      _web ? _closureReceiptMemory : _secure.read(key: closureReceiptKey));

  Iterable<String> get _legacyKeys => {
        ...AuthGatingService.accessTokenKeys,
        ...AuthGatingService.refreshTokenKeys,
      };

  Future<T> _run<T>(Future<T> Function(int generation) operation) {
    final generation = _generation;
    final previous = _tail;
    final result = previous == null
        ? Future<T>.sync(() => operation(generation))
        : previous.then((_) => operation(generation));
    // No timeout inside this chain: a timed-out platform write is not cancelled
    // and must not race a later delete or another account's write.
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<bool> _removePreferences(SharedPreferences prefs) async {
    var complete = true;
    for (final key in _legacyKeys) {
      try {
        if (!await prefs.remove(key)) complete = false;
      } catch (_) {
        complete = false;
      }
    }
    return complete;
  }

  Future<bool> _removeSecure() async {
    var complete = true;
    for (final key in _legacyKeys) {
      try {
        await _secure.delete(key: key);
      } catch (_) {
        complete = false;
      }
    }
    return complete;
  }

  Future<bool> save(String key, String value, {bool Function()? isCurrent}) =>
      _save({key: value}, isCurrent: isCurrent);

  Future<bool> saveSession(String access, String? refresh) {
    _generation += 1;
    return _save({
      'jwt_token': access,
      if (refresh != null && refresh.isNotEmpty) 'refresh_token': refresh
    });
  }

  Future<bool> _save(Map<String, String> values,
          {bool Function()? isCurrent}) =>
      _run((generation) async {
        if (generation != _generation || (isCurrent != null && !isCurrent())) {
          return false;
        }
        final prefs = await _preferences();
        if (generation != _generation) return false;
        // An interrupted save cannot make a partially migrated session active.
        if (!await prefs.setBool(revokedKey, true)) {
          throw StateError('Credential storage unavailable');
        }
        if (!_web) {
          // A new access session cannot inherit a previous account's refresh
          // secret. A response may subsequently supply its own refresh token.
          if (values.containsKey('jwt_token')) {
            await _secure.delete(key: 'refresh_token');
          }
          for (final entry in values.entries) {
            await _secure.write(key: entry.key, value: entry.value);
          }
        }
        final removed = await _removePreferences(prefs);
        final webRemoved = !_web || await _removeSecure();
        if (!removed || !webRemoved) {
          throw StateError('Credential cleanup incomplete');
        }
        if (generation != _generation || (isCurrent != null && !isCurrent())) {
          return false;
        }
        if (!await prefs.setBool(revokedKey, false)) {
          throw StateError('Credential storage unavailable');
        }
        if (generation != _generation) return false;
        _revoked = false;
        if (_web) {
          if (values.containsKey('jwt_token')) _memory.remove('refresh_token');
          _memory.addAll(values);
        }
        return true;
      });

  Future<String?> readAccess() => _run((generation) async {
        if (generation != _generation || _revoked) return null;
        final prefs = await _preferences();
        if (generation != _generation) return null;
        if (prefs.getBool(revokedKey) == true) {
          await _removePreferences(prefs);
          await _removeSecure();
          return null;
        }
        if (_web) {
          // Existing persistent browser credentials are intentionally not
          // imported. A reload requires explicit authentication.
          await _removePreferences(prefs);
          await _removeSecure();
          return generation == _generation ? _memory['jwt_token'] : null;
        }
        // Secure-store read failures never fall back to preference authority.
        String? token;
        try {
          token = await _secure.read(key: 'jwt_token');
        } catch (_) {
          // Do not retain the old weaker duplicate as a recovery authority
          // when secure storage cannot be verified.
          await prefs.setBool(revokedKey, true);
          await _removePreferences(prefs);
          rethrow;
        }
        if (generation != _generation) return null;
        if (token == null || token.isEmpty) {
          final legacy = AuthGatingService.readStoredAccessToken(prefs);
          if (legacy != null && legacy.isNotEmpty) {
            if (!await prefs.setBool(revokedKey, true)) {
              throw StateError('Credential migration unavailable');
            }
            await _secure.write(key: 'jwt_token', value: legacy);
            final refresh = AuthGatingService.readStoredRefreshToken(prefs);
            if (refresh != null && refresh.isNotEmpty) {
              await _secure.write(key: 'refresh_token', value: refresh);
            }
            token = legacy;
          }
        }
        if (!await _removePreferences(prefs)) {
          throw StateError('Credential migration cleanup incomplete');
        }
        if (generation != _generation) return null;
        if (!await prefs.setBool(revokedKey, false)) {
          throw StateError('Credential storage unavailable');
        }
        return generation == _generation ? token : null;
      });

  Future<CredentialCleanupResult> clear() {
    _generation += 1;
    _revoked = true;
    _memory.clear();
    // Persist intent independently of potentially hung secret IO. Reassert it
    // in the serialized cleanup too, after any earlier platform completion.
    final marker = () async {
      try {
        return await (await _preferences()).setBool(revokedKey, true);
      } catch (_) {
        return false;
      }
    }();
    return _run((_) async {
      var restartBlocked = await marker;
      var preferencesRemoved = false;
      try {
        final prefs = await _preferences();
        restartBlocked =
            await prefs.setBool(revokedKey, true) || restartBlocked;
        preferencesRemoved = await _removePreferences(prefs);
      } catch (_) {
        // Independent secure deletion is still required after preference errors.
      }
      final secureRemoved = await _removeSecure();
      return CredentialCleanupResult(
        complete: preferencesRemoved && secureRemoved,
        restartBlocked: restartBlocked,
      );
    });
  }
}
