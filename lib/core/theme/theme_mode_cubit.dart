import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide (like `AlarmCubit`) — theme choice must survive navigation.
/// Persists to `shared_preferences` directly rather than going through a
/// full feature-first domain/data stack: this is a single UI preference,
/// not a domain concept with business rules, so the extra layering would
/// be pure ceremony (project style guide: keep code as short as it can be
/// while remaining clear).
@lazySingleton
class ThemeModeCubit extends Cubit<ThemeMode> {
  ThemeModeCubit() : super(ThemeMode.system) {
    unawaited(_load());
  }

  static const _key = 'theme_mode';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    final mode = ThemeMode.values.firstWhere(
      (m) => m.name == stored,
      orElse: () => ThemeMode.system,
    );
    if (mode != state) emit(mode);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    emit(mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}
