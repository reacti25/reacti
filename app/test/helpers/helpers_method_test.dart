// Unit tests for the pure date/time/validation helpers in
// lib/helpers/helpers_method.dart.
//
// Only the side-effect-free functions are covered here — the date/time
// formatters and parsers, and the email/phone regexes. The dialog
// helpers (pickDate, showCustomDatePicker, showCustomTimePicker),
// formatTime (needs a BuildContext), setInitValue (storage + device
// info) and rotation (SystemChrome) are platform/UI bound and out of
// scope for unit tests.

import 'package:reacti_app/helpers/helpers_method.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatTimeOfDay (12-hour h:mm AM/PM)', () {
    test('formats an evening time', () {
      expect(formatTimeOfDay(const TimeOfDay(hour: 21, minute: 5)), '9:05 PM');
    });

    test('midnight is 12:00 AM', () {
      expect(formatTimeOfDay(const TimeOfDay(hour: 0, minute: 0)), '12:00 AM');
    });

    test('noon is 12:30 PM', () {
      expect(
        formatTimeOfDay(const TimeOfDay(hour: 12, minute: 30)),
        '12:30 PM',
      );
    });

    test('a morning time pads the minutes', () {
      expect(formatTimeOfDay(const TimeOfDay(hour: 9, minute: 7)), '9:07 AM');
    });
  });

  group('formatedTime (12-hour, no context)', () {
    test('formats an evening time', () {
      expect(formatedTime(const TimeOfDay(hour: 13, minute: 9)), '1:09 PM');
    });

    test('midnight is 12:00 AM', () {
      expect(formatedTime(const TimeOfDay(hour: 0, minute: 0)), '12:00 AM');
    });
  });

  group('formatTimeOfDay24Hour (HH:mm)', () {
    test('zero-pads the hour and minute', () {
      expect(
        formatTimeOfDay24Hour(const TimeOfDay(hour: 9, minute: 5)),
        '09:05',
      );
    });

    test('keeps a 24-hour evening time', () {
      expect(
        formatTimeOfDay24Hour(const TimeOfDay(hour: 21, minute: 0)),
        '21:00',
      );
    });
  });

  group('date formatters', () {
    final date = DateTime(2026, 5, 18);

    test('formatDate is MM/dd/yyyy', () {
      expect(formatDate(date), '05/18/2026');
    });

    test('formatDateYear is yyyy-MM-dd', () {
      expect(formatDateYear(date), '2026-05-18');
    });

    test('dashFormatDate is MM-dd-yyyy', () {
      expect(dashFormatDate(date), '05-18-2026');
    });
  });

  group('formatStringIntoDate', () {
    test('parses a MM/dd/yyyy string', () {
      expect(formatStringIntoDate('05/18/2026'), DateTime(2026, 5, 18));
    });

    test('throws on a malformed string', () {
      expect(() => formatStringIntoDate('not-a-date'), throwsFormatException);
    });
  });

  group('convertToTimeOfDay (12-hour hh:mm a)', () {
    test('parses an AM time', () {
      expect(
        convertToTimeOfDay('09:05 AM'),
        const TimeOfDay(hour: 9, minute: 5),
      );
    });

    test('parses a PM time into 24-hour', () {
      expect(
        convertToTimeOfDay('09:05 PM'),
        const TimeOfDay(hour: 21, minute: 5),
      );
    });

    test('throws on a malformed string', () {
      expect(() => convertToTimeOfDay('nonsense'), throwsFormatException);
    });
  });

  group('formatStringToTime (24-hour HH:mm)', () {
    test('parses a colon-separated time', () {
      expect(formatStringToTime('21:05'), const TimeOfDay(hour: 21, minute: 5));
    });

    test('throws a FormatException on a non-time string', () {
      expect(() => formatStringToTime('bad'), throwsFormatException);
    });
  });

  group('parseTime (lenient 12-hour parser)', () {
    test('parses an AM time', () {
      expect(parseTime('9:05 AM'), const TimeOfDay(hour: 9, minute: 5));
    });

    test('parses a PM time, adjusting the hour', () {
      expect(parseTime('9:05 PM'), const TimeOfDay(hour: 21, minute: 5));
    });

    test('leaves 12 PM unchanged', () {
      expect(parseTime('12:00 PM'), const TimeOfDay(hour: 12, minute: 0));
    });

    test('falls back to a TimeOfDay (does not throw) on malformed input', () {
      // No colon -> the parser cannot split it and returns TimeOfDay.now().
      expect(parseTime('garbage'), isA<TimeOfDay>());
    });
  });

  group('validation regexes', () {
    test('emailRegex accepts well-formed addresses', () {
      expect(emailRegex.hasMatch('alice@example.com'), isTrue);
      expect(emailRegex.hasMatch('a.b+c@sub.example.co'), isTrue);
    });

    test('emailRegex rejects malformed addresses', () {
      expect(emailRegex.hasMatch('not-an-email'), isFalse);
      expect(emailRegex.hasMatch('missing@domain'), isFalse);
      expect(emailRegex.hasMatch('@example.com'), isFalse);
    });

    test('phoneRegex accepts digits with +, spaces and brackets', () {
      expect(phoneRegex.hasMatch('+1 (202) 555-0100'), isTrue);
      expect(phoneRegex.hasMatch('2025550100'), isTrue);
    });

    test('phoneRegex rejects letters', () {
      expect(phoneRegex.hasMatch('call-me'), isFalse);
    });
  });
}
