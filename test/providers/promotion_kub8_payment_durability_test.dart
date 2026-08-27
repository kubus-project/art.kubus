import 'dart:convert';

import 'package:art_kubus/models/promotion.dart';
import 'package:art_kubus/providers/promotion_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The key the provider records an unverified transfer under.
const String _pendingKey = 'promotion_pending_kub8_payment_v1';

PromotionRequestSubmission _submission() => PromotionRequestSubmission(
      request: PromotionRequest.fromJson(<String, dynamic>{'id': 'req-1'}),
      kub8Payment: PromotionQuoteKub8(
        mintAddress: 'BnRyTep3pLBJrBDt9UxbRYeh3jzQt4nrG99FT3yoKXrm',
        decimals: 6,
        amountRaw: BigInt.from(1500000),
        amount: '1.5',
        cluster: 'devnet',
        destinationOwner: 'DestOwner11111111111111111111111111111111111',
      ),
    );

Future<String> _signer({
  required String mintAddress,
  required String destinationOwner,
  required BigInt rawAmount,
  required int decimals,
}) async =>
    'signature-1';

/// A KUB8 promotion payment is a real on-chain transfer of the user's money.
///
/// Between the wallet returning a signature and the backend confirming
/// finalization, the only thing that knows which promotion that transfer paid
/// for is the app. If that knowledge lives solely in memory and the process
/// stops, the request reads as `awaiting_payment` on restart and the user is
/// invited to pay a second time for something already paid.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting(null);
  });

  test('the submitted signature is durable before verification is attempted',
      () async {
    final api = BackendApiService();
    // Verification never succeeds here, standing in for everything between
    // "the transfer is on chain" and "the backend agreed it is".
    api.setHttpClient(
      MockClient((_) async => http.Response('{"success":false}', 500)),
    );
    final provider = PromotionProvider(api: api);

    await provider.payPromotionWithKub8(
      submission: _submission(),
      signer: _signer,
    );

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingKey);
    expect(raw, isNotNull,
        reason: 'the transfer already happened; losing this record is a '
            'second payment for the same promotion');
    final decoded = jsonDecode(raw!) as Map<String, dynamic>;
    expect(decoded['requestId'], 'req-1');
    expect(decoded['signature'], 'signature-1');
  });

  test('a restart resumes the transfer instead of presenting it as unpaid',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      _pendingKey: jsonEncode(<String, String>{
        'requestId': 'req-9',
        'signature': 'signature-9',
      }),
    });

    // A brand-new provider, as after a cold start.
    final provider = PromotionProvider(api: BackendApiService());
    final resumed = await provider.restorePendingKub8Payment();

    expect(resumed, 'req-9');
    expect(provider.pendingKub8RequestId, 'req-9');
    expect(provider.pendingKub8Signature, 'signature-9');
    expect(provider.kub8Stage, Kub8PaymentStage.submitted);
  });

  test('the record is cleared only once the backend confirms', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      _pendingKey: jsonEncode(<String, String>{
        'requestId': 'req-3',
        'signature': 'signature-3',
      }),
    });
    final api = BackendApiService();
    api.setHttpClient(
      MockClient(
        (_) async => http.Response(
          jsonEncode(<String, Object?>{
            'success': true,
            'data': <String, Object?>{
              'request': <String, Object?>{'id': 'req-3'},
            },
          }),
          200,
        ),
      ),
    );
    final provider = PromotionProvider(api: api);

    final outcome = await provider.verifyPendingKub8Payment(
      requestId: 'req-3',
      signature: 'signature-3',
    );

    expect(outcome.stage, Kub8PaymentStage.confirmed);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_pendingKey), isNull);
  });

  test('a verification that fails keeps the record for a retry', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      _pendingKey: jsonEncode(<String, String>{
        'requestId': 'req-4',
        'signature': 'signature-4',
      }),
    });
    final api = BackendApiService();
    api.setHttpClient(
      MockClient((_) async => http.Response('{"success":false}', 500)),
    );
    final provider = PromotionProvider(api: api);

    await provider.verifyPendingKub8Payment(
      requestId: 'req-4',
      signature: 'signature-4',
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_pendingKey), isNotNull,
        reason: 'a failed verification must leave the user able to retry '
            'rather than pay again');
  });
}
