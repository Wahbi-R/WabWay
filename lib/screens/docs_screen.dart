import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../data/docs_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';
import '../widgets/widgets.dart';
import 'docs/doc_card.dart';
import 'docs/doc_detail.dart';
import 'docs/add_doc_sheet.dart';

class DocsScreen extends StatefulWidget {
  const DocsScreen({super.key});

  @override
  State<DocsScreen> createState() => _DocsScreenState();
}

class _DocsScreenState extends State<DocsScreen> {
  final List<TripDocument> _docs = List.from(kMockDocuments);
  String? _selectedDocId;
  DocType? _filterType;
  String _search = '';

  final _searchCtrl = TextEditingController();
  final _filterScrollCtrl = ScrollController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _filterScrollCtrl.dispose();
    super.dispose();
  }

  TripDocument? get _selectedDoc =>
      _selectedDocId == null
          ? null
          : _docs.where((d) => d.id == _selectedDocId).firstOrNull;

  List<TripDocument> get _filtered {
    final q = _search.toLowerCase().trim();
    return _docs.where((d) {
      final matchType = _filterType == null || d.type == _filterType;
      final matchSearch = q.isEmpty ||
          d.title.toLowerCase().contains(q) ||
          d.type.label.toLowerCase().contains(q) ||
          d.uploadedBy.toLowerCase().contains(q);
      return matchType && matchSearch;
    }).toList();
  }

  void _addDoc(BuildContext context) async {
    final doc = await showAddDocSheet(context);
    if (doc != null && mounted) {
      setState(() {
        _docs.insert(0, doc);
        _selectedDocId = doc.id;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
    return isDesktop ? _buildDesktop(context) : _buildMobile(context);
  }

  // ─── Desktop ──────────────────────────────────────────────────────────────────

  Widget _buildDesktop(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      body: Column(
        children: [
          _DesktopDocsBar(
            onSearchChanged: (v) => setState(() => _search = v),
            onAdd: () => _addDoc(context),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 360,
                  child: Column(
                    children: [
                      _FilterStrip(
                        selected: _filterType,
                        onSelect: (t) => setState(() {
                          _filterType = _filterType == t ? null : t;
                        }),
                        scrollController: _filterScrollCtrl,
                      ),
                      Expanded(child: _buildDesktopList()),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1, color: kColorBorder),
                Expanded(child: _buildDesktopDetail()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopList() {
    final items = _filtered;
    if (items.isEmpty) {
      return Center(
        child: WabwayEmptyState(
          icon: Icons.folder_open_rounded,
          title: _search.isNotEmpty ? 'No results' : 'No documents',
          description: _search.isNotEmpty
              ? 'Try a different search term.'
              : 'Upload your first document.',
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(kSpace3),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: kSpace2),
      itemBuilder: (_, i) => DocListRow(
        doc: items[i],
        selected: _selectedDocId == items[i].id,
        onTap: () => setState(() => _selectedDocId = items[i].id),
      ),
    );
  }

  Widget _buildDesktopDetail() {
    final doc = _selectedDoc;
    if (doc == null) {
      return const Center(
        child: WabwayEmptyState(
          icon: Icons.insert_drive_file_rounded,
          title: 'Select a document',
          description: 'Click any document in the list to view details.',
        ),
      );
    }
    return SingleChildScrollView(
      child: DocDetailContent(key: ValueKey(doc.id), doc: doc),
    );
  }

  // ─── Mobile ───────────────────────────────────────────────────────────────────

  Widget _buildMobile(BuildContext context) {
    final items = _filtered;
    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        title: Text('Documents', style: kStyleTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            color: kColorInkSoft,
            onPressed: () => _addDoc(context),
          ),
          const SizedBox(width: kSpace2),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(kSpace4, 0, kSpace4, kSpace3),
            child: WabwayTextField(
              hint: 'Search documents…',
              prefixIcon: Icons.search_rounded,
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _FilterStrip(
            selected: _filterType,
            onSelect: (t) => setState(() {
              _filterType = _filterType == t ? null : t;
            }),
            scrollController: _filterScrollCtrl,
          ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: WabwayEmptyState(
                      icon: Icons.folder_open_rounded,
                      title: _search.isNotEmpty ? 'No results' : 'No documents',
                      description: _search.isNotEmpty
                          ? 'Try a different search term.'
                          : 'Tap + to upload your first document.',
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(kSpace3),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: kSpace3,
                      mainAxisSpacing: kSpace3,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: items.length,
                    itemBuilder: (ctx, i) => DocGridCard(
                      doc: items[i],
                      onTap: () => Navigator.push(
                        ctx,
                        MaterialPageRoute(
                          builder: (_) => DocDetailScreen(doc: items[i]),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'docs_fab',
        onPressed: () => _addDoc(context),
        icon: const Icon(Icons.upload_file_rounded),
        label: Text(
          'Add document',
          style: kStyleButtonMd.copyWith(color: kColorTextOnPrimary),
        ),
      ),
    );
  }
}

// ─── Desktop top bar ──────────────────────────────────────────────────────────

class _DesktopDocsBar extends StatelessWidget {
  const _DesktopDocsBar({
    required this.onSearchChanged,
    required this.onAdd,
  });

  final ValueChanged<String> onSearchChanged;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kTopBarHeight,
      decoration: const BoxDecoration(
        color: kColorBgRaised,
        border: Border(bottom: BorderSide(color: kColorBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: kSpace4),
      child: Row(
        children: [
          Text('Documents', style: kStyleTitle),
          const SizedBox(width: kSpace6),
          SizedBox(
            width: 260,
            child: WabwayTextField(
              hint: 'Search documents…',
              prefixIcon: Icons.search_rounded,
              onChanged: onSearchChanged,
            ),
          ),
          const Spacer(),
          WabwayButton(
            label: 'Add document',
            icon: Icons.upload_file_rounded,
            size: WabwayButtonSize.sm,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

// ─── Filter strip ─────────────────────────────────────────────────────────────

class _FilterStrip extends StatelessWidget {
  const _FilterStrip({
    required this.selected,
    required this.onSelect,
    required this.scrollController,
  });

  final DocType? selected;
  final ValueChanged<DocType> onSelect;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: kColorBgRaised,
        border: Border(bottom: BorderSide(color: kColorBorder)),
      ),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
          },
        ),
        child: ListView.separated(
          controller: scrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: kSpace2),
          itemCount: DocType.values.length,
          separatorBuilder: (_, __) => const SizedBox(width: kSpace1),
          itemBuilder: (_, i) {
            final type = DocType.values[i];
            return _FilterChip(
              label: type.label,
              icon: type.icon,
              color: type.color,
              selected: selected == type,
              onTap: () => onSelect(type),
            );
          },
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: kSpace3),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: kRadiusPill,
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.4) : kColorBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: selected ? color : kColorInkSoft),
            const SizedBox(width: kSpace1),
            Text(
              label,
              style: kStyleCaptionMedium.copyWith(
                color: selected ? color : kColorInkSoft,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
