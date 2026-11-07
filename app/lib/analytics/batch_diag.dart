// TEMPORARY diagnostics for one bug: on a real iPhone, a captioned batch of 3
// photos in a group shows only 2 photos and no caption until the group is
// reopened (Achia, staging 1205), and the testing lab cannot reproduce it. The
// private chat logs the same steps, as the working case to compare with.
// Delete this file and its calls once the cause is known.

import 'analytics_config.dart';
import 'analytics_locator.dart';
import 'events.dart';

/// Whether diagnostics are sent: staging builds only, never production.
bool batchDiagEnabled = AnalyticsConfig.env == 'staging';

/// Temp ids start above this (see message_reconciler.dart).
const int _tempIdFrom = 1000000000000;

int _seq = 0;
final Set<String> _drawn = {};
final Map<String, int> _lastRows = {};

/// Sends one numbered [step] of [scope] (`group` or `private`) with [detail].
///
/// Never pass message text: only ids, types and text lengths.
void batchDiag(String scope, String step, [String detail = '']) {
  if (!batchDiagEnabled) return;
  analytics.track(Events.batchDiag, {
    Props.diagSeq: _seq++,
    Props.scope: scope,
    Props.diagStep: step,
    Props.diagDetail: detail,
  });
}

/// One message as `id:type:textLength`, temp ids shortened to `T` + last 4.
String batchDiagItem(int? id, String? type, String? text) {
  final shown = (id ?? 0) > _tempIdFrom ? 'T${id! % 10000}' : '$id';
  return '$shown:${type ?? 'text'}:${(text ?? '').trim().length}';
}

/// The newest [items] of a thread (newest first), with the thread's length.
String batchDiagSnap(List<(int?, String?, String?)> items) {
  final shown = items.take(6).map((m) => batchDiagItem(m.$1, m.$2, m.$3));
  return 'n=${items.length} ${shown.join(',')}';
}

/// Logs the first time a message's bubble is drawn: a message in the list that
/// never logs this is in the data but not on the screen.
void batchDiagDraw(String scope, int? id, String? type, String? text) {
  if (!batchDiagEnabled || !_drawn.add('$scope$id')) return;
  batchDiag(scope, 'draw', batchDiagItem(id, type, text));
}

/// Logs the row count of the thread when it changes.
void batchDiagRows(String scope, int rows) {
  if (!batchDiagEnabled || _lastRows[scope] == rows) return;
  _lastRows[scope] = rows;
  batchDiag(scope, 'rows', '$rows');
}
