import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/features/chat/data/pending_reactions.dart';
import 'package:reacti_app/helpers/di.dart';

import '../../../support/test_storage.dart';

/// A transport failure: the server was never reached.
DioException _offline() => DioException(
  requestOptions: RequestOptions(path: '/send'),
  type: DioExceptionType.connectionError,
);

/// The server answered, with an error.
DioException _refused() => DioException(
  requestOptions: RequestOptions(path: '/send'),
  response: Response(
    requestOptions: RequestOptions(path: '/send'),
    statusCode: 422,
  ),
  type: DioExceptionType.badResponse,
);

void main() {
  late List<Map> uploaded;
  late Object? Function() failWith;
  late PendingReactions store;
  late String clip;

  setUp(() async {
    await initTestGetStorage();
    await appData.erase();
    await appData.write(kKeyUserId, 5);
    uploaded = [];
    failWith = () => null;
    store = PendingReactions(
      upload: (entry) async {
        uploaded.add(entry);
        final error = failWith();
        if (error != null) throw error;
      },
    );
    final dir = await Directory.systemTemp.createTemp('pending_reactions');
    clip = '${dir.path}/reaction.mp4';
    File(clip).writeAsStringSync('clip');
  });

  void keep({String? path}) =>
      store.begin(path: path ?? clip, to: 42, group: false, replyTo: 7);

  test('a reaction the server got is not sent again', () async {
    keep();
    store.end(clip, sent: true);

    await store.resend();

    expect(uploaded, isEmpty);
  });

  test('a cut-off reaction is sent again once, to the same chat', () async {
    keep();
    store.end(clip, sent: false);

    await store.resend();
    await store.resend();

    expect(uploaded, hasLength(1));
    expect(uploaded.single, containsPair('path', clip));
    expect(uploaded.single, containsPair('to', 42));
    expect(uploaded.single, containsPair('reply', 7));
    expect(uploaded.single, containsPair('group', false));
  });

  test('a reaction still uploading is left alone', () async {
    keep();

    await store.resend();

    expect(uploaded, isEmpty);
  });

  test('it is kept while the server cannot be reached', () async {
    keep();
    store.end(clip, sent: false);
    failWith = _offline;
    await store.resend();

    failWith = () => null;
    await store.resend();

    expect(uploaded, hasLength(2));
  });

  test('it is dropped once the server answers with an error', () async {
    keep();
    store.end(clip, sent: false);
    failWith = _refused;
    await store.resend();

    await store.resend();

    expect(uploaded, hasLength(1));
  });

  test('another account does not send it, its own account does', () async {
    keep();
    store.end(clip, sent: false);

    await appData.write(kKeyUserId, 6);
    await store.resend();
    expect(uploaded, isEmpty);

    await appData.write(kKeyUserId, 5);
    await store.resend();
    expect(uploaded, hasLength(1));
  });

  test('a clip whose file is gone is dropped', () async {
    keep();
    store.end(clip, sent: false);
    File(clip).deleteSync();

    await store.resend();

    expect(uploaded, isEmpty);
  });
}
