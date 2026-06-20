// Tests for the mark_viewed_result instrumentation emitted from the view-inbox
// and view-group rx layers. A failed mark-viewed silently aborts the patent
// reaction flow, so this event is how that failure becomes visible.
//
// The failure cases use a plain Exception (never a DioException), whose handler
// branch calls ToastUtil (GetX + screenutil) and is not test-safe — the
// DioException -> failure_reason mapping itself is covered in
// analytics_buckets_test.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/analytics/analytics_service.dart';
import 'package:reacti_app/analytics/events.dart';
import 'package:reacti_app/features/chat/data/rx_view_group_file/api.dart';
import 'package:reacti_app/features/chat/data/rx_view_group_file/rx.dart';
import 'package:reacti_app/features/chat/data/rx_view_inbox_image/api.dart';
import 'package:reacti_app/features/chat/data/rx_view_inbox_image/rx.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:rxdart/subjects.dart';

import '../support/fake_analytics_service.dart';

class _OkInboxApi implements ViewInboxImageApi {
  @override
  Future<Map> viewInboxImage({required int id}) async => {'success': true};
}

class _FailInboxApi implements ViewInboxImageApi {
  @override
  Future<Map> viewInboxImage({required int id}) async =>
      throw Exception('mark-viewed failed');
}

class _OkGroupApi implements ViewGroupFileApi {
  @override
  Future<Map> viewGroupFile({required int id}) async => {'success': true};
}

ViewInboxImageRx _inboxRx(ViewInboxImageApi api) {
  final fetcher = BehaviorSubject<Map>();
  // Swallow stream errors so a failure-path addError isn't "unhandled".
  fetcher.stream.listen((_) {}, onError: (_) {});
  return ViewInboxImageRx(api: api, empty: {}, dataFetcher: fetcher);
}

void main() {
  late FakeAnalyticsService analytics;

  void register(FakeAnalyticsService service) {
    if (locator.isRegistered<AnalyticsService>()) {
      locator.unregister<AnalyticsService>();
    }
    locator.registerSingleton<AnalyticsService>(service);
  }

  setUp(() {
    analytics = FakeAnalyticsService();
    register(analytics);
  });

  tearDown(() {
    if (locator.isRegistered<AnalyticsService>()) {
      locator.unregister<AnalyticsService>();
    }
  });

  test(
    'a successful 1:1 mark-viewed emits result=success (no reason)',
    () async {
      await _inboxRx(_OkInboxApi()).viewInboxImage(id: 7);

      final props = analytics.propsOf(Events.markViewedResult)!;
      expect(props[Props.scope], 'private');
      expect(props[Props.result], 'success');
      expect(props.containsKey(Props.failureReason), isFalse);
    },
  );

  test('a failed 1:1 mark-viewed emits result=failure with a reason', () async {
    await _inboxRx(_FailInboxApi()).viewInboxImage(id: 7);

    final props = analytics.propsOf(Events.markViewedResult)!;
    expect(props[Props.result], 'failure');
    // A plain (non-dio) error maps to unknown.
    expect(props[Props.failureReason], 'unknown');
  });

  test('the group mark-viewed reports scope=group', () async {
    final fetcher = BehaviorSubject<Map>();
    final rx = ViewGroupFileRx(
      api: _OkGroupApi(),
      empty: {},
      dataFetcher: fetcher,
    );

    await rx.viewGroupFile(id: 9);

    final props = analytics.propsOf(Events.markViewedResult)!;
    expect(props[Props.scope], 'group');
    expect(props[Props.result], 'success');
  });

  test('an opted-out user emits no mark_viewed_result', () async {
    register(FakeAnalyticsService(isOptedOut: () => true));

    await _inboxRx(_OkInboxApi()).viewInboxImage(id: 7);

    // Re-read the registered service to assert nothing was captured.
    final service = locator<AnalyticsService>() as FakeAnalyticsService;
    expect(service.countOf(Events.markViewedResult), 0);
  });
}
