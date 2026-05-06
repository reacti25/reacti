import 'package:get_it/get_it.dart';
import 'package:get_storage/get_storage.dart';

final locator = GetIt.instance;
final appData = locator.get<GetStorage>();

void diSetUp() {
  locator.registerSingleton<GetStorage>(GetStorage());
}