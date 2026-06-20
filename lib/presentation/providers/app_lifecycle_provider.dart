import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Current app lifecycle state, updated by the root [WidgetsBindingObserver].
final appLifecycleProvider =
    StateProvider<AppLifecycleState>((ref) => AppLifecycleState.resumed);

/// True while the app is in the foreground. Used to gate notifications so we
/// don't alert the user about events while they're actively looking at the app.
final isForegroundProvider = Provider<bool>(
  (ref) => ref.watch(appLifecycleProvider) == AppLifecycleState.resumed,
);
