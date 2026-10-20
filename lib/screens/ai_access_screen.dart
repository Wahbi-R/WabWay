import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/async_screen_mixin.dart';
import '../core/supabase/ai_access_service.dart';
import '../data/ai_access_data.dart';
import '../data/date_utils.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';
import '../widgets/wabway_button.dart';
import '../widgets/wabway_confirm_dialog.dart';
import '../widgets/wabway_detail_widgets.dart';
import '../widgets/wabway_empty_state.dart';
import '../widgets/wabway_error_state.dart';
import '../widgets/wabway_form_sheet.dart';
import '../widgets/wabway_snack.dart';

/// More → AI access: personal access tokens that let Claude, ChatGPT and
/// other MCP clients read your trips through wabway-server's `/mcp`.
class AiAccessScreen extends StatefulWidget {
  const AiAccessScreen({super.key});

  @override
  State<AiAccessScreen> createState() => _AiAccessScreenState();
}

class _AiAccessScreenState extends State<AiAccessScreen> with AsyncScreenMixin {
  List<AiAccessToken> _tokens = [];
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    final gen = beginLoad(silent: silent);
    try {
      final tokens = await AiAccessService.load();
      commitLoad(gen, () => _tokens = tokens);
    } catch (_) {
      failLoad(gen, silent: silent);
    }
  }

  Future<void> _create() async {
    final name = await showWabwayTextPrompt(
      context,
      title: 'Name this token',
      initialValue: 'Claude',
      hint: 'e.g. Claude, ChatGPT',
      helper: 'So you can tell your tokens apart later.',
      maxLength: 60,
      confirmLabel: 'Create',
    );
    if (name == null || !mounted) return;
    // Cancel / dismiss = read only, the safe default.
    final canWrite = await showWabwayConfirm(
      context,
      title: 'What can "$name" do?',
      message: 'Read only: look up your trips, bookings, plans and documents.\n\n'
          'Add & edit: also add flights, stays, plan items, spots and links from '
          'things you share with it, and fix what it added. Your crew sees '
          'everything it adds, and you can ask it to undo its changes.',
      confirmLabel: 'Add & edit',
      cancelLabel: 'Read only',
      destructive: false,
    );
    if (!mounted) return;
    setState(() => _creating = true);
    try {
      final token = await AiAccessService.create(name, canWrite: canWrite);
      if (!mounted) return;
      setState(() => _creating = false);
      await _load(silent: true);
      if (!mounted) return;
      await showWabwayAutoSheet<void>(
        context,
        builder: (ctx, handle) => _NewTokenSheet(
          token: token,
          mcpUrl: AiAccessService.mcpUrl,
          canWrite: canWrite,
          showDragHandle: handle,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      showWabwaySnack(
        context,
        e.toString().contains('too_many_tokens')
            ? 'You can have up to 10 tokens — revoke one first.'
            : "Couldn't create a token. Check your connection and try again.",
        error: true,
      );
    }
  }

  Future<void> _revoke(AiAccessToken t) async {
    final ok = await showWabwayConfirm(
      context,
      title: 'Revoke "${t.name}"?',
      message: 'Any AI assistant using this token loses access to your trips '
          'within a minute. This cannot be undone.',
      confirmLabel: 'Revoke',
    );
    if (!ok || !mounted) return;
    try {
      await AiAccessService.revoke(t.id);
      if (!mounted) return;
      setState(() => _tokens = _tokens.where((x) => x.id != t.id).toList());
      showWabwaySnack(context, 'Token revoked');
    } catch (_) {
      if (mounted) showWabwaySnack(context, "Couldn't revoke the token.", error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        title: Text('AI access', style: kStyleTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: kColorInkSoft,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: ListView(
          padding: const EdgeInsets.all(kSpace4),
          children: [
            Text(
              'Let Claude, ChatGPT and other AI assistants look up your bookings, '
              'plans and documents directly — no more screenshots. Tokens are read '
              'only unless you let one add & edit, so it can put a booking '
              'confirmation or itinerary you share with it straight into WabWay.',
              style: kStyleBody.copyWith(color: kColorInkSoft),
            ),
            const SizedBox(height: kSpace2),
            Text(
              'A token can read every trip you\'re in. Treat it like a password.',
              style: kStyleCaption,
            ),
            if (AiAccessService.mcpUrl.isEmpty) ...[
              const SizedBox(height: kSpace2),
              Text(
                'This build has no server URL, so AI assistants can\'t connect yet.',
                style: kStyleCaption.copyWith(color: kColorDanger),
              ),
            ],
            const SizedBox(height: kSpace5),
            WabwayButton(
              label: 'Create access token',
              icon: Icons.key_rounded,
              fullWidth: true,
              loading: _creating,
              onPressed: _create,
            ),
            const SizedBox(height: kSpace6),
            Text('Active tokens', style: kStyleOverline),
            const SizedBox(height: kSpace3),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(kSpace8),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (error)
              WabwayErrorState(
                action: WabwayButton(
                  label: 'Try again',
                  variant: WabwayButtonVariant.secondary,
                  onPressed: _load,
                ),
              )
            else if (_tokens.isEmpty)
              const WabwayEmptyState(
                icon: Icons.smart_toy_rounded,
                title: 'No tokens yet',
                description: 'Create one, then paste it into your AI assistant.',
              )
            else
              DecoratedBox(
                decoration: kCardDecoration(),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    children: [
                      for (var i = 0; i < _tokens.length; i++) ...[
                        if (i > 0) const Divider(height: 1, indent: kSpace4),
                        _TokenRow(token: _tokens[i], onRevoke: () => _revoke(_tokens[i])),
                      ],
                    ],
                  ),
                ),
              ),
            const SizedBox(height: kSpace16),
          ],
        ),
      ),
    );
  }
}

class _TokenRow extends StatelessWidget {
  const _TokenRow({required this.token, required this.onRevoke});
  final AiAccessToken token;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final used = token.lastUsedAt == null
        ? 'Never used'
        : 'Last used ${fmtDate(token.lastUsedAt!)}';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: kSpace4, vertical: kSpace1),
      leading: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(color: kColorPrimarySoft, borderRadius: kRadiusMd),
        child: const Icon(Icons.key_rounded, size: 20, color: kColorPrimaryDark),
      ),
      title: Text(token.name, style: kStyleBodyMedium),
      subtitle: Text(
        '${token.canWrite ? 'Can add & edit' : 'Read only'} · ${token.prefix}… · '
        'Created ${fmtDate(token.createdAt)} · $used',
        style: kStyleCaption,
      ),
      trailing: IconButton(
        tooltip: 'Revoke',
        icon: const Icon(Icons.delete_outline_rounded, color: kColorDanger),
        onPressed: onRevoke,
      ),
    );
  }
}

/// Shown once after creating a token: the token itself plus copy-ready setup
/// for each assistant. The plaintext is never retrievable again.
class _NewTokenSheet extends StatelessWidget {
  const _NewTokenSheet({
    required this.token,
    required this.mcpUrl,
    required this.canWrite,
    required this.showDragHandle,
  });
  final String token;
  final String mcpUrl;
  final bool canWrite;
  final bool showDragHandle;

  @override
  Widget build(BuildContext context) {
    final connectorUrl = '$mcpUrl?token=$token';
    final claudeCode =
        'claude mcp add --transport http wabway $mcpUrl --header "Authorization: Bearer $token"';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(kSpace5, kSpace2, kSpace5, kSpace6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDragHandle) const WabwayDragHandle(),
          const SizedBox(height: kSpace2),
          Text('Your access token', style: kStyleTitle),
          const SizedBox(height: kSpace1),
          Text(
            'Copy it now — you won\'t be able to see it again.',
            style: kStyleCaption.copyWith(color: kColorDanger),
          ),
          const SizedBox(height: kSpace3),
          _CopyBlock(value: token, copiedMessage: 'Token copied'),
          if (mcpUrl.isNotEmpty) ...[
            const SizedBox(height: kSpace6),
            Text('Claude — web, desktop and phone', style: kStyleBodySemibold),
            const SizedBox(height: kSpace1),
            Text(
              'Settings → Connectors → Add custom connector. Name it WabWay and '
              'paste this as the URL:',
              style: kStyleCaption,
            ),
            const SizedBox(height: kSpace2),
            _CopyBlock(value: connectorUrl, copiedMessage: 'Connector URL copied'),
            const SizedBox(height: kSpace5),
            Text('ChatGPT', style: kStyleBodySemibold),
            const SizedBox(height: kSpace1),
            Text(
              'Settings → Apps & Connectors → turn on Developer mode, then Create '
              'a connector with the same URL as above and no authentication.',
              style: kStyleCaption,
            ),
            const SizedBox(height: kSpace5),
            Text('Claude Code', style: kStyleBodySemibold),
            const SizedBox(height: kSpace1),
            Text('Run this in a terminal:', style: kStyleCaption),
            const SizedBox(height: kSpace2),
            _CopyBlock(value: claudeCode, copiedMessage: 'Command copied'),
            const SizedBox(height: kSpace5),
            Text(
              canWrite
                  ? 'Then just ask, e.g. "What\'s my hotel confirmation number in Kyoto?", '
                    'or share a booking email or PDF and say "add this to my Japan trip".'
                  : 'Then just ask, e.g. "What\'s my hotel confirmation number in Kyoto?" '
                    'or "Show me my JR pass".',
              style: kStyleCaption,
            ),
          ],
          const SizedBox(height: kSpace6),
          WabwayButton(
            label: 'Done',
            variant: WabwayButtonVariant.secondary,
            fullWidth: true,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _CopyBlock extends StatelessWidget {
  const _CopyBlock({required this.value, required this.copiedMessage});
  final String value;
  final String copiedMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(kSpace3, kSpace2, kSpace1, kSpace2),
      decoration: BoxDecoration(
        color: kColorSurfaceSunken,
        borderRadius: kRadiusMd,
        border: Border.all(color: kColorBorder),
      ),
      child: Row(
        children: [
          Expanded(child: SelectableText(value, style: kStyleMonoSm)),
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy_rounded, size: 18, color: kColorInkSoft),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (context.mounted) showWabwaySnack(context, copiedMessage);
            },
          ),
        ],
      ),
    );
  }
}
