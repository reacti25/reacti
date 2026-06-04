import 'dart:io';

import 'package:reacti_app/common_widget/custom_button.dart';
import 'package:reacti_app/common_widget/custom_form_field.dart';
import 'package:reacti_app/helpers/loading_helper.dart';
import 'package:reacti_app/helpers/navigation_service.dart';
import 'package:reacti_app/helpers/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_picker/image_picker.dart';

import '../../../common_widget/custom_network_image.dart';
import '../../../constants/text_font_style.dart';
import '../../../gen/assets.gen.dart';
import '../../../gen/colors.gen.dart';
import '../../../networks/api_access.dart';
import '../../group_details/model/group_details_response.dart';

/// Screen for editing an existing group's name and avatar.
///
/// Pre-fills the form from the group-details stream and submits the changes
/// through [editGroupRx], refreshing the group on success.
class EditGroupScreen extends StatefulWidget {
  /// Identifier of the group being edited.
  final int groupId;

  /// Creates an [EditGroupScreen] for the group [groupId].
  const EditGroupScreen({super.key, required this.groupId});

  @override
  State<EditGroupScreen> createState() => _EditGroupScreenState();
}

/// State for [EditGroupScreen]; owns the form controllers and image picker.
class _EditGroupScreenState extends State<EditGroupScreen> {
  /// Controller bound to the group-name text field.
  final _groupNameController = TextEditingController();

  /// Holds the avatar picked by the user, or `null` to keep the current one.
  final ValueNotifier<XFile?> _groupImage = ValueNotifier(null);

  /// Gallery image picker used to choose a new group avatar.
  final _imagePicker = ImagePicker();

  /// Opens the gallery and stores the chosen image in [_groupImage].
  ///
  /// A cancelled pick leaves [_groupImage] unchanged.
  Future<void> _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
    );
    if (image != null) {
      _groupImage.value = image;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit Group',
          style: TextFontStyle.headline16w500CF7F7F7Poppins,
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: StreamBuilder(
            stream: groupDetailsRx.getGroupDetailsStream,
            builder: (context, asyncSnapshot) {
              if (asyncSnapshot.connectionState == ConnectionState.waiting) {
                return CircularProgressIndicator();
              } else if (asyncSnapshot.hasData) {
                GroupDetailsResponse response = asyncSnapshot.data;
                final group = response.data?.group;
                // Seed the name field with the group's current name.
                _groupNameController.text = group?.name ?? "";
                return Column(
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          ValueListenableBuilder(
                            valueListenable: _groupImage,
                            builder: (context, imageFile, child) {
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
                                            urls: group?.avatar ?? "",
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
                            child: GestureDetector(
                              onTap: () {
                                _pickImage();
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
                    ),
                    UIHelper.verticalSpace(20.h),
                    CustomFormField(
                      controller: _groupNameController,
                      hintText: "Group Name",
                    ),
                    UIHelper.verticalSpace(16.h),
                  ],
                );
              } else {
                return SizedBox.shrink();
              }
            },
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 20.h),
        child: CustomButton(
          onTap: () {
            // Submit the edit, then refresh group details and pop back to
            // the previous screen once the update succeeds.
            editGroupRx
                .editGroup(
                  groupId: widget.groupId,
                  name: _groupNameController.text.trim(),
                  avatar: _groupImage.value,
                )
                .waitingForSuccess()
                .then((success) {
                  if (success) {
                    groupDetailsRx.getGroupDetails(id: widget.groupId);
                    NavigationService.goBack;
                  }
                });
          },
          btnName: "Update",
        ),
      ),
    );
  }
}
