// ignore_for_file: invalid_runtime_check_with_js_interop_types

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:bs58/bs58.dart' as bs58;
import 'package:flutter/foundation.dart';
import 'package:solana/encoder.dart';
import 'package:web/web.dart' as web;

import 'browser_solana_wallet_service.dart';

BrowserSolanaWalletService createBrowserSolanaWalletService() =>
    _BrowserSolanaWalletServiceWeb();

class _BrowserSolanaWalletServiceWeb implements BrowserSolanaWalletService {
  final Map<String, _BrowserWalletAdapter> _discoveredWallets =
      <String, _BrowserWalletAdapter>{};

  _BrowserWalletAdapter? _activeWallet;

  @override
  Future<List<BrowserSolanaWalletDefinition>>
      discoverCompatibleWallets() async {
    _log('starting injected wallet discovery');

    final discovered = <_BrowserWalletAdapter>[];
    final seen = <String>{};

    void addWallet(_BrowserWalletAdapter adapter) {
      final key = adapter.dedupeKey;
      if (!seen.add(key)) {
        return;
      }
      discovered.add(adapter);
    }

    final phantomInjected = _discoverInjectedPhantom();
    if (phantomInjected != null) {
      addWallet(phantomInjected);
    }

    for (final wallet in await _discoverWalletStandardWallets()) {
      addWallet(wallet);
    }

    discovered.sort((a, b) {
      final byPriority = a.sortPriority.compareTo(b.sortPriority);
      if (byPriority != 0) return byPriority;
      return a.definition.name.toLowerCase().compareTo(
            b.definition.name.toLowerCase(),
          );
    });

    _discoveredWallets
      ..clear()
      ..addEntries(
        discovered.map(
          (wallet) => MapEntry<String, _BrowserWalletAdapter>(
            wallet.definition.id,
            wallet,
          ),
        ),
      );

    _log(
      'discovered ${discovered.length} compatible wallet(s): '
      '${discovered.map((wallet) => wallet.definition.name).join(', ')}',
    );

    return discovered.map((wallet) => wallet.definition).toList(
          growable: false,
        );
  }

  @override
  Future<BrowserSolanaWalletConnectionResult> connect({
    required String walletId,
    required String chainId,
  }) async {
    final wallet = await _resolveWallet(walletId);
    _log(
      'connecting to ${wallet.definition.name} '
      'via ${wallet.definition.source.name} on $chainId',
    );
    final result = await wallet.connect(chainId: chainId);
    _activeWallet = wallet;
    _log(
      'connected browser wallet ${wallet.definition.name} '
      'at ${result.address}',
    );
    return result;
  }

  @override
  Future<void> disconnect() async {
    final wallet = _activeWallet;
    _activeWallet = null;
    if (wallet == null) return;
    try {
      await wallet.disconnect();
      _log('disconnected browser wallet ${wallet.definition.name}');
    } catch (error) {
      _log('disconnect ignored for ${wallet.definition.name}: $error');
    }
  }

  @override
  Future<String> signMessageBase64(String messageBase64) async {
    final wallet = _requireActiveWallet();
    return wallet.signMessageBase64(messageBase64);
  }

  @override
  Future<String> signTransactionBase64({
    required String transactionBase64,
    required String chainId,
  }) async {
    final wallet = _requireActiveWallet();
    return wallet.signTransactionBase64(
      transactionBase64: transactionBase64,
      chainId: chainId,
    );
  }

  @override
  Future<String> signAndSendTransactionBase64({
    required String transactionBase64,
    required String chainId,
  }) async {
    final wallet = _requireActiveWallet();
    return wallet.signAndSendTransactionBase64(
      transactionBase64: transactionBase64,
      chainId: chainId,
    );
  }

  _BrowserWalletAdapter _requireActiveWallet() {
    final wallet = _activeWallet;
    if (wallet == null) {
      throw StateError('No browser wallet is connected.');
    }
    return wallet;
  }

  Future<_BrowserWalletAdapter> _resolveWallet(String walletId) async {
    final existing = _discoveredWallets[walletId];
    if (existing != null) {
      return existing;
    }

    await discoverCompatibleWallets();
    final refreshed = _discoveredWallets[walletId];
    if (refreshed != null) {
      return refreshed;
    }

    throw StateError('Browser wallet "$walletId" is no longer available.');
  }

  _InjectedPhantomWalletAdapter? _discoverInjectedPhantom() {
    final windowObject = JSObject.fromInteropObject(web.window);
    final phantomContainer = _getObjectProperty(windowObject, 'phantom');
    final solanaFromContainer = phantomContainer == null
        ? null
        : _getObjectProperty(phantomContainer, 'solana');
    final windowSolana = _getObjectProperty(windowObject, 'solana');
    final provider = _pickInjectedPhantomProvider(
      solanaFromContainer,
      windowSolana,
    );

    if (provider == null) {
      return null;
    }

    if (!_hasFunction(provider, 'connect') ||
        !_hasFunction(provider, 'signMessage') ||
        !_hasFunction(provider, 'request')) {
      _log('phantom provider detected but required methods are missing');
      return null;
    }

    return _InjectedPhantomWalletAdapter(provider);
  }

  JSObject? _pickInjectedPhantomProvider(JSObject? a, JSObject? b) {
    for (final candidate in <JSObject?>[a, b]) {
      if (candidate == null) continue;
      final isPhantom = _readBool(candidate, 'isPhantom') ||
          _readBool(candidate, 'isPhantomBrowser');
      if (isPhantom) {
        return candidate;
      }
    }
    return null;
  }

  Future<List<_BrowserWalletAdapter>> _discoverWalletStandardWallets() async {
    final registerApi = JSObject();
    final wallets = <JSObject>[];
    final walletKeys = <String>{};

    void registerWallet(JSAny? walletA,
        [JSAny? walletB, JSAny? walletC, JSAny? walletD]) {
      for (final candidate in <JSAny?>[walletA, walletB, walletC, walletD]) {
        if (candidate is! JSObject) continue;
        final name = _readString(candidate, 'name');
        final version = _readString(candidate, 'version');
        if (name == null || version == null || version.isEmpty) continue;
        final key = '$name::$version';
        if (walletKeys.add(key)) {
          wallets.add(candidate);
        }
      }
    }

    registerApi['register'] = registerWallet.toJS;

    final registerListener = ((web.Event event) {
      final eventObject = JSObject.fromInteropObject(event);
      final detail = eventObject.getProperty<JSAny?>('detail'.toJS);
      if (detail is JSFunction) {
        detail.callAsFunction(detail, registerApi);
      }
    }).toJS;

    web.window.addEventListener(
      'wallet-standard:register-wallet',
      registerListener,
    );

    try {
      final appReadyEvent = web.CustomEvent(
        'wallet-standard:app-ready',
        web.CustomEventInit(detail: registerApi),
      );
      web.window.dispatchEvent(appReadyEvent);
      _pumpDeprecatedNavigatorWallets(registerApi);
      await Future<void>.delayed(const Duration(milliseconds: 120));
    } finally {
      web.window.removeEventListener(
        'wallet-standard:register-wallet',
        registerListener,
      );
    }

    return wallets
        .map<_BrowserWalletAdapter?>(
          (wallet) => _WalletStandardBrowserWalletAdapter.tryCreate(wallet),
        )
        .whereType<_BrowserWalletAdapter>()
        .toList(growable: false);
  }

  void _pumpDeprecatedNavigatorWallets(JSObject registerApi) {
    final navigatorObject = JSObject.fromInteropObject(web.window.navigator);
    final walletsValue = navigatorObject.getProperty<JSAny?>('wallets'.toJS);
    if (walletsValue is! JSArray<JSAny?>) {
      return;
    }
    for (final callback in walletsValue.toDart) {
      if (callback is JSFunction) {
        callback.callAsFunction(callback, registerApi);
      }
    }
  }

  void _log(String message) {
    if (!kDebugMode) return;
    debugPrint('BrowserSolanaWalletService: $message');
  }
}

abstract class _BrowserWalletAdapter {
  BrowserSolanaWalletDefinition get definition;
  String get dedupeKey;
  int get sortPriority;

  Future<BrowserSolanaWalletConnectionResult> connect({
    required String chainId,
  });

  Future<void> disconnect();

  Future<String> signMessageBase64(String messageBase64);

  Future<String> signTransactionBase64({
    required String transactionBase64,
    required String chainId,
  });

  Future<String> signAndSendTransactionBase64({
    required String transactionBase64,
    required String chainId,
  });
}

class _InjectedPhantomWalletAdapter implements _BrowserWalletAdapter {
  _InjectedPhantomWalletAdapter(this._provider);

  final JSObject _provider;

  @override
  final BrowserSolanaWalletDefinition definition =
      const BrowserSolanaWalletDefinition(
    id: 'browser-phantom',
    name: 'Phantom',
    source: BrowserSolanaWalletSource.phantomInjected,
    isPhantom: true,
  );

  @override
  String get dedupeKey => 'phantom';

  @override
  int get sortPriority => 0;

  @override
  Future<BrowserSolanaWalletConnectionResult> connect({
    required String chainId,
  }) async {
    await _awaitPromise(_provider.callMethodVarArgs<JSAny?>(
      'connect'.toJS,
      const <JSAny?>[],
    ));
    final address = _readProviderAddress(_provider);
    if (address == null || address.isEmpty) {
      throw StateError('Phantom connected without a Solana public key.');
    }
    return BrowserSolanaWalletConnectionResult(
      address: address,
      walletName: definition.name,
    );
  }

  @override
  Future<void> disconnect() async {
    if (!_hasFunction(_provider, 'disconnect')) return;
    await _awaitPromise(_provider.callMethodVarArgs<JSAny?>(
      'disconnect'.toJS,
      const <JSAny?>[],
    ));
  }

  @override
  Future<String> signMessageBase64(String messageBase64) async {
    final messageBytes = base64Decode(messageBase64);
    final result = await _awaitPromise(
      _provider.callMethodVarArgs<JSAny?>(
        'signMessage'.toJS,
        <JSAny?>[
          messageBytes.toJS,
          'utf8'.toJS,
        ],
      ),
    );
    final signature = _extractBytesProperty(result, 'signature');
    return base64Encode(signature);
  }

  @override
  Future<String> signTransactionBase64({
    required String transactionBase64,
    required String chainId,
  }) async {
    final request = _buildPhantomTransactionRequest(
      method: 'signTransaction',
      transactionBase64: transactionBase64,
    );
    final result = await _awaitPromise(
      _provider.callMethodVarArgs<JSAny?>(
        'request'.toJS,
        <JSAny?>[request],
      ),
    );
    if (result is! JSObject || !_hasFunction(result, 'serialize')) {
      throw StateError('Phantom did not return a serializable transaction.');
    }
    final serialized = result.callMethodVarArgs<JSAny?>(
      'serialize'.toJS,
      const <JSAny?>[],
    );
    return base64Encode(_coerceBytes(serialized));
  }

  @override
  Future<String> signAndSendTransactionBase64({
    required String transactionBase64,
    required String chainId,
  }) async {
    final request = _buildPhantomTransactionRequest(
      method: 'signAndSendTransaction',
      transactionBase64: transactionBase64,
    );
    final result = await _awaitPromise(
      _provider.callMethodVarArgs<JSAny?>(
        'request'.toJS,
        <JSAny?>[request],
      ),
    );
    final signature = _readSignatureString(result);
    if (signature == null || signature.isEmpty) {
      throw StateError('Phantom did not return a transaction signature.');
    }
    return signature;
  }

  JSObject _buildPhantomTransactionRequest({
    required String method,
    required String transactionBase64,
  }) {
    final unsigned = SignedTx.decode(transactionBase64);
    final encodedMessage = bs58.base58.encode(
      Uint8List.fromList(unsigned.compiledMessage.toByteArray().toList()),
    );
    return _createJsObject(<String, JSAny?>{
      'method': method.toJS,
      'params': _createJsObject(<String, JSAny?>{
        'message': encodedMessage.toJS,
      }),
    });
  }
}

class _WalletStandardBrowserWalletAdapter implements _BrowserWalletAdapter {
  _WalletStandardBrowserWalletAdapter._(this._wallet, this.definition);

  final JSObject _wallet;
  JSObject? _connectedAccount;

  @override
  final BrowserSolanaWalletDefinition definition;

  static const String _standardConnect = 'standard:connect';
  static const String _standardDisconnect = 'standard:disconnect';
  static const String _solanaSignMessage = 'solana:signMessage';
  static const String _solanaSignTransaction = 'solana:signTransaction';
  static const String _solanaSignAndSendTransaction =
      'solana:signAndSendTransaction';

  static _WalletStandardBrowserWalletAdapter? tryCreate(JSObject wallet) {
    final name = _readString(wallet, 'name');
    if (name == null || name.isEmpty) {
      return null;
    }

    final features = _getObjectProperty(wallet, 'features');
    if (features == null ||
        !_hasObjectFeature(features, _standardConnect) ||
        !_hasObjectFeature(features, _solanaSignMessage) ||
        !_hasObjectFeature(features, _solanaSignTransaction)) {
      return null;
    }

    final supportsSolana = _supportsSolana(wallet);
    if (!supportsSolana) {
      return null;
    }

    final normalizedName =
        name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return _WalletStandardBrowserWalletAdapter._(
      wallet,
      BrowserSolanaWalletDefinition(
        id: 'wallet-standard-$normalizedName',
        name: name,
        source: BrowserSolanaWalletSource.walletStandard,
        isPhantom: normalizedName == 'phantom',
      ),
    );
  }

  @override
  String get dedupeKey => definition.isPhantom
      ? 'phantom'
      : 'wallet-standard:${definition.name.toLowerCase()}';

  @override
  int get sortPriority {
    final normalized = definition.name.toLowerCase();
    if (normalized == 'phantom') return 1;
    if (normalized == 'solflare') return 2;
    if (normalized == 'backpack') return 3;
    return 50;
  }

  @override
  Future<BrowserSolanaWalletConnectionResult> connect({
    required String chainId,
  }) async {
    final connectFeature = _getFeatureObject(_wallet, _standardConnect);
    final connectResult = await _awaitPromise(
      connectFeature.callMethodVarArgs<JSAny?>(
        'connect'.toJS,
        const <JSAny?>[],
      ),
    );
    final accounts = _extractWalletAccounts(connectResult);
    final connectedAccounts =
        accounts.isEmpty ? _extractWalletAccounts(_wallet) : accounts;
    final account = _pickSolanaAccount(connectedAccounts, chainId: chainId);
    if (account == null) {
      throw StateError(
        '${definition.name} did not expose a compatible Solana account.',
      );
    }

    _connectedAccount = account;
    final address = _readString(account, 'address');
    if (address == null || address.isEmpty) {
      throw StateError('${definition.name} returned an empty wallet address.');
    }

    return BrowserSolanaWalletConnectionResult(
      address: address,
      walletName: definition.name,
    );
  }

  @override
  Future<void> disconnect() async {
    final features = _getObjectProperty(_wallet, 'features');
    if (features == null || !_hasObjectFeature(features, _standardDisconnect)) {
      _connectedAccount = null;
      return;
    }

    final disconnectFeature = _getFeatureObject(_wallet, _standardDisconnect);
    await _awaitPromise(
      disconnectFeature.callMethodVarArgs<JSAny?>(
        'disconnect'.toJS,
        const <JSAny?>[],
      ),
    );
    _connectedAccount = null;
  }

  @override
  Future<String> signMessageBase64(String messageBase64) async {
    final account = _requireConnectedAccount();
    final feature = _getFeatureObject(_wallet, _solanaSignMessage);
    final messageBytes = base64Decode(messageBase64);
    final result = await _awaitPromise(
      feature.callMethodVarArgs<JSAny?>(
        'signMessage'.toJS,
        <JSAny?>[
          _createJsObject(<String, JSAny?>{
            'account': account,
            'message': messageBytes.toJS,
          }),
        ],
      ),
    );
    final outputs = _coerceJsObjectList(result);
    if (outputs.isEmpty) {
      throw StateError(
          '${definition.name} did not return a message signature.');
    }
    final signature = _extractBytesProperty(outputs.first, 'signature');
    return base64Encode(signature);
  }

  @override
  Future<String> signTransactionBase64({
    required String transactionBase64,
    required String chainId,
  }) async {
    final account = _requireConnectedAccount();
    final feature = _getFeatureObject(_wallet, _solanaSignTransaction);
    final transactionBytes = base64Decode(transactionBase64);
    final result = await _awaitPromise(
      feature.callMethodVarArgs<JSAny?>(
        'signTransaction'.toJS,
        <JSAny?>[
          _createJsObject(<String, JSAny?>{
            'account': account,
            'transaction': transactionBytes.toJS,
            'chain': chainId.toJS,
          }),
        ],
      ),
    );
    final outputs = _coerceJsObjectList(result);
    if (outputs.isEmpty) {
      throw StateError(
          '${definition.name} did not return a signed transaction.');
    }
    final signedTransaction =
        _extractBytesProperty(outputs.first, 'signedTransaction');
    return base64Encode(signedTransaction);
  }

  @override
  Future<String> signAndSendTransactionBase64({
    required String transactionBase64,
    required String chainId,
  }) async {
    final account = _requireConnectedAccount();
    final feature = _getFeatureObject(_wallet, _solanaSignAndSendTransaction);
    final transactionBytes = base64Decode(transactionBase64);
    final result = await _awaitPromise(
      feature.callMethodVarArgs<JSAny?>(
        'signAndSendTransaction'.toJS,
        <JSAny?>[
          _createJsObject(<String, JSAny?>{
            'account': account,
            'transaction': transactionBytes.toJS,
            'chain': chainId.toJS,
          }),
        ],
      ),
    );
    final outputs = _coerceJsObjectList(result);
    if (outputs.isEmpty) {
      throw StateError(
        '${definition.name} did not return a transaction signature.',
      );
    }
    final signature = _extractBytesProperty(outputs.first, 'signature');
    return bs58.base58.encode(signature);
  }

  JSObject _requireConnectedAccount() {
    final account = _connectedAccount;
    if (account == null) {
      throw StateError('${definition.name} is not connected.');
    }
    return account;
  }
}

Future<JSAny?> _awaitPromise(JSAny? result) async {
  if (result is JSPromise<JSAny?>) {
    return result.toDart;
  }
  return result;
}

JSObject _createJsObject(Map<String, JSAny?> properties) {
  final object = JSObject();
  for (final entry in properties.entries) {
    object[entry.key] = entry.value;
  }
  return object;
}

JSObject? _getObjectProperty(JSObject object, String property) {
  final value = object.getProperty<JSAny?>(property.toJS);
  return value is JSObject ? value : null;
}

bool _hasFunction(JSObject object, String name) {
  final value = object.getProperty<JSAny?>(name.toJS);
  return value is JSFunction;
}

bool _hasObjectFeature(JSObject features, String name) {
  final feature = features.getProperty<JSAny?>(name.toJS);
  return feature is JSObject;
}

JSObject _getFeatureObject(JSObject wallet, String featureName) {
  final features = _getObjectProperty(wallet, 'features');
  if (features == null) {
    throw StateError('Wallet features are unavailable.');
  }
  final feature = features.getProperty<JSAny?>(featureName.toJS);
  if (feature is! JSObject) {
    throw StateError('Wallet feature "$featureName" is unavailable.');
  }
  return feature;
}

bool _supportsSolana(JSObject wallet) {
  final walletChains = _readStringList(wallet, 'chains');
  if (walletChains.any((chain) => chain.startsWith('solana:'))) {
    return true;
  }

  final accounts = _extractWalletAccounts(wallet);
  return accounts.any((account) {
    return _readStringList(account, 'chains')
        .any((chain) => chain.startsWith('solana:'));
  });
}

List<JSObject> _coerceJsObjectList(JSAny? value) {
  if (value is JSArray<JSAny?>) {
    return value.toDart.whereType<JSObject>().toList(growable: false);
  }
  if (value is JSObject) {
    return <JSObject>[value];
  }
  return const <JSObject>[];
}

List<JSObject> _extractWalletAccounts(JSAny? source) {
  if (source is! JSObject) return const <JSObject>[];
  final accounts = source.getProperty<JSAny?>('accounts'.toJS);
  if (accounts is! JSArray<JSAny?>) {
    return const <JSObject>[];
  }
  return accounts.toDart.whereType<JSObject>().toList(growable: false);
}

JSObject? _pickSolanaAccount(
  List<JSObject> accounts, {
  required String chainId,
}) {
  JSObject? fallback;
  for (final account in accounts) {
    final chains = _readStringList(account, 'chains');
    if (chains.contains(chainId)) {
      return account;
    }
    if (fallback == null &&
        chains.any((candidate) => candidate.startsWith('solana:'))) {
      fallback = account;
    }
  }
  return fallback;
}

String? _readProviderAddress(JSObject provider) {
  final publicKey = provider.getProperty<JSAny?>('publicKey'.toJS);
  return _stringifyPublicKey(publicKey);
}

String? _stringifyPublicKey(JSAny? publicKey) {
  if (publicKey is JSString) {
    return publicKey.toDart;
  }
  if (publicKey is JSObject && _hasFunction(publicKey, 'toString')) {
    final value = publicKey.callMethodVarArgs<JSAny?>(
      'toString'.toJS,
      const <JSAny?>[],
    );
    if (value is JSString) {
      return value.toDart;
    }
  }
  return null;
}

String? _readString(JSObject object, String property) {
  final value = object.getProperty<JSAny?>(property.toJS);
  if (value is JSString) {
    return value.toDart;
  }
  return null;
}

bool _readBool(JSObject object, String property) {
  final value = object.getProperty<JSAny?>(property.toJS);
  if (value is JSBoolean) {
    return value.toDart;
  }
  return false;
}

List<String> _readStringList(JSObject object, String property) {
  final value = object.getProperty<JSAny?>(property.toJS);
  if (value is! JSArray<JSAny?>) {
    return const <String>[];
  }

  return value.toDart
      .whereType<JSString>()
      .map((item) => item.toDart)
      .toList(growable: false);
}

Uint8List _extractBytesProperty(JSAny? source, String property) {
  if (source is! JSObject) {
    throw StateError('Expected object result with "$property".');
  }
  final value = source.getProperty<JSAny?>(property.toJS);
  return _coerceBytes(value);
}

Uint8List _coerceBytes(JSAny? value) {
  if (value is JSUint8Array) {
    return value.toDart;
  }
  if (value is JSArrayBuffer) {
    return JSUint8Array(value).toDart;
  }
  if (value is JSArray<JSAny?>) {
    final values = value.toDart;
    return Uint8List.fromList(
      values.map<int>((entry) => (entry as JSNumber).toDartInt).toList(),
    );
  }
  throw StateError('Expected byte array from browser wallet.');
}

String? _readSignatureString(JSAny? value) {
  if (value is JSString) {
    return value.toDart;
  }
  if (value is JSObject) {
    for (final key in const <String>['signature', 'hash', 'txid', 'result']) {
      final nested = value.getProperty<JSAny?>(key.toJS);
      if (nested is JSString && nested.toDart.isNotEmpty) {
        return nested.toDart;
      }
    }
  }
  return null;
}
