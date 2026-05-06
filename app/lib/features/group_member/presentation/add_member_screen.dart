import 'package:flutter/material.dart';

import '../../../constants/text_font_style.dart';

class AddMemberScreen extends StatefulWidget {
  final int groupId;
  const AddMemberScreen({super.key, required this.groupId});

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Add Members',
          style: TextFontStyle.headline16w500CF7F7F7Poppins,
        ),
      ),
    );
  }
}
