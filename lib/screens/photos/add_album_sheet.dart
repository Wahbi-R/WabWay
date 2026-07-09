import 'package:flutter/material.dart';
import '../../core/supabase/photo_album_service.dart';
import '../../data/photo_album_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';

Future<TripPhotoAlbum?> showAddAlbumSheet(
  BuildContext context, {
  required String tripId,
  required String userId,
}) {
  return showModalBottomSheet<TripPhotoAlbum>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AddAlbumSheet(
      tripId: tripId,
      userId: userId,
      onSubmit: (album) => Navigator.pop(ctx, album),
    ),
  );
}

class _AddAlbumSheet extends StatelessWidget {
  const _AddAlbumSheet({
    required this.tripId,
    required this.userId,
    required this.onSubmit,
  });
  final String tripId;
  final String userId;
  final ValueChanged<TripPhotoAlbum> onSubmit;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, ctrl) => DecoratedBox(
        decoration: const BoxDecoration(
          color: kColorPaper,
          borderRadius: kRadiusSheet,
        ),
        child: _AddAlbumContent(
          tripId: tripId,
          userId: userId,
          scrollController: ctrl,
          onSubmit: onSubmit,
        ),
      ),
    );
  }
}

class _AddAlbumContent extends StatefulWidget {
  const _AddAlbumContent({
    required this.tripId,
    required this.userId,
    required this.onSubmit,
    this.scrollController,
  });
  final String tripId;
  final String userId;
  final ValueChanged<TripPhotoAlbum> onSubmit;
  final ScrollController? scrollController;

  @override
  State<_AddAlbumContent> createState() => _AddAlbumContentState();
}

class _AddAlbumContentState extends State<_AddAlbumContent> {
  final _formKey  = GlobalKey<FormState>();
  final _urlCtrl  = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  AlbumService _service = AlbumService.other;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _urlCtrl.addListener(_onUrlChanged);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _onUrlChanged() {
    final url = _urlCtrl.text.trim();
    final detected = AlbumService.fromUrl(url);
    if (_titleCtrl.text.trim().isEmpty && url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      if (uri != null && uri.host.isNotEmpty) {
        final host = uri.host.replaceFirst(RegExp(r'^www\.'), '');
        _titleCtrl.text = host;
        _titleCtrl.selection = TextSelection.collapsed(offset: _titleCtrl.text.length);
      }
    }
    if (detected != _service) setState(() => _service = detected);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final album = await PhotoAlbumService.createAlbum(
        tripId:   widget.tripId,
        addedBy:  widget.userId,
        title:    _titleCtrl.text.trim(),
        url:      _urlCtrl.text.trim(),
        service:  _service,
        note:     _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      widget.onSubmit(album);
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
              Text('Add photo album', style: kStyleTitle),
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
                    label: 'Album link',
                    hint: 'https://photos.google.com/…',
                    controller: _urlCtrl,
                    prefixIcon: Icons.link_rounded,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Paste an album link';
                      final uri = Uri.tryParse(v.trim());
                      if (uri == null || !uri.hasScheme) return 'Enter a valid URL';
                      return null;
                    },
                  ),
                  const SizedBox(height: kSpace3),

                  // Service chip (auto-detected)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: kSpace3, vertical: 6),
                        decoration: BoxDecoration(
                          color: _service.softColor,
                          borderRadius: kRadiusPill,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_service.icon, size: 14, color: _service.color),
                            const SizedBox(width: 5),
                            Text(
                              _service.label,
                              style: kStyleCaption.copyWith(
                                  color: _service.color,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: kSpace2),
                      Text('auto-detected',
                          style: kStyleCaption.copyWith(color: kColorInkSoft)),
                    ],
                  ),
                  const SizedBox(height: kSpace4),

                  WabwayTextField(
                    label: 'Title',
                    hint: 'e.g. Japan 2026 — everyone\'s shots',
                    controller: _titleCtrl,
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                  ),
                  const SizedBox(height: kSpace4),

                  WabwayTextField(
                    label: 'Note (optional)',
                    hint: 'Any context for the group…',
                    controller: _noteCtrl,
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
                    label: 'Add album',
                    icon: Icons.add_photo_alternate_rounded,
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
