// Tabs in the shell stay alive, so a receipt saved from Read booking (or the
// offline queue) must refresh Money without restarting the app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wabway/core/async_screen_mixin.dart';
import 'package:wabway/core/trip_data_changes.dart';
import 'package:wabway/data/connection_data.dart' show EntityType;

class _Tab extends StatefulWidget {
  const _Tab({required this.onLoad});
  final VoidCallback onLoad;
  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> with AsyncScreenMixin {
  @override
  void initState() {
    super.initState();
    loading = false;
    reloadOnChanges(const [EntityType.receipt], widget.onLoad);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reloadWhenShown(widget.onLoad);
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  testWidgets('reloads when its data is saved elsewhere, and when shown again', (tester) async {
    var loads = 0;
    Widget shell({required bool shown}) => MaterialApp(
        home: TickerMode(enabled: shown, child: _Tab(onLoad: () => loads++)));

    await tester.pumpWidget(shell(shown: true));
    expect(loads, 0);

    TripDataChanges.touch(const [EntityType.travel]);
    expect(loads, 0, reason: 'other kinds of data don\'t matter');
    TripDataChanges.touch(const [EntityType.receipt, EntityType.travel]);
    expect(loads, 1);

    await tester.pumpWidget(shell(shown: false));
    expect(loads, 1);
    await tester.pumpWidget(shell(shown: true));
    expect(loads, 2, reason: 'switching back to the tab refreshes it');

    await tester.pumpWidget(const SizedBox());
    TripDataChanges.touch(const [EntityType.receipt]);
    expect(loads, 2, reason: 'listener removed on dispose');
  });
}
