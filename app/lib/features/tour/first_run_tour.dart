import 'package:flutter/material.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:showcaseview/showcaseview.dart';

/// The one-time "how to use Reacti" tour — three coach marks over the real
/// home screen (docs/PLAN-onboarding-walkthrough-2026-08-15.md).
///
/// Deliberately **not** the Demo Reacti. The demo teaches the *idea* (a sealed
/// clip, your captured reaction) and exists to make the product land; this
/// teaches the *mechanics* — where the tabs are and how to start talking to
/// someone. They run back to back: demo first, then this.
///
/// The marks point at **controls, not content**. A brand-new account has no
/// chats, no friends and no requests, so anything that highlighted a list item
/// would spotlight an empty box on the one run that matters.
///
/// ponytail: static keys + two functions, no controller class. There is one
/// tour, it has three steps, and it runs once.
class FirstRunTour {
  FirstRunTour._();

  /// Target of mark 1 — the Chat tab in the bottom bar.
  static final GlobalKey chatTabKey = GlobalKey();

  /// Target of mark 2 — the Friends tab, where an empty account has to start.
  static final GlobalKey friendsTabKey = GlobalKey();

  /// Target of mark 3 — the new-group control on the chat screen.
  static final GlobalKey newGroupKey = GlobalKey();

  /// Whether the tour has already run to completion (or been skipped).
  static bool get seen => appData.read(kKeyTourSeen) == true;

  /// Records that the tour is done, so it never auto-fires again.
  static void markSeen() => appData.write(kKeyTourSeen, true);

  /// Clears every tour flag, putting the app back to its first-run state as
  /// far as the walkthrough is concerned.
  ///
  /// Replaying only the home tour is not enough to review the walkthrough:
  /// the two just-in-time marks are consumed the first time their screens are
  /// reached, so without this the only way to see them again is a fresh
  /// install. After a reset they re-arm and fire on the next visit to the
  /// Contacts tab and to a 1:1 chat.
  static void resetAll() {
    appData.remove(kKeyTourSeen);
    appData.remove(kKeyTourInviteSeen);
    appData.remove(kKeyTourAttachSeen);
    appData.remove(kKeyTourSentMediaSeen);
    appData.remove(kKeyTourSealedSeen);
    _markOwners.clear();
  }

  /// Which message id currently owns each message-level mark.
  static final Map<String, int> _markOwners = {};

  /// Whether [messageId] may carry the mark gated by [storageKey].
  ///
  /// The message-level marks live on list items, and a thread can render
  /// several matching messages at once — two of them building the same
  /// [GlobalKey] is a hard crash, not a cosmetic bug. The first message to ask
  /// wins and keeps the key across rebuilds, so the tip lands on one bubble and
  /// stays there.
  ///
  /// An existing owner is answered without re-reading storage on purpose:
  /// [showOnce] writes the flag as the tip opens, and a thread rebuilds
  /// constantly (every keystroke, every arriving message). Re-checking would
  /// pull the target out from under a tip the user is still reading.
  ///
  /// ponytail: a map, not a per-mark owner class. There are two marks.
  static bool claimMark(String storageKey, int messageId) {
    final owner = _markOwners[storageKey];
    if (owner != null) return owner == messageId;
    if (appData.read(storageKey) == true) return false;
    _markOwners[storageKey] = messageId;
    return true;
  }

  /// Guards against re-registering the controller on a second call —
  /// `ShowcaseView.register` adds to a global service, not to the tree.
  static bool _registered = false;

  /// Registers the showcase controller once per process.
  ///
  /// Public because [TourMark] has to call it before it builds: a `Showcase`
  /// throws outright if no controller is registered, and the mark is built
  /// during the frame *before* any `start`/`showOnce` post-frame callback
  /// runs. A user who had already finished the home tour (so `start()` returns
  /// early) would otherwise crash the moment a marked screen was opened.
  static void ensureRegistered() => _ensureRegistered();

  /// Registers the showcase controller once per process.
  static void _ensureRegistered() {
    if (_registered) return;
    ShowcaseView.register(
      // A mark whose target is missing is skipped rather than crashing the
      // tour — cheap insurance against a screen being rearranged later.
      skipIfTargetNotPresent: true,
      enableAutoScroll: false,
    );
    _registered = true;
  }

  /// Starts the home tour.
  ///
  /// Auto-run passes [force] `false`, so it is a no-op once [seen]. The
  /// Profile replay row passes `true` — without a way back in, the tour can
  /// only ever be examined on a fresh install, which is exactly the problem
  /// the demo hit before it got its own replay row.
  static void start({bool force = false}) {
    if (!force && seen) return;
    _ensureRegistered();
    // Marked seen on START, not on finish. All sequences share one registered
    // controller, so a completion callback could not tell which sequence had
    // ended — a just-in-time mark finishing would have marked the home tour
    // seen. Marking here also means a user who force-quits mid-tour isn't
    // shown it again, which is the kinder failure.
    markSeen();
    ShowcaseView.get().startShowCase([chatTabKey, friendsTabKey, newGroupKey]);
  }

  /// Shows a single just-in-time mark the first time its screen is reached.
  ///
  /// [storageKey] is the one-time flag; [markKey] the target. Returns without
  /// consuming the flag when the target is not laid out yet — a tab that has
  /// been built off-screen would otherwise burn the mark on a frame nobody
  /// saw, and the user would never get the tip.
  static void showOnce({
    required GlobalKey markKey,
    required String storageKey,
  }) {
    if (appData.read(storageKey) == true) return;

    final box = markKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;

    appData.write(storageKey, true);
    _ensureRegistered();
    ShowcaseView.get().startShowCase([markKey]);
  }

  /// Target of the just-in-time mark on the "Invite friends" button.
  static final GlobalKey inviteKey = GlobalKey();

  /// Target of the just-in-time mark on the composer's attach button.
  static final GlobalKey attachKey = GlobalKey();

  /// Target of the mark on the user's own first sent media.
  static final GlobalKey sentMediaKey = GlobalKey();

  /// Target of the mark on the first sealed media the user receives.
  static final GlobalKey sealedKey = GlobalKey();

  /// Whether the composer attach mark has already been shown.
  ///
  /// Read by the 1:1 composer so it only builds the mark while it is still
  /// wanted — see the duplicate-key note at that call site.
  static bool get attachMarkSeen => appData.read(kKeyTourAttachSeen) == true;
}

/// Wraps [child] in a coach mark carrying [title] and [description].
///
/// A thin wrapper so the three call sites don't each repeat the styling, and
/// so the mark's look changes in one place.
class TourMark extends StatelessWidget {
  /// Creates a coach mark around [child].
  const TourMark({
    required this.markKey,
    required this.title,
    required this.description,
    required this.child,
    super.key,
  });

  /// The [GlobalKey] identifying this mark in the tour sequence.
  final GlobalKey markKey;

  /// Short heading shown in the tooltip.
  final String title;

  /// One line explaining what the highlighted control does.
  final String description;

  /// The real widget being highlighted.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Must happen before the Showcase below is constructed — see
    // FirstRunTour.ensureRegistered.
    FirstRunTour.ensureRegistered();

    final scheme = Theme.of(context).colorScheme;
    return Showcase(
      key: markKey,
      title: title,
      description: description,
      tooltipBackgroundColor: scheme.surfaceContainerHighest,
      textColor: scheme.onSurface,
      targetPadding: const EdgeInsets.all(4),
      targetBorderRadius: BorderRadius.circular(12),
      // The tour explains; it does not drive. Tapping a highlighted tab
      // mid-tour would navigate away and strand the remaining marks.
      disableDefaultTargetGestures: true,
      child: child,
    );
  }
}
