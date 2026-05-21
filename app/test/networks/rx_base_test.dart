// Locks the contract of RxResponseInt — the abstract base class that
// every rx_* data source in the app extends (39 of them at last count).
//
// Each rx_* class inherits four behaviors from this base. They are not
// otherwise unit-tested anywhere, yet a regression here would silently
// affect every networked data source:
//
//   handleSuccessWithReturn(data) — push `data` onto the stream, return it
//   handleErrorWithReturn(error)  — push the error onto the stream, rethrow
//   clean()                       — push the `empty` sentinel onto the stream
//   dispose()                     — close the stream
//
// The remaining rx_* surface (per-endpoint HTTP behavior) cannot be
// unit-tested without a production change: the data sources are `final`
// and reach HTTP through non-injectable `*.instance` singletons. That
// gap is tracked in docs/testing/inventory.md §8. This file covers the
// one piece of the rx layer that *is* reachable without touching
// production code — the shared base.

import 'package:reacti_app/networks/rx_base.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/subjects.dart';

/// Minimal concrete RxResponseInt so the abstract base can be
/// exercised directly. Mirrors how every real rx_* class is built:
/// an `empty` sentinel plus a BehaviorSubject as the data fetcher.
class _ProbeRx extends RxResponseInt<Map> {
  _ProbeRx({required super.empty, required super.dataFetcher});
}

void main() {
  late _ProbeRx rx;
  late BehaviorSubject<Map> fetcher;

  setUp(() {
    fetcher = BehaviorSubject<Map>();
    rx = _ProbeRx(empty: const {}, dataFetcher: fetcher);
  });

  tearDown(() {
    if (!fetcher.isClosed) fetcher.close();
  });

  group('RxResponseInt — handleSuccessWithReturn', () {
    test('emits the data as the latest value on the stream', () {
      rx.handleSuccessWithReturn({'id': 7});
      expect(fetcher.value, {'id': 7});
    });

    test('returns the same data it was given', () {
      final returned = rx.handleSuccessWithReturn({'id': 7});
      expect(returned, {'id': 7});
    });
  });

  group('RxResponseInt — handleErrorWithReturn', () {
    test('emits the error on the stream and rethrows it', () {
      final error = Exception('boom');

      // The stream should surface the error...
      expectLater(fetcher.stream, emitsError(error));

      // ...and the call itself should rethrow rather than swallow.
      expect(() => rx.handleErrorWithReturn(error), throwsA(error));
    });
  });

  group('RxResponseInt — clean', () {
    test('emits the empty sentinel', () {
      final emptyFetcher = BehaviorSubject<Map>();
      final emptyRx = _ProbeRx(
        empty: const {'state': 'empty'},
        dataFetcher: emptyFetcher,
      );
      addTearDown(emptyRx.dispose);

      emptyRx.clean();
      expect(emptyFetcher.value, {'state': 'empty'});
    });
  });

  group('RxResponseInt — dispose', () {
    test('closes the underlying stream', () {
      expect(fetcher.isClosed, isFalse);
      rx.dispose();
      expect(fetcher.isClosed, isTrue);
    });
  });
}
