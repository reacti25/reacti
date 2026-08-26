// Guards the contacts permission check on the Contacts tab.
//
// The bug: `FlutterContacts.getAll()` returns an EMPTY LIST rather than
// throwing when access is denied on iOS. The screen inferred permission from
// that call not blowing up, so "you said no" and "your phonebook is empty"
// looked identical — it latched onto granted, showed "No Contacts Found"
// forever, and Refresh did nothing, because the retry path saw a successful
// fetch and returned before it could ask again. There was no way back to
// sharing contacts short of reinstalling the app.
//
// Permission is now read from the OS. What is pinned here is which answers
// count as yes.

import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:reacti_app/features/friends/presentation/find_screen.dart';

void main() {
  test('granted means the phonebook can be read', () {
    expect(canReadContacts(PermissionStatus.granted), isTrue);
  });

  test('limited counts as yes — iOS 18 partial sharing', () {
    // The user picked some contacts to share. Treating that as a refusal would
    // park them on the "share your contacts" screen having already shared.
    expect(canReadContacts(PermissionStatus.limited), isTrue);
  });

  test('every refusal is a no', () {
    // Each of these used to end up indistinguishable from "granted, but your
    // phonebook is empty".
    expect(canReadContacts(PermissionStatus.denied), isFalse);
    expect(canReadContacts(PermissionStatus.permanentlyDenied), isFalse);
    expect(canReadContacts(PermissionStatus.restricted), isFalse);
    expect(canReadContacts(PermissionStatus.provisional), isFalse);
  });
}
