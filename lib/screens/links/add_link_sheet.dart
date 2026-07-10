import 'package:flutter/material.dart';
import '../../core/place_search_service.dart';
import '../../core/supabase/links_service.dart';
import '../../data/links_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';

Future<TripLink?> showAddLinkSheet(
  BuildContext context, {
  required String tripId,
  required String userId,
  String? prefillUrl,
  String? prefillTitle,
  TripLink? existing,
}) {
  return showModalBottomSheet<TripLink>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AddLinkSheet(
      tripId: tripId,
      userId: userId,
      prefillUrl: prefillUrl,
      prefillTitle: prefillTitle,
      existing: existing,
      onSubmit: (link) => Navigator.pop(ctx, link),
    ),
  );
}

class _AddLinkSheet extends StatelessWidget {
  const _AddLinkSheet({
    required this.tripId,
    required this.userId,
    required this.onSubmit,
    this.prefillUrl,
    this.prefillTitle,
    this.existing,
  });
  final String tripId;
  final String userId;
  final ValueChanged<TripLink> onSubmit;
  final String? prefillUrl;
  final String? prefillTitle;
  final TripLink? existing;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, ctrl) => DecoratedBox(
        decoration: const BoxDecoration(
          color: kColorPaper,
          borderRadius: kRadiusSheet,
        ),
        child: _AddLinkContent(
          tripId: tripId,
          userId: userId,
          scrollController: ctrl,
          prefillUrl: prefillUrl,
          prefillTitle: prefillTitle,
          existing: existing,
          onSubmit: onSubmit,
        ),
      ),
    );
  }
}

class _AddLinkContent extends StatefulWidget {
  const _AddLinkContent({
    required this.tripId,
    required this.userId,
    required this.onSubmit,
    this.scrollController,
    this.prefillUrl,
    this.prefillTitle,
    this.existing,
  });
  final String tripId;
  final String userId;
  final ValueChanged<TripLink> onSubmit;
  final ScrollController? scrollController;
  final String? prefillUrl;
  final String? prefillTitle;
  final TripLink? existing;

  @override
  State<_AddLinkContent> createState() => _AddLinkContentState();
}

class _AddLinkContentState extends State<_AddLinkContent> {
  final _formKey   = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _notesCtrl;

  late LinkCategory _category;
  bool _loading = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _urlCtrl   = TextEditingController(text: ex?.url   ?? widget.prefillUrl   ?? '');
    _titleCtrl = TextEditingController(text: ex?.title ?? widget.prefillTitle ?? '');
    _notesCtrl = TextEditingController(text: ex?.notes ?? '');
    _category  = ex?.category ?? LinkCategory.general;
    _urlCtrl.addListener(_onUrlChanged);
    if (ex == null && widget.prefillUrl != null) _autoDetectCategory(widget.prefillUrl!);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _urlCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onUrlChanged() {
    final url = _urlCtrl.text.trim();
    _autoDetectCategory(url);
    // Auto-fill title from domain if title is empty
    if (_titleCtrl.text.trim().isEmpty && url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      if (uri != null && uri.host.isNotEmpty) {
        final host = uri.host.replaceFirst(RegExp(r'^www\.'), '');
        _titleCtrl.text = host;
        _titleCtrl.selection = TextSelection.collapsed(
            offset: _titleCtrl.text.length);
      }
    }
  }

  void _autoDetectCategory(String url) {
    final lower = url.toLowerCase();
    LinkCategory detected = LinkCategory.general;
    if (PlaceSearchService.isMapsUrl(url) ||
        lower.contains('tabelog') ||
        lower.contains('yelp') ||
        lower.contains('gurunavi') ||
        lower.contains('hotpepper')) {
      detected = LinkCategory.food;
    } else if (lower.contains('booking.com') ||
        lower.contains('airbnb') ||
        lower.contains('hotels.com') ||
        lower.contains('agoda') ||
        lower.contains('jalan.net')) {
      detected = LinkCategory.accommodation;
    } else if (lower.contains('instagram.com') ||
        lower.contains('tiktok.com') ||
        lower.contains('twitter.com') ||
        lower.contains('x.com') ||
        lower.contains('youtube.com') ||
        lower.contains('youtu.be')) {
      detected = LinkCategory.social;
    } else if (lower.contains('amazon') ||
        lower.contains('rakuten') ||
        lower.contains('shopping')) {
      detected = LinkCategory.shopping;
    }
    if (detected != _category) setState(() => _category = detected);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final TripLink link;
      if (_isEditing) {
        link = await LinksService.updateLink(
          widget.existing!.id,
          title:    _titleCtrl.text.trim(),
          url:      _urlCtrl.text.trim(),
          category: _category,
          notes:    _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );
      } else {
        link = await LinksService.createLink(
          tripId:   widget.tripId,
          addedBy:  widget.userId,
          title:    _titleCtrl.text.trim(),
          url:      _urlCtrl.text.trim(),
          category: _category,
          notes:    _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );
      }
      widget.onSubmit(link);
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.viewInsetsOf(context).bottom;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const WabwayDragHandle(),
        Padding(
          padding: const EdgeInsets.fromLTRB(kSpace4, kSpace2, kSpace4, 0),
          child: Row(
            children: [
              Text(_isEditing ? 'Edit link' : 'Save a link', style: kStyleTitle),
              const Spacer(),
              WabwayIconButton(
                icon: Icons.close_rounded,
                label: 'Cancel',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        const Divider(height: kSpace5),
        Flexible(
          child: SingleChildScrollView(
            controller: widget.scrollController,
            padding: EdgeInsets.fromLTRB(kSpace4, 0, kSpace4, kSpace6 + bottomPad),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WabwayTextField(
                    label: 'URL',
                    hint: 'https://…',
                    controller: _urlCtrl,
                    prefixIcon: Icons.link_rounded,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'URL is required';
                      final uri = Uri.tryParse(v.trim());
                      if (uri == null || !uri.hasScheme) return 'Enter a valid URL';
                      return null;
                    },
                  ),
                  const SizedBox(height: kSpace4),
                  WabwayTextField(
                    label: 'Title',
                    hint: 'e.g. Ichiran Ramen menu',
                    controller: _titleCtrl,
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                  ),
                  const SizedBox(height: kSpace4),

                  // Category chips
                  Text('Category',
                      style: kStyleCaptionMedium.copyWith(color: kColorInk)),
                  const SizedBox(height: kSpace2),
                  Wrap(
                    spacing: kSpace2,
                    runSpacing: kSpace2,
                    children: LinkCategory.values.map((cat) {
                      final selected = _category == cat;
                      return GestureDetector(
                        onTap: () => setState(() => _category = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: kSpace3, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected ? cat.color : kColorSurfaceSunken,
                            borderRadius: kRadiusMd,
                            border: Border.all(
                              color: selected ? cat.color : kColorBorder,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(cat.icon,
                                  size: 14,
                                  color: selected ? Colors.white : kColorInkSoft),
                              const SizedBox(width: 4),
                              Text(
                                cat.label,
                                style: kStyleCaption.copyWith(
                                  color: selected ? Colors.white : kColorInk,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: kSpace4),

                  WabwayTextField(
                    label: 'Notes (optional)',
                    hint: 'Any context for the group…',
                    controller: _notesCtrl,
                    maxLines: 3,
                    textInputAction: TextInputAction.newline,
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: kSpace3),
                    Text(_error!,
                        style: kStyleCaption.copyWith(color: kColorDanger)),
                  ],
                  const SizedBox(height: kSpace6),
                  WabwayButton(
                    label: _isEditing ? 'Save changes' : 'Save link',
                    icon: _isEditing ? Icons.check_rounded : Icons.bookmark_add_rounded,
                    fullWidth: true,
                    size: WabwayButtonSize.lg,
                    loading: _loading,
                    onPressed: _loading ? null : _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
