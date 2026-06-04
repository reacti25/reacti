import 'dart:developer';

import 'package:rxdart/subjects.dart';

/// Base class for the per-feature `Rx` data objects that wrap an API call and
/// expose its result as a reactive stream.
///
/// Each concrete subclass binds a typed response [T] to a [BehaviorSubject]
/// ([dataFetcher]) that widgets listen to. This class supplies the shared
/// success/error plumbing so subclasses only implement the request itself.
abstract class RxResponseInt<T> {
  /// The "empty"/initial value emitted by [clean] to reset the stream.
  T empty;

  /// The reactive stream subjects emit responses (or errors) onto.
  BehaviorSubject<T> dataFetcher;

  /// Optional request payload some subclasses populate before dispatching.
  Map? map;

  /// Optional secondary subject for subclasses that expose a second stream.
  BehaviorSubject? dataFetcher2;

  /// Creates the base object.
  ///
  /// [empty] and [dataFetcher] are required; [map] and [dataFetcher2] are
  /// optional and only used by subclasses that need them.
  RxResponseInt({
    required this.empty,
    required this.dataFetcher,
    this.map,
    this.dataFetcher2,
  });

  /// Pushes a successful [data] response onto [dataFetcher] and returns it,
  /// so callers can both react to the stream and use the value inline.
  dynamic handleSuccessWithReturn(T data) {
    dataFetcher.sink.add(data);
    return data;
  }

  /// Logs [error], emits it onto [dataFetcher] as a stream error, then
  /// rethrows it so the caller's `await` also fails.
  dynamic handleErrorWithReturn(dynamic error) {
    log(error.toString());
    dataFetcher.sink.addError(error);
    throw error;
  }

  /// Resets the stream by emitting [empty] — used to clear stale state.
  void clean() {
    dataFetcher.sink.add(empty);
  }

  /// Closes [dataFetcher] to release its resources; call when done listening.
  void dispose() {
    dataFetcher.close();
  }
}
