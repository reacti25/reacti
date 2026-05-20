import '../model/chat_list_response.dart';

/// Pure presentation logic for the conversations screen.
///
/// Extracted from `ChatScreen` so it can be unit-tested without booting
/// the widget. These functions are side-effect free.

/// Returns a time-of-day greeting for the given 24-hour [hour].
///
/// `Good Morning` for 05:00–11:59, `Good Afternoon` for 12:00–16:59,
/// `Good Evening` for 17:00–20:59, and `Good Night` for any other hour.
///
/// @param  hour  The hour of day, 0–23 (e.g. `DateTime.now().hour`).
/// @return  The matching greeting string.
String timeBasedGreeting(int hour) {
  if (hour >= 5 && hour < 12) {
    return 'Good Morning';
  } else if (hour >= 12 && hour < 17) {
    return 'Good Afternoon';
  } else if (hour >= 17 && hour < 21) {
    return 'Good Evening';
  } else {
    return 'Good Night';
  }
}

/// Filters [chats] to the conversations whose name contains [query],
/// matched case-insensitively.
///
/// @param  chats  The full conversation list.
/// @param  query  The search text; an empty string matches everything.
/// @return  A new list of the matching conversations, order preserved.
List<Chat> filterChatsByName(List<Chat> chats, String query) {
  return chats
      .where((chat) => chat.name!.toLowerCase().contains(query.toLowerCase()))
      .toList();
}
