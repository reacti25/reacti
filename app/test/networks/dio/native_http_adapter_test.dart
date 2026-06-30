import 'package:flutter_test/flutter_test.dart';
import 'package:native_dio_adapter/native_dio_adapter.dart';
import 'package:reacti_app/helpers/feature_flags.dart';
import 'package:reacti_app/networks/dio/dio.dart';

/// Reports the native-HTTP flag as on; every other flag stays at its default.
class _NativeHttpOnFlagSource implements FlagSource {
  @override
  bool? cached(String key) => key == Flags.nativeHttp ? true : null;

  @override
  Future<void> reload(Iterable<String> keys) async {}
}

void main() {
  tearDown(FeatureFlags.debugResetInstance);

  group('native HTTP adapter gating (3.3)', () {
    test('is OFF by default — prod/test builds keep the Dart HTTP stack', () {
      // Default resolver: no override, empty remote cache, default=false.
      expect(useNativeHttpAdapter(), isFalse);

      DioSingleton.instance.create();
      // The patented upload path must run on the unchanged client.
      expect(
        DioSingleton.instance.dio.httpClientAdapter,
        isNot(isA<NativeAdapter>()),
      );
    });

    test('flips to the native adapter only when the flag is enabled', () {
      FeatureFlags.debugInstance = FeatureFlags.withSource(
        _NativeHttpOnFlagSource(),
      );
      expect(useNativeHttpAdapter(), isTrue);

      DioSingleton.instance.create();
      expect(DioSingleton.instance.dio.httpClientAdapter, isA<NativeAdapter>());
    });
  });
}
