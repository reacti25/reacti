import 'dart:io';

import 'package:achiar_expert_app/common_widget/custom_button.dart';
import 'package:achiar_expert_app/common_widget/custom_form_field.dart';
import 'package:achiar_expert_app/helpers/loading_helper.dart';
import 'package:achiar_expert_app/helpers/navigation_service.dart';
import 'package:achiar_expert_app/helpers/ui_helpers.dart';
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

class EditGroupScreen extends StatefulWidget {
  final int groupId;
  const EditGroupScreen({super.key, required this.groupId});

  @override
  State<EditGroupScreen> createState() => _EditGroupScreenState();
}

class _EditGroupScreenState extends State<EditGroupScreen> {
  final _groupNameController = TextEditingController();
  final ValueNotifier<XFile?> _groupImage = ValueNotifier(null);
  final _imagePicker = ImagePicker();

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
            editGroupRx
                .editGroup(
                  groupId: widget.groupId,
                  name: _groupNameController.text.trim(),
                  avatar: _groupImage.value,
                )
                .waitingForSucess()
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
