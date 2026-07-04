import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/supabase/client.dart';
import '../../core/supabase/doc_service.dart';
import '../../data/docs_data.dart';
import '../../data/money_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';

// ─── Confirmation helper ──────────────────────────────────────────────────────

Future<bool> _confirmDelete(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete withdrawal?'),
          content: const Text(
              'This will permanently remove this ATM withdrawal for everyone in the trip.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: kColorDanger)),
            ),
          ],
        ),
      ) ??
      false;
}

// ─── Mobile full-screen route ─────────────────────────────────────────────────

class CashDetailScreen extends StatelessWidget {
  const CashDetailScreen({
    super.key,
    required this.withdrawal,
    required this.myId,
    required this.members,
    required this.tripId,
    this.onDelete,
  });

  final CashWithdrawal withdrawal;
  final String myId;
  final List<TripMember> members;
  final String tripId;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: kColorInkSoft,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('ATM Withdrawal', style: kStyleTitle),
        actions: [
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              color: kColorDanger,
              onPressed: () async {
                final ok = await _confirmDelete(context);
                if (ok && context.mounted) {
                  Navigator.pop(context);
                  onDelete!();
                }
              },
            ),
          const SizedBox(width: kSpace2),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: kSpace12 + MediaQuery.paddingOf(context).bottom),
        child: CashDetailContent(
          withdrawal: withdrawal,
          myId:       myId,
          members:    members,
          tripId:     tripId,
        ),
      ),
    );
  }
}

// ─── Shared content ───────────────────────────────────────────────────────────

class CashDetailContent extends StatelessWidget {
  const CashDetailContent({
    super.key,
    required this.withdrawal,
    required this.myId,
    required this.members,
    required this.tripId,
    this.onDelete,
  });

  final CashWithdrawal withdrawal;
  final String myId;
  final List<TripMember> members;
  final String tripId;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final who = memberById(withdrawal.withdrawnById, members);
    final net = withdrawal.myNetFor(myId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header band
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(kSpace6),
          decoration: const BoxDecoration(color: kColorAccentSoft),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(kSpace2),
                    decoration: BoxDecoration(
                      color: kColorAccent.withValues(alpha: 0.15),
                      borderRadius: kRadiusMd,
                    ),
                    child: const Icon(Icons.atm_rounded, size: 20, color: kColorAccent),
                  ),
                  const SizedBox(width: kSpace3),
                  const WabwayTag(label: 'Cash / ATM'),
                ],
              ),
              const SizedBox(height: kSpace3),
              Text('ATM Withdrawal', style: kStyleHeadingSm),
              const SizedBox(height: kSpace1),
              Text(fmtDate(withdrawal.date), style: kStyleCaption),
              const SizedBox(height: kSpace4),
              Text(
                fmtAmount(withdrawal.amount, withdrawal.currency),
                style: GoogleFonts.ibmPlexMono(
                  fontSize: kText3xl,
                  fontWeight: FontWeight.w700,
                  color: kColorInk,
                ),
              ),
              if (withdrawal.atmFee > 0) ...[
                const SizedBox(height: kSpace1),
                Text(
                  '+ ${fmtAmount(withdrawal.atmFee, withdrawal.currency)} ATM fee',
                  style: kStyleCaption,
                ),
              ],
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(kSpace4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Withdrawn by
              Row(
                children: [
                  const Icon(Icons.person_rounded, size: 16, color: kColorInkSoft),
                  const SizedBox(width: kSpace2),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Withdrawn by', style: kStyleCaption),
                      Text(who.name, style: kStyleBodyMedium),
                    ],
                  ),
                ],
              ),

              if (net.abs() > 0.01) ...[
                const SizedBox(height: kSpace3),
                Row(
                  children: [
                    Icon(
                      net > 0 ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                      size: 16,
                      color: kColorInkSoft,
                    ),
                    const SizedBox(width: kSpace2),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(net > 0 ? 'You are owed' : 'You owe', style: kStyleCaption),
                        Text(
                          fmtAmount(net.abs(), withdrawal.currency),
                          style: kStyleBodyMedium.copyWith(
                              color: net > 0 ? kColorSuccess : kColorDanger),
                        ),
                      ],
                    ),
                  ],
                ),
              ],

              if (withdrawal.notes != null) ...[
                const SizedBox(height: kSpace3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notes_rounded, size: 16, color: kColorInkSoft),
                    const SizedBox(width: kSpace2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Notes', style: kStyleCaption),
                          Text(withdrawal.notes!, style: kStyleBodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: kSpace5),
              const Divider(height: 1),
              const SizedBox(height: kSpace5),

              // Distribution table
              Text('Cash distributed', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
              const SizedBox(height: kSpace3),
              ...withdrawal.distributions.map((d) => _DistRow(
                    dist:     d,
                    currency: withdrawal.currency,
                    members:  members,
                  )),

              const SizedBox(height: kSpace5),
              const Divider(height: 1),
              const SizedBox(height: kSpace5),

              _AttachSection(
                withdrawalId: withdrawal.id,
                tripId:       tripId,
                label:        'ATM Withdrawal',
              ),

              if (onDelete != null) ...[
                const SizedBox(height: kSpace5),
                WabwayButton(
                  label: 'Delete withdrawal',
                  icon: Icons.delete_outline_rounded,
                  variant: WabwayButtonVariant.ghost,
                  fullWidth: true,
                  onPressed: () async {
                    final ok = await _confirmDelete(context);
                    if (ok && context.mounted) onDelete!();
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─── ATM slip attachment section ──────────────────────────────────────────────

class _AttachSection extends StatefulWidget {
  const _AttachSection({
    required this.withdrawalId,
    required this.tripId,
    required this.label,
  });

  final String withdrawalId;
  final String tripId;
  final String label;

  @override
  State<_AttachSection> createState() => _AttachSectionState();
}

class _AttachSectionState extends State<_AttachSection> {
  List<TripDocument>? _docs;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final docs = await DocService.loadLinkedDocuments(
        linkedType: DocLinkedType.cashWithdrawal,
        linkedId:   widget.withdrawalId,
      );
      if (mounted) setState(() => _docs = docs);
    } catch (_) {
      if (mounted) setState(() => _docs = []);
    }
  }

  Future<void> _open(TripDocument doc) async {
    if (doc.storagePath == null) return;
    final url = await DocService.getSignedUrl(doc.storagePath!);
    if (url == null) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    Navigator.pop(context);
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    final ext   = picked.path.split('.').last.toLowerCase();
    final userId = supabase.auth.currentUser?.id ?? '';

    setState(() => _uploading = true);
    try {
      final doc = await DocService.uploadAndCreate(
        tripId:     widget.tripId,
        userId:     userId,
        title:      widget.label,
        type:       DocType.receipt,
        ext:        ext.isNotEmpty ? ext : 'jpg',
        bytes:      bytes,
        fileSizeKb: (bytes.lengthInBytes / 1024).round(),
      );
      await DocService.addLink(
        documentId: doc.id,
        linkedType: DocLinkedType.cashWithdrawal,
        linkedId:   widget.withdrawalId,
        createdBy:  userId,
      );
      if (mounted) {
        setState(() {
          _docs = [...?_docs, doc];
          _uploading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showPickerSheet() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: kColorPaper,
      shape: const RoundedRectangleBorder(borderRadius: kRadiusSheet),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, kSpace6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const WabwayDragHandle(),
            const SizedBox(height: kSpace3),
            Text('Attach ATM slip', style: kStyleTitle),
            const SizedBox(height: kSpace4),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: kColorInkSoft),
              title: Text('Take photo', style: kStyleBodyMedium),
              onTap: () => _pickAndUpload(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: kColorInkSoft),
              title: Text('Choose from gallery', style: kStyleBodyMedium),
              onTap: () => _pickAndUpload(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docs = _docs ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (docs.isNotEmpty) ...[
          Text('ATM slip', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
          const SizedBox(height: kSpace3),
          ...docs.map((doc) => Padding(
            padding: const EdgeInsets.only(bottom: kSpace2),
            child: _DocRow(doc: doc, onTap: () => _open(doc)),
          )),
          const SizedBox(height: kSpace3),
        ],

        // Attach tap zone
        GestureDetector(
          onTap: _uploading ? null : _showPickerSheet,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: kSpace5),
            decoration: BoxDecoration(
              color: kColorSurfaceSunken,
              borderRadius: kRadiusMd,
              border: Border.all(
                color: _uploading ? kColorPrimary : kColorBorder,
                width: 1.5,
              ),
            ),
            child: _uploading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(kColorPrimary),
                      ),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_photo_alternate_rounded,
                          size: 28, color: kColorInkSoft),
                      const SizedBox(height: kSpace2),
                      Text(
                        docs.isEmpty ? 'Attach ATM slip' : 'Attach another',
                        style: kStyleBodyMedium.copyWith(color: kColorInkSoft),
                      ),
                      const SizedBox(height: kSpace1),
                      Text('Take a photo or choose from gallery',
                          style: kStyleCaption),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({required this.doc, required this.onTap});
  final TripDocument doc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: doc.storagePath != null ? onTap : null,
      borderRadius: kRadiusMd,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: kSpace3),
        decoration: BoxDecoration(
          color: kColorSurfaceSunken,
          borderRadius: kRadiusMd,
          border: Border.all(color: kColorBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.receipt_long_rounded, size: 18, color: kColorInkSoft),
            const SizedBox(width: kSpace3),
            Expanded(
              child: Text(doc.title, style: kStyleBodyMedium,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (doc.storagePath != null)
              const Icon(Icons.open_in_new_rounded, size: 16, color: kColorInkSoft),
          ],
        ),
      ),
    );
  }
}

// ─── Distribution row ─────────────────────────────────────────────────────────

class _DistRow extends StatelessWidget {
  const _DistRow({required this.dist, required this.currency, required this.members});
  final CashDistribution dist;
  final String currency;
  final List<TripMember> members;

  @override
  Widget build(BuildContext context) {
    final member = memberById(dist.memberId, members);
    return Padding(
      padding: const EdgeInsets.only(bottom: kSpace3),
      child: Row(
        children: [
          WabwayAvatar(name: member.name, size: WabwayAvatarSize.sm),
          const SizedBox(width: kSpace3),
          Expanded(
            child: Text(member.name, style: kStyleBodyMedium),
          ),
          Text(
            fmtAmount(dist.amount, currency),
            style: GoogleFonts.ibmPlexMono(
              fontSize: kTextSm,
              fontWeight: FontWeight.w500,
              color: kColorInk,
            ),
          ),
        ],
      ),
    );
  }
}
