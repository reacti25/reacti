import 'package:achiar_expert_app/constants/app_constants.dart';
import 'package:achiar_expert_app/helpers/di.dart';

Future<void> totalDataClean() async {
  await appData.write(kKeyIsLoggedIn, false);
  // await appData.write(kKeyRole, '');
}
