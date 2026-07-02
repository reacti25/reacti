import 'dart:developer';
import 'dart:io';

import 'package:reacti_app/common_widget/custom_button.dart';
import 'package:reacti_app/common_widget/custom_form_field.dart';
import 'package:reacti_app/constants/text_font_style.dart';
import 'package:reacti_app/features/profile/model/profile_response.dart';
import 'package:reacti_app/gen/assets.gen.dart';
import 'package:reacti_app/helpers/loading_helper.dart';
import 'package:reacti_app/helpers/navigation_service.dart';
import 'package:reacti_app/helpers/toast.dart';
import 'package:reacti_app/helpers/ui_helpers.dart';
import 'package:reacti_app/networks/api_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_picker/image_picker.dart';

import '../../../common_widget/custom_network_image.dart';
import '../../../gen/colors.gen.dart';
import '../../../theme/app_theme.dart';

/// Screen that lets the user edit their own profile.
///
/// Pre-fills form fields from the cached profile stream, lets the user pick a
/// new avatar from the gallery, and submits the changes through
/// `editProfileRx`.
class EditProfileScreen extends StatefulWidget {
  /// Creates the edit-profile screen.
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

/// State for [EditProfileScreen]; owns the form controllers and avatar pick.
class _EditProfileScreenState extends State<EditProfileScreen> {
  /// Controller for the (read-only) username field.
  final _userNameController = TextEditingController();

  /// Controller for the first-name field.
  final _fNameController = TextEditingController();

  /// Controller for the last-name field.
  final _lNameController = TextEditingController();

  /// Controller for the bio field.
  final _bioController = TextEditingController();

  /// Controller for the phone-number field.
  final _phoneController = TextEditingController();

  /// Controller for the (read-only) email field.
  final _emailController = TextEditingController();

  /// Holds the avatar image the user picked, or `null` if unchanged.
  ///
  /// A [ValueNotifier] so only the avatar preview rebuilds on selection.
  final ValueNotifier<XFile?> _profileImage = ValueNotifier(null);

  /// Gallery picker used to choose a new avatar image.
  final ImagePicker _picker = ImagePicker();

  /// Opens the gallery and stores the chosen image in [_profileImage].
  ///
  /// Does nothing if the user cancels the picker.
  Future<void> _pickProfileImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      _profileImage.value = image;
    }
  }

  /// Disposes all text controllers to avoid memory leaks.
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

  /// Builds the edit-profile form.
  ///
  /// The body subscribes to `getProfileRx.getProfileStream`; when data
  /// arrives the controllers are seeded with the current profile values
  /// before the form is rendered.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit Profile',
          style: TextFontStyle.headline16w500CF7F7F7Poppins.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
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

            // Light: recessed grey field fill (the labels above are dark).
            // Dark: keep the original c161618 so dark is unchanged.
            final Color fieldFill =
                Theme.of(context).brightness == Brightness.dark
                    ? AppColors.c161618
                    : context.reacti.surfaceVariant;

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
                    style: TextFontStyle.headline16w500CFFFFFFPoppins.copyWith(
                      color: context.reacti.textPrimary,
                    ),
                  ),
                  UIHelper.verticalSpace(8.h),

                  CustomFormField(
                    hintText: data?.username ?? "",
                    fillColor: fieldFill,
                    controller: _userNameController,
                    isRead: true,
                  ),
                  UIHelper.verticalSpace(20.h),

                  Text(
                    "First Name",
                    style: TextFontStyle.headline16w500CFFFFFFPoppins.copyWith(
                      color: context.reacti.textPrimary,
                    ),
                  ),
                  UIHelper.verticalSpace(8.h),

                  CustomFormField(
                    hintText: "Enter your full name",
                    fillColor: fieldFill,
                    controller: _fNameController,
                  ),

                  UIHelper.verticalSpace(20.h),

                  Text(
                    "Last Name",
                    style: TextFontStyle.headline16w500CFFFFFFPoppins.copyWith(
                      color: context.reacti.textPrimary,
                    ),
                  ),
                  UIHelper.verticalSpace(8.h),

                  CustomFormField(
                    hintText: "Enter your full name",
                    fillColor: fieldFill,
                    controller: _lNameController,
                  ),
                  UIHelper.verticalSpace(20.h),

                  Text(
                    "Phone Number",
                    style: TextFontStyle.headline16w500CFFFFFFPoppins.copyWith(
                      color: context.reacti.textPrimary,
                    ),
                  ),
                  UIHelper.verticalSpace(8.h),

                  CustomFormField(
                    hintText: "Enter your phone number",
                    fillColor: fieldFill,
                    controller: _phoneController,
                    inputType: TextInputType.phone,
                  ),
                  UIHelper.verticalSpace(20.h),
                  Text(
                    "Email",
                    style: TextFontStyle.headline16w500CFFFFFFPoppins.copyWith(
                      color: context.reacti.textPrimary,
                    ),
                  ),
                  UIHelper.verticalSpace(8.h),

                  CustomFormField(
                    hintText: "Enter your email",
                    fillColor: fieldFill,
                    controller: _emailController,
                    inputType: TextInputType.phone,
                    isRead: true,
                  ),
                  UIHelper.verticalSpace(20.h),

                  Text(
                    "Bio",
                    style: TextFontStyle.headline16w500CFFFFFFPoppins.copyWith(
                      color: context.reacti.textPrimary,
                    ),
                  ),
                  UIHelper.verticalSpace(8.h),

                  CustomFormField(
                    hintText: "Write a short bio",
                    fillColor: fieldFill,
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
                          .waitingForSuccess()
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

  /// Builds the circular avatar preview with an overlaid camera button.
  ///
  /// Shows the newly picked image when one exists, otherwise the remote
  /// avatar from [data], falling back to a placeholder asset. Tapping the
  /// camera button triggers [_pickProfileImage].
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
