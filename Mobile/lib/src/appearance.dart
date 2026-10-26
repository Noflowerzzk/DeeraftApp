import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state.dart';

final appearanceProvider = NotifierProvider<AppearanceController, ThemeMode>(
  AppearanceController.new,
);

class AppearanceController extends Notifier<ThemeMode> {
  static const storageKey = 'appearance.themeMode';
  int _revision = 0;
  @override
  ThemeMode build() {
    Future.microtask(_restore);
    return ThemeMode.system;
  }

  Future<void> _restore() async {
    final revision = _revision;
    try {
      final saved = await ref.read(apiProvider).storage.read(key: storageKey);
      if (ref.mounted && revision == _revision) {
        state =
            ThemeMode.values.where((mode) => mode.name == saved).firstOrNull ??
            ThemeMode.system;
      }
    } catch (_) {
      // A preference read failure must not prevent login or normal browsing.
    }
  }

  Future<void> select(ThemeMode mode) async {
    final revision = ++_revision;
    final previous = state;
    state = mode;
    try {
      await ref
          .read(apiProvider)
          .storage
          .write(key: storageKey, value: mode.name);
    } catch (_) {
      if (ref.mounted && revision == _revision) state = previous;
      rethrow;
    }
  }
}
