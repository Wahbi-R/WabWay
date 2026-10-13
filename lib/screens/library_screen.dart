import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/widgets.dart';
import 'docs_screen.dart';
import 'links_screen.dart';

/// Which half of the Library is showing (0 = Documents, 1 = Links).
final libraryTabProvider = StateProvider<int>((_) => 0);

/// One "Library" for everything saved to the trip: files and links. Each half
/// keeps its own search, filters and add action; the header title is the
/// shared [LibraryTabs] switcher. (Storage stays separate — documents and
/// trip_links — this is a single place to find them, not a data merge.)
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key, this.initialTab});

  /// Optional tab to show when pushed (e.g. from a "Links" shortcut).
  final int? initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (initialTab != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.read(libraryTabProvider) != initialTab) {
          ref.read(libraryTabProvider.notifier).state = initialTab!;
        }
      });
    }
    final tab = ref.watch(libraryTabProvider);
    return IndexedStack(
      index: tab,
      children: const [DocsScreen(), LinksScreen()],
    );
  }
}

/// Header title for the Library halves: Documents | Links.
class LibraryTabs extends ConsumerWidget {
  const LibraryTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => WabwaySegmentTabs<int>(
        tabs: const [
          (0, 'Documents', Icons.folder_rounded),
          (1, 'Links', Icons.link_rounded),
        ],
        selected: ref.watch(libraryTabProvider),
        onChanged: (i) => ref.read(libraryTabProvider.notifier).state = i,
      );
}
