import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../constants/text_font_style.dart';
import '../../../../theme/app_theme.dart';

/// Composer bar shown in place of the normal message composer while the user
/// is editing one of their own text messages (WhatsApp-style).
///
/// Shows an "Edit message" header with a cancel control, a text field
/// prefilled with the current text, and a confirm button. Submitting hands the
/// trimmed text back via [onSubmit]; the screen performs the edit API call and
/// updates the message. Kept separate from the send composer so the send path
/// (media staging, reactions) stays untouched.
class MessageEditBar extends StatefulWidget {
  /// Creates the edit bar.
  ///
  /// [initialText] seeds the field; [onSubmit] receives the new (trimmed,
  /// non-empty) text; [onCancel] dismisses edit mode.
  const MessageEditBar({
    super.key,
    required this.initialText,
    required this.onSubmit,
    required this.onCancel,
  });

  /// The message's current text, used to seed the field.
  final String initialText;

  /// Invoked with the new trimmed text when the user confirms the edit.
  final void Function(String text) onSubmit;

  /// Invoked when the user cancels editing.
  final VoidCallback onCancel;

  @override
  State<MessageEditBar> createState() => _MessageEditBarState();
}

/// State for [MessageEditBar]; owns the prefilled text controller.
class _MessageEditBarState extends State<MessageEditBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Submits the edit when the field holds non-empty text.
  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      color: context.reacti.bubbleIn,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.edit_outlined, size: 16.sp, color: scheme.primary),
                SizedBox(width: 8.w),
                Text(
                  "Edit message",
                  style: TextFontStyle.headline14w600C333333Poppins.copyWith(
                    color: scheme.primary,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: widget.onCancel,
                  child: Icon(
                    Icons.close,
                    size: 18.sp,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
            SizedBox(height: 6.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    minLines: 1,
                    maxLines: 4,
                    style: TextFontStyle.headline14w600C333333Poppins.copyWith(
                      color: scheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 8.h,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                SizedBox(width: 8.w),
                IconButton(
                  onPressed: _submit,
                  icon: Icon(
                    Icons.check_circle,
                    color: scheme.primary,
                    size: 30.sp,
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
