import 'package:reacti_app/constants/app_constants.dart';
import 'package:reacti_app/helpers/di.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';

/// Holds the user's chosen appearance ([ThemeMode]) and persists it.
///
/// A `provider` [ChangeNotifier]: `GetMaterialApp` watches [themeMode] and
/// rebuilds when [setThemeMode] fires, applying the change app-wide instantly.
/// The choice is stored under [kKeyThemeMode] and defaults to
/// [ThemeMode.system] (follow the OS) when unset — for new and existing users.
class ThemeController extends ChangeNotifier {
  /// Creates the controller, loading any persisted choice.
  ///
  /// [storage] defaults to the shared [appData] store; inject a test store to
  /// exercise persistence in isolation.
  ThemeController({GetStorage? storage}) : _storage = storage ?? appData {
    _mode = _read();
  }

  /// Backing store for the persisted [ThemeMode].
  final GetStorage _storage;

  /// The active appearance; mirrored from [_storage] on construction.
  late ThemeMode _mode;

  /// The active appearance, fed to `GetMaterialApp.themeMode`.
  ThemeMode get themeMode => _mode;

  /// Reads the stored [ThemeMode] name, defaulting to [ThemeMode.system].
  ThemeMode _read() {
    switch (_storage.read(kKeyThemeMode)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  /// Sets and persists the appearance, notifying listeners on a real change.
  ///
  /// Listeners fire immediately so the theme applies app-wide without waiting
  /// on disk; the persistence write follows.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    await _storage.write(kKeyThemeMode, mode.name);
  }
}
