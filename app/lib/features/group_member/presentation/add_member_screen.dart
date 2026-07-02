import 'package:flutter/material.dart';

import '../../../constants/text_font_style.dart';

/// Screen for adding new members to an existing group.
///
/// Currently a placeholder that renders only an app bar; the member-picker
/// UI is not yet implemented.
class AddMemberScreen extends StatefulWidget {
  /// Identifier of the group members will be added to.
  final int groupId;

  /// Creates an [AddMemberScreen] for the group [groupId].
  const AddMemberScreen({super.key, required this.groupId});

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

/// State for [AddMemberScreen].
class _AddMemberScreenState extends State<AddMemberScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Add Members',
          style: TextFontStyle.headline16w500CF7F7F7Poppins.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
