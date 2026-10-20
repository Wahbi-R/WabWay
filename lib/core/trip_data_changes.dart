import 'package:flutter/foundation.dart';
import '../data/connection_data.dart' show EntityType;

/// "Something in the trip was just saved on this device" — for the shell's
/// tabs (Money, Travel, Stays, Plan), which stay alive in the background and
/// otherwise only refresh from realtime. Realtime misses changes made while
/// its connection was down (e.g. the app was in the background for a share),
/// so anything that saves outside the screen showing it — Read booking, the
/// offline queue — also bumps this. Screens subscribe with
/// [AsyncScreenMixin.reloadOnChanges].
abstract final class TripDataChanges {
  static final Map<EntityType, ValueNotifier<int>> _notifiers = {};

  static ValueNotifier<int> _of(EntityType kind) =>
      _notifiers.putIfAbsent(kind, () => ValueNotifier(0));

  /// Fires whenever [kind] is changed through [touch].
  static Listenable of(EntityType kind) => _of(kind);

  static void touch(Iterable<EntityType> kinds) {
    for (final k in kinds.toSet()) {
      _of(k).value++;
    }
  }
}
