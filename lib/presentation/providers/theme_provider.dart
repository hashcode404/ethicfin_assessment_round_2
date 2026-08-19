import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system);

  void toggleTheme(bool isDarkMode) {
    state = isDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  void toggle(BuildContext context) {
    if (state == ThemeMode.system) {
      final brightness = MediaQuery.platformBrightnessOf(context);
      state = brightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
    } else if (state == ThemeMode.dark) {
      state = ThemeMode.light;
    } else {
      state = ThemeMode.dark;
    }
  }
}
