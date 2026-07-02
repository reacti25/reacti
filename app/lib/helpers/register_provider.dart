import 'package:reacti_app/provider/auth_provider.dart';
import 'package:reacti_app/theme/theme_controller.dart';
import 'package:provider/provider.dart';

/// App-wide list of `provider` package providers registered at the root.
///
/// Fed into a `MultiProvider` during app bootstrap so every screen can
/// resolve shared state such as [AuthProvider] and [ThemeController].
var providers = [
  ChangeNotifierProvider<AuthProvider>(create: (context) => AuthProvider()),
  ChangeNotifierProvider<ThemeController>(
    create: (context) => ThemeController(),
  ),
];
