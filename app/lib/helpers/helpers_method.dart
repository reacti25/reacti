import 'dart:io';

import 'package:achiar_expert_app/constants/app_constants.dart';
import 'package:achiar_expert_app/helpers/di.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

String formatTimeOfDay(TimeOfDay time) {
  final hour =
      time.hourOfPeriod == 0
          ? 12
          : time.hourOfPeriod; // Convert 0 to 12 for AM/PM format
  final period = time.period == DayPeriod.am ? "AM" : "PM";
  final minute = time.minute.toString().padLeft(
    2,
    '0',
  ); // Add leading zero to minutes if needed
  return "$hour:$minute $period";
}

final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
final phoneRegex = RegExp(r'^[\+]?[0-9\s\-\(\)]+$');

Future<String?> pickDate({
  required BuildContext context,
  required DateTime startDate,
  required DateTime endDate,
  String dateFormat = "yyyy-MM-dd",
}) async {
  final DateTime? pickedDate = await showDatePicker(
    context: context,
    initialDate: startDate,
    firstDate: startDate,
    lastDate: endDate,
  );

  if (pickedDate != null) {
    return DateFormat(dateFormat).format(pickedDate);
  }
  return null;
}

Future<void> showCustomDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  required Function(DateTime) onDatePicked,
}) async {
  final DateTime? pickedDate = await showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
  );

  if (pickedDate != null) {
    onDatePicked(pickedDate);
  }
}

String formatDate(DateTime date) {
  return DateFormat('MM/dd/yyyy').format(date);
}

String formatDateYear(DateTime date) {
  return DateFormat('yyyy-MM-dd').format(date);
}

String dashFormatDate(DateTime date) {
  return DateFormat('MM-dd-yyyy').format(date);
}

DateTime formatStringIntoDate(String date) {
  return DateFormat("MM/dd/yyyy").parse(date);
}

Future<void> showCustomTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  required Function(TimeOfDay) onTimePicked,
}) async {
  final TimeOfDay? pickedTime = await showTimePicker(
    context: context,
    initialTime: initialTime,
  );

  if (pickedTime != null) {
    onTimePicked(pickedTime);
  }
}

String formatTime(TimeOfDay time, BuildContext context) {
  final now = DateTime.now();
  final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
  return TimeOfDay.fromDateTime(dt).format(context);
}

String formatedTime(TimeOfDay time) {
  final hour =
      time.hourOfPeriod == 0
          ? 12
          : time.hourOfPeriod; // Adjusts for 12-hour format
  final minute = time.minute.toString().padLeft(
    2,
    '0',
  ); // Pads minutes with a leading zero if needed
  final period = time.period == DayPeriod.am ? 'AM' : 'PM';

  return '$hour:$minute $period';
}

String formatTimeOfDay24Hour(TimeOfDay time) {
  final int hour = time.hour;
  final int minute = time.minute;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

TimeOfDay convertToTimeOfDay(String timeString) {
  DateFormat dateFormat = DateFormat("hh:mm a");
  DateTime dateTime = dateFormat.parse(timeString);
  return TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);
}

TimeOfDay formatStringToTime(String timeString) {
  try {
    final parts = timeString.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return TimeOfDay(hour: hour, minute: minute);
  } catch (e) {
    throw FormatException("Invalid time format: $timeString");
  }
}

// Future<void> initInternetChecker() async {
//   InternetConnectionChecker.createInstance(
//     checkInterval: const Duration(seconds: 2),
//   ).onStatusChange.listen((status) {
//     switch (status) {
//       case InternetConnectionStatus.connected:
//         // ToastUtil.showShortToast('Data connection is available.');
//         break;
//       case InternetConnectionStatus.disconnected:
//         ToastUtil.showNoInternetToast();
//         break;
//       case InternetConnectionStatus.slow:
//         ToastUtil.showShortToast('Your internet connection is slow.');
//         break;
//     }
//   });
// }

TimeOfDay parseTime(String timeString) {
  // Example parsing format: "9:00 AM"
  // Adjust this based on your app's time format (e.g., "hh:mm a")
  final timeParts = timeString.split(':');
  if (timeParts.length == 2) {
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1].split(' ')[0]);
    final isPM = timeString.contains('PM');

    // Adjust hour for AM/PM
    final adjustedHour = isPM && hour != 12 ? hour + 12 : hour;
    return TimeOfDay(hour: adjustedHour, minute: minute);
  }
  return TimeOfDay.now(); // Default to current time if parsing fails
}

Future<void> setInitValue() async {
  await appData.writeIfNull(kKeyIsLoggedIn, false);
  await appData.writeIfNull(kKeyIsFirstTime, true);

  //lisbon
  // appData.writeIfNull(kKeySelectedLat, 38.74631383626653);
  // appData.writeIfNull(kKeySelectedLng, -9.130169921874991);
  //codemen
  // await appData.writeIfNull(kKeySelectedLat, 22.818285677915657);
  // await appData.writeIfNull(kKeySelectedLng, 89.5535583794117);

  var deviceInfo = DeviceInfoPlugin();
  if (Platform.isIOS) {
    var iosDeviceInfo = await deviceInfo.iosInfo;
    appData.writeIfNull(kKeyDeviceID, iosDeviceInfo.identifierForVendor);
  } else if (Platform.isAndroid) {
    var androidDeviceInfo = await deviceInfo.androidInfo;
    appData.writeIfNull(kKeyDeviceID, androidDeviceInfo.id);
  }
  await Future.delayed(const Duration(seconds: 3));
}

void rotation() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
}
