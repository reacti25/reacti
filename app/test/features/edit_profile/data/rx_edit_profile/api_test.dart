// The profile update sends each field under the key the server reads.

import 'package:flutter_test/flutter_test.dart';
import 'package:reacti_app/features/edit_profile/data/rx_edit_profile/api.dart';

void main() {
  test('the bio goes out as bio, which the server saves', () {
    final fields = profileFields(
      fName: 'Ada',
      lName: 'Lovelace',
      phone: '555',
      bio: 'hello',
    );
    expect(fields, {
      'first_name': 'Ada',
      'last_name': 'Lovelace',
      'phone': '555',
      'bio': 'hello',
    });
  });
}
