import 'dart:async';

import 'package:dio/dio.dart';

import 'api_exception.dart';

/// Asks the admin to sign in again (step-up). Resolves to true when a fresh
/// sign-in for the same account happened and the request may be retried.
typedef StepUpHandler = Future<bool> Function();

/// Typed access to the admin API.
///
/// Every call maps failures to [ApiException]. A `403 step_up_required`
/// (the action needs a sign-in from the last 15 minutes) triggers
/// [onStepUp] once, and the request is retried automatically after it
/// succeeds. Concurrent step-ups share one prompt.
class ApiClient {
  ApiClient(this._dio, {this.onStepUp});

  final Dio _dio;

  /// Set by the UI layer once there is a navigator to show the sheet on.
  StepUpHandler? onStepUp;

  Future<bool>? _stepUpInFlight;

  Future<Map<String, dynamic>> get(String path, {Map<String, Object?>? query}) =>
      _json(() => _dio.get<Object?>(path, queryParameters: _clean(query)));

  Future<Map<String, dynamic>> post(String path, {Object? body}) =>
      _json(() => _dio.post<Object?>(path, data: body ?? const <String, Object?>{}));

  Future<Map<String, dynamic>> patch(String path, {Object? body}) => _json(() => _dio.patch<Object?>(path, data: body));

  Future<Map<String, dynamic>> put(String path, {Object? body}) => _json(() => _dio.put<Object?>(path, data: body));

  Future<Map<String, dynamic>> delete(String path) => _json(() => _dio.delete<Object?>(path));

  /// For endpoints answering 204 No Content.
  Future<void> postVoid(String path, {Object? body}) =>
      _json(() => _dio.post<Object?>(path, data: body ?? const <String, Object?>{}));

  Future<void> deleteVoid(String path) => _json(() => _dio.delete<Object?>(path));

  static Map<String, Object?>? _clean(Map<String, Object?>? q) {
    if (q == null) return null;
    return {
      for (final e in q.entries)
        if (e.value != null && e.value.toString().isNotEmpty) e.key: e.value,
    };
  }

  Future<Map<String, dynamic>> _json(Future<Response<Object?>> Function() send) async {
    final data = await run(send);
    if (data is Map) return data.cast<String, dynamic>();
    return const <String, dynamic>{};
  }

  /// Runs [send], handling step-up and error mapping. Public for tests.
  Future<Object?> run(Future<Response<Object?>> Function() send) async {
    final sentAt = DateTime.now();
    try {
      return (await send()).data;
    } on DioException catch (e) {
      final error = ApiException.fromDio(e);
      if (!error.isStepUpRequired) throw error;
      final handler = onStepUp;
      if (handler == null) throw error;
      // Sent with the old token while another request's step-up finished:
      // the session is fresh now, so just retry.
      final freshSince = _lastStepUp;
      final alreadyFresh = freshSince != null && freshSince.isAfter(sentAt);
      if (!alreadyFresh && !await _stepUp(handler)) throw ApiException.stepUpCancelled;
      try {
        // The SDK interceptor attaches the new session's token on the retry.
        return (await send()).data;
      } on DioException catch (e) {
        throw ApiException.fromDio(e);
      }
    }
  }

  DateTime? _lastStepUp;

  /// One prompt at a time: concurrent callers wait for the same answer.
  Future<bool> _stepUp(StepUpHandler handler) {
    final existing = _stepUpInFlight;
    if (existing != null) return existing;
    Future<bool> prompt() async {
      try {
        final ok = await handler();
        if (ok) _lastStepUp = DateTime.now();
        return ok;
      } catch (_) {
        return false;
      } finally {
        _stepUpInFlight = null;
      }
    }

    return _stepUpInFlight = prompt();
  }
}
