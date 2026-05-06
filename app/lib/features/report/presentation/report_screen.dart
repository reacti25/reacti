import 'package:achiar_expert_app/common_widget/custom_button.dart';
import 'package:achiar_expert_app/common_widget/custom_form_field.dart';
import 'package:achiar_expert_app/gen/colors.gen.dart';
import 'package:achiar_expert_app/helpers/ui_helpers.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../constants/text_font_style.dart';

class ReportScreen extends StatefulWidget {
  final String name;
  const ReportScreen({super.key, required this.name});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _reportTextController = TextEditingController();

  final List<String> reportReasonList = [
    'Harassment or Abusive Behavior',
    'Spam',
    'Impersonation',
    'Inappropriate or Harmful Content',
    'Intellectual Property Violations',
    'Policy or Rule Violations',
    'Fake Name/Profile',
  ];

  String? selectedValue;
  @override
  void dispose() {
    _reportTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Report ${widget.name}',
          style: TextFontStyle.headline16w500CFFFFFFPoppins,
        ),
      ),
      body: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UIHelper.verticalSpace(14.h),

            Text(
              "Why are you reporting this user ?",
              style: TextFontStyle.headline14w500CFFFFFFPoppins,
            ),
            UIHelper.verticalSpace(18.h),
            DropdownButtonFormField2<String>(
              isExpanded: true,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                // filled: true,
                // fillColor: AppColors.c161618,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: AppColors.cFFFFFF, width: 1.w),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(
                    color: AppColors.cFFFFFF.withValues(alpha: 0.5),
                    width: 1.w,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: AppColors.cFFFFFF, width: 1.w),
                ),
                // Add more decoration..
              ),
              hint: Text(
                'Select a reason',
                style: TextFontStyle.headline16w400CFFFFFFPoppins.copyWith(
                  fontSize: 14.sp,
                  color: AppColors.cFFFFFF.withValues(alpha: 0.5),
                ),
              ),
              items:
                  reportReasonList
                      .map(
                        (item) => DropdownItem<String>(
                          value: item,
                          height: 48.h,
                          child: Text(
                            item,
                            style: TextFontStyle.headline16w500CFFFFFFPoppins,
                          ),
                        ),
                      )
                      .toList(),
              validator: (value) {
                if (value == null) {
                  return 'Please select gender.';
                }
                return null;
              },
              onChanged: (value) {},
              onSaved: (value) {
                selectedValue = value.toString();
              },
              buttonStyleData: const FormFieldButtonStyleData(
                padding: EdgeInsets.only(right: 8),
              ),
              iconStyleData: const IconStyleData(
                icon: Icon(
                  Icons.arrow_drop_down_rounded,
                  color: AppColors.cFFFFFF,
                ),
                iconSize: 24,
              ),
              dropdownStyleData: DropdownStyleData(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15.r),
                  color: AppColors.c161618,
                ),
              ),
              menuItemStyleData: const MenuItemStyleData(
                padding: EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
            UIHelper.verticalSpace(18.h),
            Text(
              "Describe the issue",
              style: TextFontStyle.headline14w500CFFFFFFPoppins,
            ),
            UIHelper.verticalSpace(12.h),
            CustomFormField(
              minLine: 4,
              maxline: 7,
              controller: _reportTextController,
              hintText: 'Write here... ',
              textInputAction: TextInputAction.newline,
            ),
            UIHelper.verticalSpace(38.h),

            // Center(child: Text('This is the Repost Screen')),
            CustomButton(onTap: () {}, btnName: "Submit Report"),
          ],
        ),
      ),
    );
  }
}
