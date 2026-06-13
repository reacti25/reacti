import 'dart:io';

import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Formats [time] as a 12-hour clock string such as `9:05 PM`.
///
/// Returns the formatted `h:mm AM/PM` string.
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

/// Validation pattern for email addresses used in auth/profile forms.
final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

/// Validation pattern for phone numbers, allowing `+`, spaces and brackets.
final phoneRegex = RegExp(r'^[\+]?[0-9\s\-\(\)]+$');

/// Shows the platform date picker and returns the chosen date as a string.
///
/// The dialog is anchored to [context] and bounded between [startDate] and
/// [endDate]. The result is formatted with [dateFormat] (defaults to
/// `yyyy-MM-dd`). Returns `null` when the user dismisses the picker.
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

/// Shows the platform date picker and invokes a callback with the result.
///
/// Anchored to [context] and bounded between [firstDate] and [lastDate],
/// starting at [initialDate]. When the user confirms a date, [onDatePicked]
/// is called with the chosen [DateTime]; dismissal invokes nothing. Use this
/// (rather than [pickDate]) when the caller wants the raw [DateTime].
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

/// Formats [date] as a `MM/dd/yyyy` string for display.
String formatDate(DateTime date) {
  return DateFormat('MM/dd/yyyy').format(date);
}

/// Formats [date] as an ISO-style `yyyy-MM-dd` string (e.g. for API payloads).
String formatDateYear(DateTime date) {
  return DateFormat('yyyy-MM-dd').format(date);
}

/// Formats [date] as a dash-separated `MM-dd-yyyy` string.
String dashFormatDate(DateTime date) {
  return DateFormat('MM-dd-yyyy').format(date);
}

/// Parses a `MM/dd/yyyy` string [date] back into a [DateTime].
///
/// Throws a [FormatException] if [date] does not match the expected format.
DateTime formatStringIntoDate(String date) {
  return DateFormat("MM/dd/yyyy").parse(date);
}

/// Shows the platform time picker and invokes a callback with the result.
///
/// Anchored to [context] and opened at [initialTime]. When the user confirms,
/// [onTimePicked] is called with the chosen [TimeOfDay]; dismissal does
/// nothing.
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

/// Formats [time] using the locale-aware formatting of the given [context].
///
/// Honours the device's 12/24-hour preference, unlike [formatTimeOfDay]
/// which always produces a 12-hour string.
String formatTime(TimeOfDay time, BuildContext context) {
  final now = DateTime.now();
  final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
  return TimeOfDay.fromDateTime(dt).format(context);
}

/// Formats [time] as a 12-hour `h:mm AM/PM` string without needing a context.
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

/// Formats [time] as a zero-padded 24-hour `HH:mm` string.
String formatTimeOfDay24Hour(TimeOfDay time) {
  final int hour = time.hour;
  final int minute = time.minute;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// Parses a 12-hour `hh:mm a` string [timeString] into a [TimeOfDay].
///
/// Throws a [FormatException] if [timeString] cannot be parsed.
TimeOfDay convertToTimeOfDay(String timeString) {
  DateFormat dateFormat = DateFormat("hh:mm a");
  DateTime dateTime = dateFormat.parse(timeString);
  return TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);
}

/// Parses a 24-hour `HH:mm` string [timeString] into a [TimeOfDay].
///
/// Throws a [FormatException] if [timeString] is not a colon-separated
/// hour/minute pair.
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

/// Leniently parses a `h:mm AM/PM` string [timeString] into a [TimeOfDay].
///
/// Unlike [convertToTimeOfDay] this does not throw on malformed input: it
/// falls back to [TimeOfDay.now] when [timeString] cannot be parsed.
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

/// Seeds first-run default values into [appData] and captures the device ID.
///
/// Initialises the logged-in and first-time flags only if absent (so existing
/// state is preserved across restarts) and stores the platform-specific
/// device identifier. The trailing delay paces the splash screen.
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
  // (Removed a hardcoded 3-second Future.delayed that padded every cold start
  // purely to keep the splash visible — the splash now shows only as long as
  // real initialization takes.)
}

/// Applies the app's global system-UI chrome and orientation preferences.
///
/// Makes the status bar transparent with dark icons and locks the app to
/// portrait orientations. Intended to run once during app bootstrap.
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
