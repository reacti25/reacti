import 'package:achiar_expert_app/constants/app_constants.dart';
import 'package:achiar_expert_app/helpers/di.dart';

/// Clears persisted session state so the app reverts to a logged-out state.
///
/// Writes `false` to the [kKeyIsLoggedIn] flag in [appData]. Typically invoked
/// on logout or session expiry.
Future<void> totalDataClean() async {
  await appData.write(kKeyIsLoggedIn, false);
  // await appData.write(kKeyRole, '');
}
