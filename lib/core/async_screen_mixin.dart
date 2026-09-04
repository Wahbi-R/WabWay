import 'package:flutter/material.dart';

/// Mixin for [State] subclasses that perform async data loads.
///
/// Provides the standard SWR pattern used across every screen:
///   - generation counter to discard results from superseded loads
///   - mounted check integration
///   - consistent loading / error / offline state
///
/// Usage:
/// ```dart
/// class _MyScreenState extends ConsumerState<MyScreen> with AsyncScreenMixin {
///   List<Item> _items = [];
///
///   Future<void> _load({bool silent = false}) async {
///     final gen = beginLoad(silent: silent);
///     try {
///       final items = await ItemService.load(widget.tripId);
///       commitLoad(gen, () => _items = items);
///     } catch (_) {
///       failLoad(gen, silent: silent);
///     }
///   }
/// }
/// ```
///
/// Reference these fields directly in build(): [loading], [error], [offline],
/// [errorMessage]. Never re-declare them on the State — they come from here.
/// Never write `!mounted || gen != _loadGen` manually — use [isStale].
mixin AsyncScreenMixin<T extends StatefulWidget> on State<T> {
  // Generation counter — library-private, only accessed via the public API below.
  int _loadGen = 0;

  /// True while a non-silent load is in progress (show spinner).
  bool loading = true;

  /// True when a non-silent load failed (show error UI).
  bool error = false;

  /// True when a silent background refresh failed (show offline banner).
  bool offline = false;

  /// Human-readable error detail, set by [failLoad] when [errorMessage] is
  /// provided. Display this when [error] is true and you need more than a
  /// generic "failed to load" message.
  String errorMessage = '';

  /// Starts a new load cycle. Increments the generation counter and, for
  /// non-silent loads, resets [loading]/[error]/[offline] via [setState].
  /// Returns the generation token — pass it unchanged to [commitLoad],
  /// [failLoad], or [isStale].
  int beginLoad({bool silent = false}) {
    // Don't supersede an in-progress non-silent load with a background refresh:
    // the non-silent result would be discarded as stale. Return -1 so any
    // commitLoad/failLoad call for this silent load is immediately a no-op.
    if (silent && loading) return -1;
    final gen = ++_loadGen;
    if (!silent) {
      setState(() {
        loading = true;
        error = false;
        offline = false;
        errorMessage = '';
      });
    }
    return gen;
  }

  /// Returns `true` if [gen] is stale — the widget was unmounted, a newer
  /// load has started, or [gen] is -1 (silent load that was pre-empted).
  bool isStale(int gen) => !mounted || gen < 0 || gen != _loadGen;

  /// Commits a successful load. Runs [onData] inside [setState] along with
  /// clearing [loading], [error], and [offline]. No-ops when stale.
  ///
  /// ```dart
  /// commitLoad(gen, () { _items = freshItems; });
  /// ```
  void commitLoad(int gen, VoidCallback onData) {
    if (isStale(gen)) return;
    setState(() {
      onData();
      loading = false;
      error = false;
      offline = false;
      errorMessage = '';
    });
  }

  /// Marks a failed load. No-ops when stale.
  ///
  /// - Silent failure → sets [offline] (background refresh lost connectivity).
  /// - Non-silent failure → sets [error] (user-triggered load failed).
  ///
  /// Pass [message] to store a human-readable reason in [errorMessage].
  void failLoad(int gen, {bool silent = false, String? message}) {
    if (isStale(gen)) return;
    setState(() {
      loading = false;
      if (silent) {
        offline = true;
      } else {
        error = true;
        offline = false;
        errorMessage = message ?? '';
      }
    });
  }
}
