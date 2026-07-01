// features/friends/presentation/find_screen.dart
import 'dart:developer';

import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/constants/text_font_style.dart';
import 'package:reacti_app/gen/colors.gen.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
// Prefixed: permission_handler also exports a `PermissionStatus` enum, which
// would clash with flutter_contacts'. We use it only for a silent status check
// (no OS prompt), so the user can decline before any dialog appears.
import 'package:permission_handler/permission_handler.dart' as ph;

/// A screen that lists the device's phone contacts so the user can invite
/// them to the app.
///
/// Requests the contacts permission, loads contacts in pages as the user
/// scrolls, and renders each contact with an "Invite" action.
class FindScreen extends StatefulWidget {
  /// Creates the contact-finding screen.
  const FindScreen({super.key});

  @override
  State<FindScreen> createState() => _FindScreenState();
}

/// State for [FindScreen]: holds the loaded contacts and drives the lazy,
/// scroll-triggered pagination of the list.
class _FindScreenState extends State<FindScreen> with WidgetsBindingObserver {
  /// Every contact fetched from the device, before pagination.
  List<Contact> _allContacts = [];

  /// The subset of [_allContacts] currently rendered in the list.
  List<Contact> _displayedContacts = [];

  /// Whether the initial contact load is still in progress.
  bool _loading = true;

  /// Whether the contacts permission was refused by the user.
  bool _permissionDenied = false;

  /// Whether contacts permission has been granted and contacts loaded.
  bool _granted = false;

  /// Whether the user previously tapped "Not now" on the priming prompt.
  bool _skipped = false;

  /// Whether a "load more" page fetch is currently running.
  bool _loadingMore = false;

  /// Whether more contacts remain to be paged in.
  bool _hasMoreContacts = true;

  // Pagination variables
  /// Number of contacts revealed per page.
  final int _pageSize = 15; // Number of contacts to load per page

  /// The number of pages already revealed.
  int _currentPage = 0;

  /// Controller used to detect when the list is scrolled near its end.
  final ScrollController _scrollController = ScrollController();

  /// Wires up the scroll listener and decides the initial state.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupScrollController();
    _init();
  }

  /// When the user returns from the iOS Settings page (where they may have just
  /// enabled Contacts), re-check the permission and load the list — otherwise
  /// the screen stays stuck on "Grant Permission".
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_granted) {
      _recheckPermission();
    }
  }

  /// On resume, try to read contacts (ground truth, no prompt). If it succeeds
  /// the user enabled permission in Settings while away, so the list loads.
  Future<void> _recheckPermission() async {
    if (_granted) return;
    await _fetchContacts();
  }

  /// Picks the initial state without ever prompting the OS.
  ///
  /// If contacts permission was already granted, loads the list as before.
  /// Otherwise shows the priming intro (no dialog), so the user can decline.
  /// [_skipped] restores the compact variant for users who skipped earlier.
  Future<void> _init() async {
    _skipped = appData.read(kKeyContactsSkipped) == true;
    final status = await ph.Permission.contacts.status;
    if (status == ph.PermissionStatus.granted) {
      await _fetchContacts();
    } else if (mounted) {
      setState(() => _loading = false);
    }
  }

  /// Requests contacts permission and loads the list.
  ///
  /// The only place the OS dialog is triggered. iOS shows the contacts dialog
  /// only once — after the user has denied it, `request()` returns immediately
  /// with no dialog. So when permission is permanently denied we send the user
  /// to the app's Settings page (otherwise "Grant Permission" did nothing).
  Future<void> _requestAndLoad() async {
    setState(() => _loading = true);

    // 1) Ground truth first: if permission is already granted (e.g. the user
    //    just enabled it in Settings), this loads with no prompt — and fixes the
    //    "Grant Permission keeps bouncing to Settings even after granting" bug.
    if (await _fetchContacts()) return;

    // 2) Not granted — ask. iOS shows the dialog only once; afterwards request()
    //    returns permanentlyDenied with no dialog, so route to Settings.
    final status = await ph.Permission.contacts.request();
    if (status == ph.PermissionStatus.granted) {
      await _fetchContacts();
      return;
    }
    if (status == ph.PermissionStatus.permanentlyDenied ||
        status == ph.PermissionStatus.restricted) {
      await ph.openAppSettings();
    }
    if (mounted) {
      setState(() {
        _permissionDenied = true;
        _loading = false;
      });
    }
  }

  /// Records that the user declined the contacts prompt for now.
  ///
  /// Persists the skip so later launches don't re-show the full priming copy;
  /// the manual "Find friends" action stays available.
  void _skipContacts() {
    appData.write(kKeyContactsSkipped, true);
    setState(() => _skipped = true);
  }

  /// Attaches a listener that triggers [_loadMoreContacts] once the user
  /// scrolls within 100 logical pixels of the bottom of the list.
  void _setupScrollController() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 100.h) {
        _loadMoreContacts();
      }
    });
  }

  /// Fetches all device contacts (permission already granted) and reveals the
  /// first page.
  ///
  /// On success [_allContacts] is populated and page one is shown via
  /// [_loadFirstPage]. Any error is logged and clears the loading flag so the
  /// UI does not hang. Permission is handled by [_requestAndLoad] / [_init].
  /// Returns `true` when contacts were read (permission is really granted).
  /// `getAll` never prompts — it throws/returns nothing without permission — so
  /// this doubles as the ground-truth permission check after the user returns
  /// from Settings, where the cached permission_handler status can be stale.
  Future<bool> _fetchContacts() async {
    try {
      final contacts = await FlutterContacts.getAll(
        properties: {ContactProperty.name, ContactProperty.phone},
      );

      if (!mounted) return true;
      setState(() {
        _granted = true;
        _permissionDenied = false;
        _allContacts = contacts;
        _loadFirstPage();
        _loading = false;
      });
      return true;
    } catch (e) {
      log('Error loading contacts: $e');
      return false;
    }
  }

  /// Reveals the first [_pageSize] contacts from [_allContacts].
  ///
  /// Also updates [_currentPage] and [_hasMoreContacts] so subsequent
  /// pagination starts from the correct offset.
  void _loadFirstPage() {
    final endIndex =
        _allContacts.length > _pageSize ? _pageSize : _allContacts.length;

    _displayedContacts = _allContacts.sublist(0, endIndex);
    _currentPage = 1;
    _hasMoreContacts = _allContacts.length > _pageSize;
  }

  /// Appends the next page of contacts to [_displayedContacts].
  ///
  /// Returns immediately if a fetch is already running or no contacts remain.
  /// A short artificial delay is used to make the loading indicator visible.
  Future<void> _loadMoreContacts() async {
    if (_loadingMore || !_hasMoreContacts) return;

    setState(() {
      _loadingMore = true;
    });

    // Simulate loading delay for better UX
    await Future.delayed(const Duration(milliseconds: 500));

    final startIndex = _currentPage * _pageSize;
    if (startIndex >= _allContacts.length) {
      setState(() {
        _loadingMore = false;
        _hasMoreContacts = false;
      });
      return;
    }

    final endIndex =
        (startIndex + _pageSize) < _allContacts.length
            ? (startIndex + _pageSize)
            : _allContacts.length;

    final newContacts = _allContacts.sublist(startIndex, endIndex);

    setState(() {
      _displayedContacts.addAll(newContacts);
      _currentPage++;
      _loadingMore = false;
      _hasMoreContacts = endIndex < _allContacts.length;
    });
  }

  /// Resets all pagination state and reloads contacts from scratch.
  ///
  /// Invoked by the pull-to-refresh gesture and the empty/error retry
  /// buttons.
  Future<void> _refreshContacts() async {
    setState(() {
      _loading = true;
      _displayedContacts.clear();
      _currentPage = 0;
      _hasMoreContacts = true;
    });
    _requestAndLoad();
  }

  /// Formats a raw phone [number] for display.
  ///
  /// Strips non-digit characters and, when exactly ten digits remain,
  /// returns a `(XXX) XXX-XXXX` string; otherwise returns the original input.
  String _formatPhoneNumber(String number) {
    final cleaned = number.replaceAll(RegExp(r'\D+'), '');
    if (cleaned.length == 10) {
      return '(${cleaned.substring(0, 3)}) ${cleaned.substring(3, 6)}-${cleaned.substring(6)}';
    }
    return number;
  }

  /// Builds a single list row for [contact] at the given [index].
  ///
  /// Renders an initial-letter avatar, the contact name, a formatted phone
  /// number (or a fallback label), and an "Invite" badge.
  Widget _buildContactItem(Contact contact, int index) {
    final hasPhones = contact.phones.isNotEmpty;

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: ListTile(
        leading: Container(
          width: 40.w,
          height: 40.h,
          decoration: BoxDecoration(
            color: AppColors.allPrimaryColor,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              contact.displayName != null && contact.displayName!.isNotEmpty
                  ? contact.displayName![0].toUpperCase()
                  : '?',
              style: TextFontStyle.headline16w500C333333Poppins,
            ),
          ),
        ),
        title: Text(
          (contact.displayName == null || contact.displayName!.isEmpty)
              ? 'Unknown'
              : contact.displayName!,
          style: TextFontStyle.headline16w500C333333Poppins.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle:
            hasPhones
                ? Text(
                  _formatPhoneNumber(contact.phones.first.number),
                  style: TextFontStyle.headline14w400C666666Poppins,
                )
                : Text(
                  'No phone number',
                  style: TextFontStyle.headline14w400C666666Poppins,
                ),
        trailing: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: AppColors.allPrimaryColor,
            borderRadius: BorderRadius.circular(6.r),
          ),
          child: Text(
            'Invite',
            style: TextFontStyle.headline12w400CDDDDDDPoppins.copyWith(
              color: AppColors.c000000,
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the contacts priming prompt shown before any OS permission ask.
  ///
  /// Offers a primary "Find friends" action (the only trigger for the OS
  /// dialog) and a secondary "Not now". After a skip, only the compact manual
  /// action remains, so the tab stays usable without nagging. Layout is
  /// centered and direction-agnostic, so it reads correctly in RTL.
  Widget _buildContactsIntro() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.contacts_outlined, size: 64.r, color: AppColors.c666666),
            SizedBox(height: 16.h),
            Text(
              'Find friends from your contacts',
              textAlign: TextAlign.center,
              style: TextFontStyle.headline16w500C333333Poppins.copyWith(
                color: AppColors.cFFFFFF,
              ),
            ),
            if (!_skipped) ...[
              SizedBox(height: 8.h),
              Text(
                'See which of your contacts are already on Reacti.',
                textAlign: TextAlign.center,
                style: TextFontStyle.headline14w400C666666Poppins,
              ),
            ],
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: _requestAndLoad,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.allPrimaryColor,
              ),
              child: Text(
                'Find friends',
                style: TextFontStyle.headline14w600C333333Poppins,
              ),
            ),
            if (!_skipped) ...[
              SizedBox(height: 8.h),
              TextButton(
                onPressed: _skipContacts,
                child: Text(
                  'Not now',
                  style: TextFontStyle.headline14w400C666666Poppins,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Builds the spinner shown at the bottom of the list while more contacts
  /// are being paged in.
  Widget _buildLoadingIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      child: Center(
        child: SizedBox(
          width: 24.w,
          height: 24.h,
          child: CircularProgressIndicator(
            strokeWidth: 2.0,
            color: AppColors.allPrimaryColor,
          ),
        ),
      ),
    );
  }

  /// Builds the "No more contacts" footer shown once every contact has been
  /// revealed.
  Widget _buildEndOfListIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      child: Center(
        child: Text(
          'No more contacts',
          style: TextFontStyle.headline14w400C666666Poppins,
        ),
      ),
    );
  }

  /// Renders the screen, switching between the loading spinner, the
  /// permission-denied prompt, the empty-state view, and the paginated
  /// contact list depending on the current state.
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.allPrimaryColor),
      );
    }

    if (_permissionDenied) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.contacts_outlined, size: 64.r, color: AppColors.c666666),
            SizedBox(height: 16.h),
            Text(
              'Contact Permission Required',
              style: TextFontStyle.headline16w500C333333Poppins.copyWith(
                color: AppColors.cFFFFFF,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Please enable contacts permission to find friends',
              style: TextFontStyle.headline14w400C666666Poppins,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: _requestAndLoad,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.allPrimaryColor,
              ),
              child: Text(
                'Grant Permission',
                style: TextFontStyle.headline14w600C333333Poppins,
              ),
            ),
          ],
        ),
      );
    }

    if (!_granted) {
      return _buildContactsIntro();
    }

    if (_allContacts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refreshContacts,
        color: AppColors.allPrimaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.contacts_outlined,
                    size: 64.r,
                    color: AppColors.c666666,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'No Contacts Found',
                    style: TextFontStyle.headline16w500C333333Poppins.copyWith(
                      color: AppColors.cFFFFFF,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Your device contacts will appear here',
                    style: TextFontStyle.headline14w400C666666Poppins,
                  ),
                  SizedBox(height: 16.h),
                  ElevatedButton(
                    onPressed: _refreshContacts,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.allPrimaryColor,
                    ),
                    child: Text(
                      'Refresh',
                      style: TextFontStyle.headline14w600C333333Poppins,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshContacts,
      color: AppColors.allPrimaryColor,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _displayedContacts.length + 1, // +1 for loading indicator
        itemBuilder: (context, index) {
          if (index == _displayedContacts.length) {
            if (_loadingMore) {
              return _buildLoadingIndicator();
            } else if (_hasMoreContacts) {
              return _buildLoadingIndicator(); // Show loading when approaching end
            } else {
              return _buildEndOfListIndicator();
            }
          }
          return _buildContactItem(_displayedContacts[index], index);
        },
      ),
    );
  }

  /// Releases the [_scrollController] when the screen is removed.
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }
}
