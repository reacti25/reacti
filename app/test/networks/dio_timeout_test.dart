// Pins the Dio connect timeout (backlog §7 / EP8).
//
// connectTimeout was 10 minutes, so a dead server / no network left the user
// on a spinner for ten minutes. It is now 30 seconds. receiveTimeout is left
// generous on purpose (slow-network upload responses), so it is not asserted
// here.

import 'package:reacti_app/networks/dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('create() builds a client with a 30s connect timeout', () {
    DioSingleton.instance.create();

    expect(
      DioSingleton.instance.dio.options.connectTimeout,
      const Duration(seconds: 30),
    );
  });

  test('update() keeps the 30s connect timeout', () {
    DioSingleton.instance.update('token');

    expect(
      DioSingleton.instance.dio.options.connectTimeout,
      const Duration(seconds: 30),
    );
  });
}
