import 'dart:async';
import 'dart:typed_data';

import 'package:neoauth_console/core/api/api_client.dart';
import 'package:neoauth_console/core/api/api_exception.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const _stepUp = FakeReply(403, {'error': 'step_up_required', 'message': 'Sign in again to confirm this action.'});

void main() {
  late FakeAdapter adapter;
  late Dio dio;

  setUp(() {
    adapter = FakeAdapter();
    dio = Dio(BaseOptions(baseUrl: 'http://auth.test/admin'))..httpClientAdapter = adapter;
  });

  group('step-up', () {
    test('re-authenticates once and retries the request', () async {
      adapter.replies.addAll([
        _stepUp,
        const FakeReply(200, {'revoked': 3}),
      ]);
      var prompts = 0;
      final api = ApiClient(
        dio,
        onStepUp: () async {
          prompts++;
          return true;
        },
      );

      final body = await api.delete('/users/u1/sessions');

      expect(body, {'revoked': 3});
      expect(prompts, 1);
      expect(adapter.requests, hasLength(2));
      expect(adapter.requests.map((r) => '${r.method} ${r.path}'), everyElement('DELETE /users/u1/sessions'));
    });

    test('a dismissed prompt fails with step_up_cancelled and no retry', () async {
      adapter.replies.add(_stepUp);
      final api = ApiClient(dio, onStepUp: () async => false);

      await expectLater(
        api.post('/clients/c1/rotate-secret'),
        throwsA(isA<ApiException>().having((e) => e.isStepUpCancelled, 'cancelled', isTrue)),
      );
      expect(adapter.requests, hasLength(1));
    });

    test('a handler that throws counts as cancelled', () async {
      adapter.replies.add(_stepUp);
      final api = ApiClient(dio, onStepUp: () async => throw StateError('no navigator'));
      await expectLater(
        api.post('/x'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'step_up_cancelled')),
      );
    });

    test('prompts at most once per request: a second step_up_required is surfaced', () async {
      adapter.replies.addAll([_stepUp, _stepUp]);
      var prompts = 0;
      final api = ApiClient(
        dio,
        onStepUp: () async {
          prompts++;
          return true;
        },
      );
      await expectLater(
        api.post('/x'),
        throwsA(isA<ApiException>().having((e) => e.isStepUpRequired, 'step-up', isTrue)),
      );
      expect(prompts, 1);
    });

    test('concurrent requests share one prompt', () async {
      adapter.handler = (o) {
        // Every first attempt needs step-up; retries (after the prompt) succeed.
        final retried = adapter.requests.where((r) => r.path == o.path).length > 1;
        return retried ? const FakeReply(200, {'ok': true}) : _stepUp;
      };
      final gate = Completer<bool>();
      var prompts = 0;
      final api = ApiClient(
        dio,
        onStepUp: () {
          prompts++;
          return gate.future;
        },
      );

      final a = api.post('/a');
      final b = api.post('/b');
      await pumpEventQueue();
      expect(prompts, 1, reason: 'the second request waits for the open prompt');
      gate.complete(true);

      expect(await a, {'ok': true});
      expect(await b, {'ok': true});
      expect(prompts, 1);
    });

    test('a request sent before a finished step-up retries without a new prompt', () async {
      var prompts = 0;
      final api = ApiClient(
        dio,
        onStepUp: () async {
          prompts++;
          return true;
        },
      );
      // A slow request goes out with the old token...
      final slowReply = Completer<FakeReply>();
      final slowAdapter = _DeferredAdapter(adapter, slowReply);
      dio.httpClientAdapter = slowAdapter;
      final slow = api.post('/slow');
      await pumpEventQueue();
      // ...meanwhile another request steps up.
      dio.httpClientAdapter = adapter;
      adapter.replies.addAll([
        _stepUp,
        const FakeReply(200, {'fast': true}),
        const FakeReply(200, {'slow': true}),
      ]);
      expect(await api.post('/fast'), {'fast': true});
      expect(prompts, 1);
      // The slow one now comes back step_up_required: retried directly.
      slowReply.complete(_stepUp);
      expect(await slow, {'slow': true});
      expect(prompts, 1);
    });

    test('without a handler the original error is thrown', () async {
      adapter.replies.add(_stepUp);
      final api = ApiClient(dio);
      await expectLater(
        api.post('/x'),
        throwsA(isA<ApiException>().having((e) => e.isStepUpRequired, 'step-up', isTrue)),
      );
    });

    test('a plain 403 (missing role) never prompts', () async {
      adapter.replies.add(
        const FakeReply(403, {'message': 'requires the owner role', 'error': 'Forbidden', 'statusCode': 403}),
      );
      var prompts = 0;
      final api = ApiClient(
        dio,
        onStepUp: () async {
          prompts++;
          return true;
        },
      );
      await expectLater(
        api.get('/admins'),
        throwsA(isA<ApiException>().having((e) => e.isForbidden, 'forbidden', isTrue)),
      );
      expect(prompts, 0);
    });
  });

  group('error mapping', () {
    test('validation messages arrive as a list', () async {
      adapter.replies.add(
        const FakeReply(400, {
          'message': ['access_token_ttl must be an integer between 300 and 3600 seconds for public clients'],
          'error': 'Bad Request',
          'statusCode': 400,
        }),
      );
      final api = ApiClient(dio);
      try {
        await api.put('/apps/a/token-policy', body: {});
        fail('expected an error');
      } on ApiException catch (e) {
        expect(e.statusCode, 400);
        expect(e.isValidation, isTrue);
        expect(e.messages, hasLength(1));
        expect(e.friendly, startsWith('Access_token_ttl must be'));
      }
    });

    test('a string message and 404', () async {
      adapter.replies.add(
        const FakeReply(404, {'message': 'app "x" not found', 'error': 'Not Found', 'statusCode': 404}),
      );
      final api = ApiClient(dio);
      await expectLater(
        api.get('/apps/x'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.isNotFound, 'notFound', isTrue)
              .having((e) => e.message, 'message', 'app "x" not found'),
        ),
      );
    });

    test('no response is a network error', () {
      final e = ApiException.fromDio(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        ),
      );
      expect(e.isNetwork, isTrue);
      expect(e.friendly, contains("Can't reach the server"));
    });

    test('204 responses resolve to an empty map', () async {
      adapter.replies.add(const FakeReply(204));
      final api = ApiClient(dio);
      await api.postVoid('/users/u1/unsuspend');
      expect(adapter.requests.single.method, 'POST');
    });

    test('empty query values are dropped', () async {
      adapter.replies.add(const FakeReply(200, {'users': []}));
      final api = ApiClient(dio);
      await api.get('/users', query: {'q': '', 'before': null, 'limit': 50});
      expect(adapter.requests.single.queryParameters, {'limit': 50});
    });
  });
}

/// Answers the first request with [first] once it completes, then defers to [inner].
class _DeferredAdapter implements HttpClientAdapter {
  _DeferredAdapter(this.inner, this.first);
  final FakeAdapter inner;
  final Completer<FakeReply> first;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final reply = await first.future;
    inner.replies.insert(0, reply);
    return inner.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) {}
}
