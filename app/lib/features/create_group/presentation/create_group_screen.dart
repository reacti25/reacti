import 'dart:io';

import 'package:achiar_expert_app/common_widget/custom_form_field.dart';
import 'package:achiar_expert_app/common_widget/custom_network_image.dart';
import 'package:achiar_expert_app/features/friends/model/friend_list_response.dart';
import 'package:achiar_expert_app/gen/assets.gen.dart';
import 'package:achiar_expert_app/helpers/loading_helper.dart';
import 'package:achiar_expert_app/helpers/navigation_service.dart';
import 'package:achiar_expert_app/helpers/toast.dart';
import 'package:achiar_expert_app/helpers/ui_helpers.dart';
import 'package:achiar_expert_app/networks/api_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_picker/image_picker.dart';

import '../../../constants/text_font_style.dart';
import '../../../gen/colors.gen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  // final _formKey = GlobalKey<FormState>();
  final _groupNameController = TextEditingController();

  // final _searchController = TextEditingController();
  // final _searchFocusNode = FocusNode();
  // final bool _isSearching = false;

  List<Datum> selectedContacts = [];

  final ValueNotifier<XFile?> _groupImage = ValueNotifier(null);
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickGroupImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      _groupImage.value = image;
    }
  }

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
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
          style: TextFontStyle.headline16w500CFFFFFFPoppins,
        ),
        actions: [
          IconButton(
            onPressed: () {
              if (selectedContacts.isEmpty) {
                ToastUtil.showErrorMessage(
                  "Please select at least one contact",
                );
                return;
              }
              if (!_formKey.currentState!.validate()) {
                return;
              }
              createGroupRx
                  .createGroup(
                    name: _groupNameController.text.trim(),
                    memberIds: selectedContacts.map((e) => e.id).toList(),
                    avatar: _groupImage.value,
                  )
                  .waitingForSucess()
                  .then((success) {
                    if (success) {
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
                                  .copyWith(fontSize: 12.sp),
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
                              color: AppColors.c161618,
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
                                          color: AppColors.cFFFFFF,
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

class ContactListTile extends StatelessWidget {
  final String imageUrl;
  final String userName;
  final String name;
  final double? leftPadding;
  final VoidCallback? onTap;

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
                Text(name, style: TextFontStyle.headline12w400CFFFFFFPoppins),
                UIHelper.verticalSpace(4.h),
                Text(
                  userName,
                  style: TextFontStyle.headline12w400CFFFFFFPoppins,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class Friend {
  final String? firstName;
  final String? lastName;
  final String? cover;
  final DateTime? lastActivityAt;

  Friend({this.firstName, this.lastName, this.cover, this.lastActivityAt});
}
