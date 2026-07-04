import 'dart:io';

import 'package:reacti_app/common_widget/custom_form_field.dart';
import 'package:reacti_app/common_widget/custom_network_image.dart';
import 'package:reacti_app/features/friends/model/friend_list_response.dart';
import 'package:reacti_app/gen/assets.gen.dart';
import 'package:reacti_app/helpers/loading_helper.dart';
import 'package:reacti_app/helpers/navigation_service.dart';
import 'package:reacti_app/helpers/toast.dart';
import 'package:reacti_app/helpers/ui_helpers.dart';
import 'package:reacti_app/networks/api_access.dart';
import 'package:reacti_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_picker/image_picker.dart';

import '../../../constants/text_font_style.dart';
import '../../../gen/colors.gen.dart';

/// Screen for creating a new group from the user's friend list.
///
/// Lets the user pick an avatar, enter a name, select members from their
/// friends and submit the group through [createGroupRx].
class CreateGroupScreen extends StatefulWidget {
  /// Creates a [CreateGroupScreen].
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

/// State for [CreateGroupScreen]; owns the form, selection and image state.
class _CreateGroupScreenState extends State<CreateGroupScreen> {
  // final _formKey = GlobalKey<FormState>();
  /// Controller bound to the group-name text field.
  final _groupNameController = TextEditingController();

  // final _searchController = TextEditingController();
  // final _searchFocusNode = FocusNode();
  // final bool _isSearching = false;

  /// Friends currently selected to become members of the new group.
  List<Datum> selectedContacts = [];

  /// Holds the avatar picked by the user, or `null` when none is chosen.
  final ValueNotifier<XFile?> _groupImage = ValueNotifier(null);

  /// Gallery image picker used to choose the group avatar.
  final ImagePicker _picker = ImagePicker();

  /// Opens the gallery and stores the chosen image in [_groupImage].
  ///
  /// A cancelled pick leaves [_groupImage] unchanged.
  Future<void> _pickGroupImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      _groupImage.value = image;
    }
  }

  /// Form key used to validate the group-name field before submission.
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    // Load the friend list so it can populate the member picker.
    getFriendListRx.getFriendList();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Create Group',
          style: TextFontStyle.headline16w500CFFFFFFPoppins.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              // A group needs at least one member besides the creator.
              if (selectedContacts.isEmpty) {
                ToastUtil.showErrorMessage(
                  "Please select at least one contact",
                );
                return;
              }
              // Abort if the group name fails form validation.
              if (!_formKey.currentState!.validate()) {
                return;
              }
              // Submit the new group and pop back on success.
              createGroupRx
                  .createGroup(
                    name: _groupNameController.text.trim(),
                    memberIds: selectedContacts.map((e) => e.id).toList(),
                    avatar: _groupImage.value,
                  )
                  .waitingForSuccess()
                  .then((success) {
                    if (success) {
                      // Refresh the chat list so the new group shows up
                      // immediately instead of only after a restart/realtime
                      // event (the chat screen's initState won't re-run on pop).
                      getAllChatRx.getAllChat();
                      NavigationService.goBack;
                    }
                  });
            },
            icon: Icon(Icons.done),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              UIHelper.verticalSpace(16.h),
              Row(
                spacing: 14.w,
                children: [
                  Stack(
                    children: [
                      ValueListenableBuilder(
                        valueListenable: _groupImage,
                        builder: (context, imageFile, _) {
                          return Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.allPrimaryColor,
                                width: 2.sp,
                              ),
                            ),
                            child: ClipOval(
                              child:
                                  imageFile == null
                                      ? CustomNetworkImage(
                                        height: 90.h,
                                        width: 90.w,
                                        urls:
                                            "https://upload.wikimedia.org/wikipedia/commons/thumb/6/65/No-Image-Placeholder.svg/1665px-No-Image-Placeholder.svg.png",
                                      )
                                      : Image.file(
                                        File(imageFile.path),
                                        height: 90.h,
                                        width: 90.w,
                                        fit: BoxFit.cover,
                                      ),
                            ),
                          );
                        },
                      ),

                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: InkWell(
                          onTap: () {
                            _pickGroupImage();
                          },
                          child: Container(
                            padding: EdgeInsets.all(6.sp),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.allPrimaryColor,
                            ),
                            child: SvgPicture.asset(
                              Assets.icons.cameraIcon,
                              height: 16.h,
                              width: 16.w,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: CustomFormField(
                      controller: _groupNameController,
                      hintText: "Group Name",
                      textInputAction: TextInputAction.done,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter group name';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              UIHelper.verticalSpace(16.h),
              if (selectedContacts.isNotEmpty)
                Container(
                  alignment: Alignment.centerLeft,
                  height: 80.h,
                  child: ListView.builder(
                    shrinkWrap: true,
                    scrollDirection: Axis.horizontal,
                    itemCount: selectedContacts.length,
                    itemBuilder: (context, index) {
                      final contact = selectedContacts[index];
                      return Padding(
                        padding: EdgeInsets.only(right: 18.w),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ClipOval(
                                  child: CustomNetworkImage(
                                    urls: contact.avatar ?? "",
                                    // noImageUrl: Assets.images.userImage.path,
                                    height: 40.h,
                                    width: 40.w,
                                  ),
                                ),
                                Positioned(
                                  right: -5.w,
                                  top: -2.h,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        selectedContacts.removeAt(index);
                                      });
                                    },
                                    child: Container(
                                      padding: EdgeInsets.all(2.sp),
                                      decoration: BoxDecoration(
                                        color: AppColors.cFFFFFF,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.15,
                                            ),
                                            blurRadius: 6.sp,
                                            spreadRadius: 1.sp,
                                            offset: Offset(2.sp, 2.sp),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 14.sp,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            UIHelper.verticalSpace(4.h),
                            Text(
                              "${contact.name}",
                              style: TextFontStyle.headline16w400CFFFFFFPoppins
                                  .copyWith(
                                    fontSize: 12.sp,
                                    color: context.reacti.textPrimary,
                                  ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              UIHelper.verticalSpace(8.h),
              Divider(color: AppColors.cFFFFFF.withValues(alpha: 0.5)),
              UIHelper.verticalSpace(16.h),
              StreamBuilder(
                stream: getFriendListRx.getFriendListStream,
                builder: (context, asyncSnapshot) {
                  if (asyncSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: AppColors.allPrimaryColor,
                      ),
                    );
                  } else if (asyncSnapshot.hasData) {
                    FriendListResponse response = asyncSnapshot.data!;

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      // itemCount: allContacts.length,
                      itemCount: response.data?.length,
                      itemBuilder: (context, index) {
                        final data = response.data?[index];

                        // final user = response.data?[index];
                        return InkWell(
                          highlightColor: Colors.transparent,
                          splashColor: Colors.transparent,
                          onTap: () {
                            // Toggle the friend in or out of the selection.
                            setState(() {
                              if (selectedContacts.contains(data)) {
                                selectedContacts.remove(data);
                              } else {
                                selectedContacts.add(data!);
                              }
                            });
                          },
                          child: Container(
                            margin: EdgeInsets.only(bottom: 16.h),
                            padding: EdgeInsets.symmetric(vertical: 8.h),
                            decoration: BoxDecoration(
                              // Light: a white row card on the canvas; dark:
                              // the original slab (unchanged).
                              color:
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppColors.c161618
                                      : context.reacti.card,
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Column(
                              children: [
                                Stack(
                                  alignment: Alignment.centerRight,
                                  children: [
                                    ContactListTile(
                                      imageUrl: data?.avatar ?? "",
                                      userName: "${data?.username}",
                                      name: data?.name ?? "",
                                    ),
                                    if (selectedContacts.contains(data))
                                      Padding(
                                        padding: EdgeInsets.only(right: 16.w),
                                        child: Icon(
                                          Icons.check_box,
                                          color:
                                              Theme.of(context).brightness ==
                                                      Brightness.dark
                                                  ? AppColors.cFFFFFF
                                                  : context.reacti.brandAccent,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  } else {
                    return SizedBox.shrink();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Row widget showing a single contact's avatar, name and username.
///
/// Used inside the create-group friend list to render each selectable friend.
class ContactListTile extends StatelessWidget {
  /// URL of the contact's avatar image.
  final String imageUrl;

  /// The contact's username, shown beneath the name.
  final String userName;

  /// The contact's display name.
  final String name;

  /// Optional left padding; defaults to `10.w` when omitted.
  final double? leftPadding;

  /// Optional tap callback invoked when the tile is pressed.
  final VoidCallback? onTap;

  /// Creates a [ContactListTile] for a single contact.
  const ContactListTile({
    super.key,
    required this.imageUrl,
    required this.userName,
    this.leftPadding,
    this.onTap,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: leftPadding ?? 10.w),
      child: InkWell(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onTap: onTap,
        child: Row(
          children: [
            ClipOval(
              child: CustomNetworkImage(
                width: 34.w,
                height: 34.h,
                urls: imageUrl,
                // noImageUrl: Assets.images.userImage.path,
              ),
            ),
            UIHelper.horizontalSpace(8.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextFontStyle.headline12w400CFFFFFFPoppins.copyWith(
                    color: context.reacti.textPrimary,
                  ),
                ),
                UIHelper.verticalSpace(4.h),
                Text(
                  userName,
                  style: TextFontStyle.headline12w400CFFFFFFPoppins.copyWith(
                    color: context.reacti.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Lightweight friend model holding a contact's basic profile fields.
class Friend {
  /// Friend's first name.
  final String? firstName;

  /// Friend's last name.
  final String? lastName;

  /// URL of the friend's cover image.
  final String? cover;

  /// Timestamp of the friend's last recorded activity.
  final DateTime? lastActivityAt;

  /// Creates a [Friend] from optional named fields.
  Friend({this.firstName, this.lastName, this.cover, this.lastActivityAt});
}
