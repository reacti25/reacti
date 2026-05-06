// features/friends/presentation/find_screen.dart
import 'dart:developer';

import 'package:achiar_expert_app/constants/text_font_style.dart';
import 'package:achiar_expert_app/gen/colors.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class FindScreen extends StatefulWidget {
  const FindScreen({super.key});

  @override
  State<FindScreen> createState() => _FindScreenState();
}

class _FindScreenState extends State<FindScreen> {
  List<Contact> _allContacts = [];
  List<Contact> _displayedContacts = [];
  bool _loading = true;
  bool _permissionDenied = false;
  bool _loadingMore = false;
  bool _hasMoreContacts = true;

  // Pagination variables
  final int _pageSize = 15; // Number of contacts to load per page
  int _currentPage = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _setupScrollController();
  }

  void _setupScrollController() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 100.h) {
        _loadMoreContacts();
      }
    });
  }

  Future<void> _loadContacts() async {
    try {
      // Check and request permission
      final status = await FlutterContacts.permissions.request(PermissionType.readWrite);
      if (status != PermissionStatus.granted) {
        setState(() {
          _permissionDenied = true;
          _loading = false;
        });
        return;
      }

      final contacts = await FlutterContacts.getAll(
        properties: {ContactProperty.name, ContactProperty.phone},
      );

      setState(() {
        _allContacts = contacts;
        _loadFirstPage();
        _loading = false;
      });
    } catch (e) {
      log('Error loading contacts: $e');
      setState(() {
        _loading = false;
      });
    }
  }

  void _loadFirstPage() {
    final endIndex =
        _allContacts.length > _pageSize ? _pageSize : _allContacts.length;

    _displayedContacts = _allContacts.sublist(0, endIndex);
    _currentPage = 1;
    _hasMoreContacts = _allContacts.length > _pageSize;
  }

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

  Future<void> _refreshContacts() async {
    setState(() {
      _loading = true;
      _displayedContacts.clear();
      _currentPage = 0;
      _hasMoreContacts = true;
    });
    _loadContacts();
  }

  String _formatPhoneNumber(String number) {
    final cleaned = number.replaceAll(RegExp(r'\D+'), '');
    if (cleaned.length == 10) {
      return '(${cleaned.substring(0, 3)}) ${cleaned.substring(3, 6)}-${cleaned.substring(6)}';
    }
    return number;
  }

  Widget _buildContactItem(Contact contact, int index) {
    final hasPhones = contact.phones.isNotEmpty;

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: AppColors.c252529,
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
            color: AppColors.cFFFFFF,
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
              onPressed: _loadContacts,
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
