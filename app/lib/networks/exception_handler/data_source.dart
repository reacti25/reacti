/// Thrown by an API call when the server answers with a status it does not
/// handle (anything other than the success code that call expects).
///
/// Callers only log it, push it onto a stream as an error, and show their own
/// generic message; analytics buckets it as `unknown`. Transport errors are
/// not wrapped in this: they stay `DioException`s.
final class Failure implements Exception {
  /// Creates the (field-less) unexpected-response failure.
  const Failure();

  @override
  String toString() => 'Failure: unexpected API response';
}
