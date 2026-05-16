// NOTE: This file is intentionally fully commented out. It holds the legacy
// `NotificationScreen` (an in-app notifications list with hard-coded sample
// data) which is not currently part of the navigation flow. Kept for
// reference until the notifications feature is revived or removed.
//
// import 'package:achiar_expert_app/common_widget/custom_network_image.dart';
// import 'package:achiar_expert_app/constants/text_font_style.dart';
// import 'package:achiar_expert_app/features/notification/model/notification_model.dart';
// import 'package:achiar_expert_app/gen/colors.gen.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';

// class NotificationScreen extends StatefulWidget {
//   const NotificationScreen({super.key});

//   @override
//   State<NotificationScreen> createState() => _NotificationScreenState();
// }

// class _NotificationScreenState extends State<NotificationScreen> {
//   // Sample notifications
//   final List<NotificationItem> notifications = [
//     NotificationItem(
//       title: 'Mk Azizi ',
//       message: '3 Mutual Contacts',
//       timestamp: DateTime.now().subtract(Duration(hours: 6)),
//       imageUrl:
//           "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&q=80&w=1170",
//     ),
//     NotificationItem(
//       title: 'Mk Azizi ',
//       message: '3 Mutual Contacts',
//       timestamp: DateTime.now().subtract(Duration(days: 1)),
//       imageUrl:
//           "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&q=80&w=1170",
//     ),
//     NotificationItem(
//       title: 'Mk Azizi ',
//       message: '3 Mutual Contacts',
//       timestamp: DateTime.now().subtract(Duration(days: 1)),
//       imageUrl:
//           "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&q=80&w=1170",
//     ),
//     NotificationItem(
//       title: 'Mk Azizi ',
//       message: '3 Mutual Contacts',
//       timestamp: DateTime.now().subtract(Duration(days: 1)),
//       imageUrl:
//           "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&q=80&w=1170",
//     ),
//     NotificationItem(
//       title: 'Mk Azizi ',
//       message: '3 Mutual Contacts',
//       timestamp: DateTime.now().subtract(Duration(days: 1)),
//       imageUrl:
//           "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&q=80&w=1170",
//     ),
//     NotificationItem(
//       title: 'Mk Azizi ',
//       message: '3 Mutual Contacts',
//       timestamp: DateTime.now().subtract(Duration(days: 1)),
//       imageUrl:
//           "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&q=80&w=1170",
//     ),
//     NotificationItem(
//       title: 'Mk Azizi ',
//       message: '3 Mutual Contacts',
//       timestamp: DateTime.now().subtract(Duration(days: 1)),
//       imageUrl:
//           "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&q=80&w=1170",
//     ),
//     NotificationItem(
//       title: 'Mk Azizi ',
//       message: '3 Mutual Contacts',
//       timestamp: DateTime.now().subtract(Duration(days: 1)),
//       imageUrl:
//           "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&q=80&w=1170",
//     ),
//     NotificationItem(
//       title: 'Mk Azizi ',
//       message: '3 Mutual Contacts',
//       timestamp: DateTime.now().subtract(Duration(days: 1)),
//       imageUrl:
//           "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&q=80&w=1170",
//     ),
//     NotificationItem(
//       title: 'Mk Azizi ',
//       message: '3 Mutual Contacts',
//       timestamp: DateTime.now().subtract(Duration(days: 1)),
//       imageUrl:
//           "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&q=80&w=1170",
//     ),
//     NotificationItem(
//       title: 'Mk Azizi ',
//       message: '3 Mutual Contacts',
//       timestamp: DateTime.now().subtract(Duration(days: 1)),
//       imageUrl:
//           "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&q=80&w=1170",
//     ),
//     NotificationItem(
//       title: 'Mk Azizi ',
//       message: '3 Mutual Contacts',
//       timestamp: DateTime.now().subtract(Duration(days: 1)),
//       imageUrl:
//           "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&q=80&w=1170",
//     ),
//     NotificationItem(
//       title: 'Mk Azizi ',
//       message: '3 Mutual Contacts',
//       timestamp: DateTime.now().subtract(Duration(days: 1)),
//       imageUrl:
//           "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&q=80&w=1170",
//     ),
//     NotificationItem(
//       title: 'Mk Azizi ',
//       message: '3 Mutual Contacts',
//       timestamp: DateTime.now().subtract(Duration(days: 1)),
//       imageUrl:
//           "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&q=80&w=1170",
//     ),
//   ];

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         title: Text(
//           "Notifications",
//           style: TextFontStyle.headline20w600CFFFFFFPoppins,
//         ),
//       ),
//       body:
//           notifications.isEmpty
//               ? Center(
//                 child: Text(
//                   'No notifications yet',
//                   style: TextFontStyle.headline14w400C666666Poppins.copyWith(
//                     color: AppColors.cE5E5E5,
//                   ),
//                 ),
//               )
//               : ListView.builder(
//                 physics: BouncingScrollPhysics(),
//                 padding: EdgeInsets.symmetric(horizontal: 20.w),
//                 itemCount: notifications.length,
//                 itemBuilder: (context, index) {
//                   final notification = notifications[index];
//                   return Card(
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(6.r),
//                     ),
//                     color: AppColors.c161618,
//                     margin: EdgeInsets.only(bottom: 12.h),
//                     child: ListTile(
//                       leading: ClipOval(
//                         child: CustomNetworkImage(
//                           height: 32.h,
//                           width: 32.w,
//                           urls: notification.imageUrl,
//                         ),
//                       ),
//                       title: Text(
//                         notification.title,
//                         style: TextFontStyle.headline16w400CFFFFFFPoppins
//                             .copyWith(color: AppColors.cE5E5E5),
//                       ),
//                       subtitle: Text(
//                         notification.message,
//                         style: TextFontStyle.headline10w400CF7F7F7Poppins
//                             .copyWith(color: AppColors.cE5E5E5),
//                       ),

//                       trailing: Text(
//                         _formatTime(notification.timestamp),
//                         style: TextFontStyle.headline14w400C666666Poppins
//                             .copyWith(color: AppColors.cE5E5E5),
//                       ),
//                       onTap: () {
//                         // Handle notification tap
//                       },
//                     ),
//                   );
//                 },
//               ),
//     );
//   }

//   String _formatTime(DateTime timestamp) {
//     final now = DateTime.now();
//     final difference = now.difference(timestamp);

//     if (difference.inMinutes < 60) {
//       return '${difference.inMinutes} minutes ago';
//     } else if (difference.inHours < 24) {
//       return '${difference.inHours} hours ago';
//     } else {
//       return '${difference.inDays} days ago';
//     }
//   }
// }
