/// Reown AppKit implementation of [ExternalWalletModalConnector].
///
/// This library is loaded via a `deferred` import from
/// `external_wallet_signer_service.dart`; keep it the ONLY importer of
/// `package:reown_appkit` so the whole WalletConnect stack stays out of the
/// initial web bundle.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:reown_appkit/reown_appkit.dart';

import '../config/api_keys.dart';
import '../config/config.dart';
import 'external_wallet_modal_connector.dart';

ExternalWalletModalConnector createReownConnector() => _ReownModalConnector();

class _ReownModalConnector implements ExternalWalletModalConnector {
  static const String _solanaNamespace = 'solana';

  ReownAppKitModal? _modal;
  BuildContext? _context;
  ReownAppKitModal? _subscribedModal;
  ExternalWalletModalCallbacks? _callbacks;

  @override
  bool get isConnected => _modal?.isConnected ?? false;

  @override
  Future<void> initialize(
    BuildContext context,
    ExternalWalletModalCallbacks callbacks,
  ) async {
    _callbacks = callbacks;
    final existing = _modal;
    if (existing != null && identical(_context, context)) {
      return;
    }

    _context = context;
    final projectId = ApiKeys.walletConnectProjectId.trim();
    if (projectId.isEmpty || projectId == 'YOUR_WALLETCONNECT_PROJECT_ID') {
      throw StateError('WalletConnect project ID is not configured.');
    }

    final modal = ReownAppKitModal(
      context: context,
      projectId: projectId,
      metadata: const PairingMetadata(
        name: 'art.kubus',
        description: 'Noncustodial art.kubus wallet signing',
        url: 'https://app.kubus.site',
        icons: ['https://app.kubus.site/icons/Icon-512.png'],
        redirect: Redirect(
          native: kExternalWalletCallbackUri,
          universal: 'https://app.kubus.site/walletconnect',
        ),
      ),
      optionalNamespaces: {
        _solanaNamespace: RequiredNamespace(
          chains: ReownAppKitModalNetworks.getAllSupportedNetworks(
            namespace: _solanaNamespace,
          ).map((network) => network.chainId).toList(),
          methods: NetworkUtils.defaultNetworkMethods[_solanaNamespace] ??
              const <String>[
                'solana_signMessage',
                'solana_signTransaction',
                'solana_signAllTransactions',
                'solana_signAndSendTransaction',
              ],
          events: NetworkUtils.defaultNetworkEvents[_solanaNamespace] ??
              const <String>[],
        ),
      },
      logLevel: kDebugMode ? LogLevel.error : LogLevel.nothing,
      enableAnalytics: AppConfig.enableAnalytics,
    );
    _modal = modal;
    await modal.init();
    _subscribe(modal);
  }

  void _subscribe(ReownAppKitModal modal) {
    if (identical(_subscribedModal, modal)) return;
    _subscribedModal = modal;
    modal.onModalConnect.subscribe(_handleModalConnect);
    modal.onModalUpdate.subscribe(_handleModalConnect);
    modal.onModalDisconnect.subscribe(_handleModalDisconnect);
    modal.onModalError.subscribe(_handleModalError);
  }

  void _handleModalConnect(ModalConnect? event) {
    _callbacks?.onConnectOrUpdate();
  }

  void _handleModalDisconnect(ModalDisconnect? event) {
    _callbacks?.onDisconnect();
  }

  void _handleModalError(ModalError? event) {
    _callbacks?.onError(event?.message);
  }

  @override
  ExternalWalletModalSession? currentSession() {
    final modal = _modal;
    final session = modal?.session;
    if (modal == null || session == null) return null;

    final address = (session.getAddress(_solanaNamespace) ?? '').trim();
    if (address.isEmpty) return null;
    final walletName = (session.connectedWalletName ??
            modal.selectedWallet?.listing.name ??
            '')
        .trim();

    return ExternalWalletModalSession(
      address: address,
      walletName: walletName,
    );
  }

  @override
  Future<void> openModalView() async {
    final modal = _modal;
    if (modal == null) {
      throw StateError('External wallet signer is not initialized.');
    }
    await modal.openModalView();
  }

  @override
  Future<void> disconnect() async {
    final modal = _modal;
    if (modal != null && modal.isConnected) {
      await modal.disconnect();
    }
  }

  @override
  Future<bool> dispatchEnvelope(String uri) async {
    final modal = _modal;
    if (modal == null) return false;
    return modal.dispatchEnvelope(uri);
  }

  @override
  String? solanaChainId() {
    final modal = _modal;
    final selected = (modal?.selectedChain?.chainId ?? '').trim();
    if (selected.contains(':')) return selected;
    if (selected.isNotEmpty) return '$_solanaNamespace:$selected';

    final sessionChain = (modal?.session?.chainId ?? '').trim();
    if (sessionChain.contains(':')) return sessionChain;
    if (sessionChain.isNotEmpty) return '$_solanaNamespace:$sessionChain';
    return null;
  }

  @override
  Future<dynamic> requestSolana({
    required String method,
    required Map<String, dynamic> params,
  }) async {
    final modal = _modal;
    final session = modal?.session;
    if (modal == null || session == null) {
      throw StateError('External wallet signer is not connected.');
    }
    return modal.request(
      topic: session.topic,
      chainId: solanaChainId() ?? '',
      request: SessionRequestParams(
        method: method,
        params: params,
      ),
    );
  }
}
