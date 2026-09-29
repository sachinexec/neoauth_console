import 'package:neoauth/neoauth.dart';
import 'package:dio/dio.dart';

/// A failed admin-API call, from the server's `{statusCode, message, error}`
/// body (or a network / session failure).
class ApiException implements Exception {
  const ApiException({required this.statusCode, required this.code, required this.messages});

  /// HTTP status, or null when the request never got a response.
  final int? statusCode;

  /// The `error` field, e.g. `Bad Request`, `step_up_required`, or a
  /// client-side code: `network_error`, `session_ended`, `step_up_cancelled`.
  final String code;

  /// The `message` field: validation errors come back as a list.
  final List<String> messages;

  String get message => messages.isEmpty ? 'Something went wrong.' : messages.join('\n');

  bool get isStepUpRequired => statusCode == 403 && code == 'step_up_required';
  bool get isStepUpCancelled => code == 'step_up_cancelled';
  bool get isForbidden => statusCode == 403 && !isStepUpRequired;
  bool get isNotFound => statusCode == 404;
  bool get isNetwork => code == 'network_error';
  bool get isSessionEnded => code == 'session_ended' || statusCode == 401;
  bool get isValidation => statusCode == 400 || statusCode == 409;

  static const stepUpCancelled = ApiException(
    statusCode: 403,
    code: 'step_up_cancelled',
    messages: ['Confirm it is you to continue.'],
  );

  /// A message fit for a snackbar or error view.
  String get friendly {
    if (isNetwork) return "Can't reach the server. Check your connection and try again.";
    if (isSessionEnded) return 'Your session has ended. Sign in again.';
    if (isStepUpCancelled) return 'Cancelled: this action needs you to confirm it is you.';
    if (isForbidden) return "You don't have permission to do that.";
    if (statusCode != null && statusCode! >= 500) return 'The server had a problem. Try again in a moment.';
    return _capitalise(message);
  }

  static String _capitalise(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  factory ApiException.fromDio(DioException e) {
    final inner = e.error;
    if (inner is NeoAuthException) {
      return ApiException(
        statusCode: inner.status,
        code: inner.isSessionEnded ? 'session_ended' : inner.error,
        messages: [inner.description],
      );
    }
    final response = e.response;
    if (response == null) {
      return ApiException(statusCode: null, code: 'network_error', messages: [e.message ?? 'Network error']);
    }
    return ApiException.fromBody(response.statusCode, response.data);
  }

  factory ApiException.fromBody(int? status, Object? body) {
    if (body is Map) {
      final raw = body['message'] ?? body['error_description'];
      final messages = switch (raw) {
        List() => raw.map((m) => m.toString()).toList(),
        null => <String>[],
        _ => [raw.toString()],
      };
      return ApiException(
        statusCode: (body['statusCode'] as num?)?.toInt() ?? status,
        code: body['error']?.toString() ?? 'request_failed',
        messages: messages,
      );
    }
    return ApiException(
      statusCode: status,
      code: 'request_failed',
      messages: [if (body is String && body.isNotEmpty) body else 'Request failed ($status)'],
    );
  }

  @override
  String toString() => 'ApiException($statusCode $code: $message)';
}
