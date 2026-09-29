import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A response recorded from the local backend (`test/fixtures`).
Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync()) as Map<String, dynamic>;

/// One canned reply for [FakeAdapter].
class FakeReply {
  const FakeReply(this.status, [this.body]);
  final int status;
  final Object? body;
}

/// A Dio adapter that answers from a queue and records every request, so
/// tests can script sequences like "403 step_up_required, then 200".
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter([List<FakeReply>? replies]) : replies = replies ?? [];

  final List<FakeReply> replies;
  final List<RequestOptions> requests = [];

  /// Optional router: when set, it answers instead of the queue.
  FakeReply Function(RequestOptions options)? handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final reply = handler?.call(options) ?? (replies.isNotEmpty ? replies.removeAt(0) : const FakeReply(500));
    final body = reply.body == null ? '' : jsonEncode(reply.body);
    return ResponseBody.fromString(
      body,
      reply.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// An unsigned JWT with the given claims (the app only reads claims).
String fakeJwt(Map<String, Object?> claims) {
  String part(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${part({'alg': 'none'})}.${part(claims)}.sig';
}
