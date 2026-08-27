import 'package:flutter/material.dart';
import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/features/chat/model/chat_list_response.dart';
import 'package:reacti_app/features/navigation/presentation/navigation_screen.dart';
import 'package:reacti_app/features/tour/tour_recap_sheet.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:reacti_app/helpers/navigation_service.dart';
import 'package:reacti_app/networks/api_access.dart';
import 'package:showcaseview/showcaseview.dart';

/// The one-time "how to use Reacti" tour: a card explaining what a Reacti is,
/// then three coach marks over the real home screen
/// (docs/PLAN-onboarding-walkthrough-2026-08-15.md).
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

  /// Target of the home tour's only mark — the Friends tab.
  ///
  /// Shown only to an account with nobody to send to. Jonjon, 2026-08-17: the
  /// Chat-tab mark ("Your chats") explained a label that explains itself, and
  /// the "+" mark sold groups to someone who has not sent their first Reacti
  /// yet. Both are gone; what is left is the one step that unblocks sending.
  static final GlobalKey friendsTabKey = GlobalKey();

  /// Target of the mark on the first chat row.
  ///
  /// The other half of "Send my first Reacti": someone who already has friends
  /// gets no Friends mark, and used to be dropped on the chat list with the
  /// button's promise unkept and no idea the walkthrough was still running.
  static final GlobalKey firstChatKey = GlobalKey();

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
    appData.remove(kKeyTourFirstChatSeen);
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
  /// [eligible] is consulted only while the mark is unclaimed, so an owner
  /// keeps it after whatever qualified it stops holding — the sent-media tip
  /// qualifies on "still uploading", which stops being true seconds later.
  ///
  /// ponytail: a map, not a per-mark owner class. There are three marks.
  static bool claimMark(
    String storageKey,
    int messageId, {
    bool eligible = true,
  }) {
    final owner = _markOwners[storageKey];
    if (owner != null) return owner == messageId;
    if (!eligible) return false;
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

  /// Runs the walkthrough: the "How a Reacti works" card, then whichever tab
  /// this account's next step is actually on.
  ///
  /// Auto-run passes [force] `false`, so it is a no-op once [seen]. The
  /// Profile replay row passes `true` — without a way back in, the tour can
  /// only ever be examined on a fresh install, which is exactly the problem
  /// the demo hit before it got its own replay row.
  static Future<void> start({bool force = false}) async {
    if (!force && seen) return;
    _ensureRegistered();
    // Marked seen on START, not on finish. All sequences share one registered
    // controller, so a completion callback could not tell which sequence had
    // ended — a just-in-time mark finishing would have marked the home tour
    // seen. Marking here also means a user who force-quits mid-tour isn't
    // shown it again, which is the kinder failure.
    markSeen();

    // The mechanic first, the geography second. Marks can only say "this
    // button is here"; they cannot say what the app is for, because saying
    // that needs a sealed message and a reaction, and the account being walked
    // through has neither. Awaiting the sheet keeps the two from overlapping.
    final context = NavigationService.navigatorKey.currentContext;
    if (context != null) await showTourRecapSheet(context);

    // Land on the tab where this account's next step actually IS, rather than
    // dropping everyone on the chat list and pointing at a tab to go press.
    //
    // Someone with no chats was left staring at "No chats found" with a mark
    // on the Friends button — the walkthrough telling them to navigate instead
    // of taking them there. Both the states that need Friends go to Friends;
    // the marks waiting on the other side (the empty state's own buttons, or
    // "Open a chat" on the first friend row) carry it from there.
    if (!await _hasChats()) {
      final goToTab = NavigationScreen.goToTab;
      if (goToTab == null) {
        // No shell mounted to switch — point at the tab instead of ending the
        // walkthrough on nothing.
        ShowcaseView.get().startShowCase([friendsTabKey]);
        return;
      }
      goToTab(_friendsTabIndex);
      // Nothing more to show here: the Friends tab explains itself. With no
      // friends its empty state offers contacts and username search; with
      // friends, the first row carries "Open a chat". A mark pointing at the
      // tab you are already on would be noise.
      return;
    }

    // Has chats, so the chat list is the right place — its first row carries
    // "Pick someone" and fires on its own.
  }

  /// Index of the Friends tab in the bottom bar.
  ///
  /// ponytail: a named constant, not an enum. There are four tabs and they
  /// have not moved since the app shipped.
  static const int _friendsTabIndex = 1;

  /// Whether this account has any conversation at all.
  ///
  /// Fetched rather than inferred: the walkthrough can run before the chat list
  /// has loaded, and "not loaded yet" and "none" look identical from here. A
  /// failed fetch answers `false`, which routes to Friends — the friendlier way
  /// to be wrong, since that tab explains itself either way.
  static Future<bool> _hasChats() async {
    try {
      await getAllChatRx.getAllChat();
      final response = getAllChatRx.getChatStream.valueOrNull;
      final chats = response is ChatListResponse ? response.data?.chats : null;
      return chats != null && chats.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Shows a single mark, once ever, and records that it has been shown.
  ///
  /// [storageKey] is the one-time flag; [markKey] the target.
  ///
  /// Deciding whether the target is on screen is the *caller's* job, and in
  /// practice that means [TourMark] — which is the only thing that can tell.
  /// This used to check `markKey.currentContext` here, which looked right and
  /// was silently always false: showcaseview's `Showcase` keeps the key as its
  /// `showcaseKey` and never passes it to `super`, so the key is attached to
  /// no element and has no context. The guard rejected every call, and the
  /// contextual tips never fired once, in any build.
  static void showOnce({
    required GlobalKey markKey,
    required String storageKey,
  }) {
    if (appData.read(storageKey) == true) return;

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

  /// Target of the mark on the first row of the Friends list.
  ///
  /// The other way into a first chat, and the only one a brand-new account
  /// has. A 1:1 row appears in the CHAT list only once messages have been
  /// exchanged, so someone who has just added their first friend still sees an
  /// empty Chat tab — the "Pick someone" mark there has nothing to point at and
  /// never fires. Tapping a friend is how that first conversation starts.
  ///
  /// Shares [kKeyTourFirstChatSeen] with the chat-row mark: they teach the same
  /// step by two routes, so whichever the user reaches first spends it. Separate
  /// GlobalKeys, though — one key on two widgets is a crash if both ever mount.
  static final GlobalKey friendRowKey = GlobalKey();

  /// Whether the composer attach mark has already been shown.
  ///
  /// Read by the 1:1 composer so it only builds the mark while it is still
  /// wanted — see the duplicate-key note at that call site.
  static bool get attachMarkSeen => appData.read(kKeyTourAttachSeen) == true;
}

/// Wraps [child] in a coach mark carrying [title] and [description].
///
/// A thin wrapper so the call sites don't each repeat the styling, and so the
/// mark's look changes in one place.
class TourMark extends StatefulWidget {
  /// Creates a coach mark around [child].
  const TourMark({
    required this.markKey,
    required this.title,
    required this.description,
    required this.child,
    this.showOnceKey,
    this.tooltipPosition,
    super.key,
  });

  /// Forces the tooltip above or below the target instead of letting
  /// showcaseview pick whichever side has room.
  ///
  /// Only worth setting when the side carries meaning — the sent-media tip
  /// points down into the gap the reaction will arrive in.
  final TooltipPosition? tooltipPosition;

  /// GetStorage flag gating a mark that shows itself, once, as soon as it is
  /// built.
  ///
  /// Screens used to fire their own tips from `initState`, and it did not
  /// work: a chat opens on a loading skeleton and the Contacts tab opens
  /// before the contacts load, so at that first frame the button the tip
  /// points at does not exist yet. [FirstRunTour.showOnce] correctly declined
  /// to burn the flag — and nothing ever asked again, so the tip never
  /// appeared at all. Firing from the mark itself means it fires exactly when
  /// its target is on screen, which is the only moment it could ever work.
  final String? showOnceKey;

  /// The [GlobalKey] identifying this mark in the tour sequence.
  final GlobalKey markKey;

  /// Short heading shown in the tooltip.
  final String title;

  /// One line explaining what the highlighted control does.
  final String description;

  /// The real widget being highlighted.
  final Widget child;

  @override
  State<TourMark> createState() => _TourMarkState();
}

/// Holds the one-shot post-frame trigger for a [TourMark.showOnceKey] mark.
class _TourMarkState extends State<TourMark> {
  @override
  void initState() {
    super.initState();
    if (widget.showOnceKey != null) _fireWhenVisible();
  }

  /// Fires the one-shot tip on the first frame where this mark is genuinely on
  /// screen, re-arming until then.
  ///
  /// Waiting is not optional. The Contacts tab is the second page of a
  /// `TabBarView`, so it is built — and its `initState` runs — while it is
  /// still parked off to the side; firing there would spend the tip on a frame
  /// nobody saw. And a chat opens on a loading skeleton, so the button the tip
  /// points at does not exist on frame one at all.
  ///
  /// ponytail: re-arms per frame rather than listening to a scroll position.
  /// It is one rect test, only on frames that were being produced anyway, and
  /// it stops the moment it fires or the mark is disposed. Swap it for a
  /// visibility listener if it ever shows up in a frame profile.
  void _fireWhenVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final storageKey = widget.showOnceKey;
      if (storageKey == null || appData.read(storageKey) == true) return;

      if (!_isOnScreen()) {
        _fireWhenVisible();
        return;
      }

      FirstRunTour.showOnce(markKey: widget.markKey, storageKey: storageKey);
    });
  }

  /// Whether this mark's box currently overlaps the visible window, on a route
  /// nothing is covering.
  bool _isOnScreen() {
    // A tip that starts while the "How a Reacti works" card is open draws its
    // overlay *under* the card: invisible, and the flag spent. The chat list
    // sits right behind that card, so this is the normal case, not an edge one.
    if (ModalRoute.of(context)?.isCurrent == false) return false;

    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;

    final origin = box.localToGlobal(Offset.zero);
    final screen = MediaQuery.sizeOf(context);
    return origin.dx + box.size.width > 0 &&
        origin.dy + box.size.height > 0 &&
        origin.dx < screen.width &&
        origin.dy < screen.height;
  }

  @override
  Widget build(BuildContext context) {
    // Must happen before the Showcase below is constructed — see
    // FirstRunTour.ensureRegistered.
    FirstRunTour.ensureRegistered();

    final scheme = Theme.of(context).colorScheme;
    return Showcase(
      key: widget.markKey,
      title: widget.title,
      description: widget.description,
      tooltipPosition: widget.tooltipPosition,
      tooltipBackgroundColor: scheme.surfaceContainerHighest,
      textColor: scheme.onSurface,
      targetPadding: const EdgeInsets.all(4),
      targetBorderRadius: BorderRadius.circular(12),
      // The tour explains; it does not drive. Tapping a highlighted tab
      // mid-tour would navigate away and strand the remaining marks.
      disableDefaultTargetGestures: true,
      child: widget.child,
    );
  }
}
