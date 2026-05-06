import 'dart:developer';
import 'dart:io';

import 'package:achiar_expert_app/common_widget/custom_button.dart';
import 'package:achiar_expert_app/common_widget/custom_form_field.dart';
import 'package:achiar_expert_app/constants/text_font_style.dart';
import 'package:achiar_expert_app/features/profile/model/profile_response.dart';
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

import '../../../common_widget/custom_network_image.dart';
import '../../../gen/colors.gen.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _userNameController = TextEditingController();
  final _fNameController = TextEditingController();
  final _lNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  final ValueNotifier<XFile?> _profileImage = ValueNotifier(null);
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickProfileImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      _profileImage.value = image;
    }
  }

  @override
  void dispose() {
    _userNameController.dispose();
    _fNameController.dispose();
    _lNameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit Profile',
          style: TextFontStyle.headline16w500CF7F7F7Poppins,
        ),
      ),
      body: StreamBuilder(
        stream: getProfileRx.getProfileStream,
        builder: (context, asyncSnapshot) {
          if (asyncSnapshot.connectionState == ConnectionState.waiting) {
            return CircularProgressIndicator();
          } else if (asyncSnapshot.hasData) {
            ProfileResponse response = asyncSnapshot.data;
            final data = response.data;

            _userNameController.text = data?.username ?? "";
            _fNameController.text = data?.firstName ?? "";
            _lNameController.text = data?.lastName ?? "";
            _phoneController.text = data?.phone ?? "";
            _emailController.text = data?.email ?? "";
            _bioController.text = data?.bio ?? "";
            return SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UIHelper.verticalSpace(16.h),
                  _imagePickerSection(data),
                  UIHelper.verticalSpace(20.h),
            
                  Text(
                    "Username",
                    style: TextFontStyle.headline16w500CFFFFFFPoppins,
                  ),
                  UIHelper.verticalSpace(8.h),
            
                  CustomFormField(
                    hintText: data?.username ?? "",
                    fillColor: AppColors.c161618,
                    controller: _userNameController,
                    isRead: true,
                  ),
                  UIHelper.verticalSpace(20.h),
            
                  Text(
                    "First Name",
                    style: TextFontStyle.headline16w500CFFFFFFPoppins,
                  ),
                  UIHelper.verticalSpace(8.h),
            
                  CustomFormField(
                    hintText: "Enter your full name",
                    fillColor: AppColors.c161618,
                    controller: _fNameController,
                  ),
            
                  UIHelper.verticalSpace(20.h),
            
                  Text(
                    "Last Name",
                    style: TextFontStyle.headline16w500CFFFFFFPoppins,
                  ),
                  UIHelper.verticalSpace(8.h),
            
                  CustomFormField(
                    hintText: "Enter your full name",
                    fillColor: AppColors.c161618,
                    controller: _lNameController,
                  ),
                  UIHelper.verticalSpace(20.h),
            
                  Text(
                    "Phone Number",
                    style: TextFontStyle.headline16w500CFFFFFFPoppins,
                  ),
                  UIHelper.verticalSpace(8.h),
            
                  CustomFormField(
                    hintText: "Enter your phone number",
                    fillColor: AppColors.c161618,
                    controller: _phoneController,
                    inputType: TextInputType.phone,
                  ),
                  UIHelper.verticalSpace(20.h),
                  Text(
                    "Email",
                    style: TextFontStyle.headline16w500CFFFFFFPoppins,
                  ),
                  UIHelper.verticalSpace(8.h),
            
                  CustomFormField(
                    hintText: "Enter your email",
                    fillColor: AppColors.c161618,
                    controller: _emailController,
                    inputType: TextInputType.phone,
                    isRead: true,
                  ),
                  UIHelper.verticalSpace(20.h),
            
                  Text(
                    "Bio",
                    style: TextFontStyle.headline16w500CFFFFFFPoppins,
                  ),
                  UIHelper.verticalSpace(8.h),
            
                  CustomFormField(
                    hintText: "Write a short bio",
                    fillColor: AppColors.c161618,
                    controller: _bioController,
                    maxline: 4,
                    minLine: 3,
                    textInputAction: TextInputAction.newline,
                  ),
            
                  UIHelper.verticalSpace(40.h),
                  CustomButton(
                    onTap: () {
                      editProfileRx
                          .userEditProfile(
                            fName: _fNameController.text.trim(),
                            lName: _lNameController.text.trim(),
                            phone: _phoneController.text.trim(),
                            bio: _bioController.text.trim(),
                            avatar: _profileImage.value,
                          )
                          .waitingForSucess()
                          .then((success) {
                            if (success) {
                              ToastUtil.showSuccessMessage(
                                "Profile updated successfully",
                              );
                              getProfileRx.getProfile();
                              NavigationService.goBack;
                            }
                          });
                    },
                    btnName: "Update Profile",
                  ),
                  UIHelper.verticalSpace(30.h),
                ],
              ),
            );
          } else {
            return SizedBox.shrink();
          }
        },
      ),
    );
  }

  Widget _imagePickerSection(Data? data) {
    return Center(
      child: Stack(
        children: [
          ValueListenableBuilder(
            valueListenable: _profileImage,
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
                          ? data?.avatar != null
                              ? CustomNetworkImage(
                                height: 90.h,
                                width: 90.w,
                                urls: data?.avatar ?? "",
                              )
                              : Image.asset(
                                Assets.images.noImage.path,
                                height: 90.h,
                                width: 90.w,
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
                log("Click");
                _pickProfileImage();
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
    );
  }
}
