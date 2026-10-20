import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/money_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../core/text_utils.dart';
import '../../widgets/widgets.dart';

/// Edit an itemized bill and who had what — the same split the Receipts site
/// does, inside WabWay and fully offline. Returns the edited itemization, or
/// null when cancelled.
Future<ReceiptItemization?> showReceiptItemsEditor(
  BuildContext context, {
  required ReceiptItemization initial,
  required List<TripMember> members,
  required String currency,
}) {
  return showWabwayFormSheet<ReceiptItemization>(
    context,
    desktopHeightFactor: 0.92,
    initialChildSize: 0.95,
    minChildSize: 0.6,
    maxChildSize: 0.97,
    builder: (ctx, scroll, handle, close) => _ItemsEditor(
      initial: initial,
      members: members,
      currency: currency,
      scrollController: scroll,
      showDragHandle: handle,
      onDone: close,
    ),
  );
}

class _ItemsEditor extends StatefulWidget {
  const _ItemsEditor({
    required this.initial,
    required this.members,
    required this.currency,
    required this.onDone,
    this.scrollController,
    this.showDragHandle = false,
  });

  final ReceiptItemization initial;
  final List<TripMember> members;
  final String currency;
  final void Function([ReceiptItemization? result]) onDone;
  final ScrollController? scrollController;
  final bool showDragHandle;

  @override
  State<_ItemsEditor> createState() => _ItemsEditorState();
}

class _ItemsEditorState extends State<_ItemsEditor> {
  late ReceiptItemization _it =
      widget.initial.keepMembers({for (final m in widget.members) m.id});

  Iterable<String> get _ids => widget.members.map((m) => m.id);
  String _fmt(double v) => fmtAmount(v, widget.currency);
  void _set(ReceiptItemization next) => setState(() => _it = next);

  Future<void> _editItem(ReceiptItem? item) async {
    final result = await showWabwayAutoSheet<_ItemEdit>(
      context,
      builder: (ctx, handle) => _ItemForm(item: item, currency: widget.currency, showDragHandle: handle),
    );
    if (result == null) return;
    if (result.delete && item != null) {
      _set(_it.removeItem(item.id));
    } else if (item == null) {
      _set(_it.addItem(name: result.name, quantity: result.quantity, totalPrice: result.price));
    } else {
      _set(_it.updateItem(item.copyWith(
          name: result.name, quantity: result.quantity, totalPrice: result.price)));
    }
  }

  Future<void> _editExtras() async {
    final result = await showWabwayAutoSheet<(double, double, double)>(
      context,
      builder: (ctx, handle) => _ExtrasForm(it: _it, showDragHandle: handle),
    );
    if (result != null) _set(_it.copyWith(tax: result.$1, tip: result.$2, discount: result.$3));
  }

  Future<void> _editPortions(ReceiptItem item) async {
    final result = await showWabwayAutoSheet<Map<String, double>>(
      context,
      builder: (ctx, handle) => _PortionsForm(
        item: item,
        members: widget.members,
        weights: _it.weightsFor(item.id),
        showDragHandle: handle,
      ),
    );
    if (result == null) return;
    var next = _it;
    for (final m in widget.members) {
      next = next.setWeight(item.id, m.id, result[m.id] ?? 0);
    }
    _set(next);
  }

  @override
  Widget build(BuildContext context) {
    final navBarPad = MediaQuery.paddingOf(context).bottom;
    final totals = _it.personTotals(_ids);
    final unclaimed = _it.unclaimedTotal;
    final shares = _it.itemSharesByMember();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showDragHandle) const WabwayDragHandle(),
        Padding(
          padding: const EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Split by item', style: kStyleTitle),
                    Text('Tap who had each item', style: kStyleCaption),
                  ],
                ),
              ),
              WabwayIconButton(
                icon: Icons.close_rounded,
                label: 'Cancel',
                onPressed: () => widget.onDone(),
              ),
            ],
          ),
        ),
        const Divider(height: kSpace5),
        Flexible(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(kSpace4, 0, kSpace4, kSpace4),
            children: [
              if (_it.subtotalMismatch)
                _Notice(
                  icon: Icons.warning_amber_rounded,
                  color: kColorWarning,
                  soft: kColorWarningSoft,
                  text: 'Items add up to ${_fmt(_it.itemsTotal)} but the receipt says '
                      '${_fmt(_it.subtotal)} — check for a missed or misread line.',
                ),
              if (_it.items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: kSpace3),
                  child: Wrap(
                    spacing: kSpace2,
                    runSpacing: kSpace2,
                    children: [
                      WabwayButton(
                        label: 'Everyone shares all',
                        icon: Icons.groups_rounded,
                        size: WabwayButtonSize.sm,
                        variant: WabwayButtonVariant.secondary,
                        onPressed: () => _set(_it.assignAll(_ids)),
                      ),
                      if (unclaimed > 0.005)
                        WabwayButton(
                          label: 'Split leftovers equally',
                          icon: Icons.call_split_rounded,
                          size: WabwayButtonSize.sm,
                          variant: WabwayButtonVariant.ghost,
                          onPressed: () => _set(_it.assignUnclaimed(_ids)),
                        ),
                    ],
                  ),
                ),
              if (_it.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: kSpace6),
                  child: WabwayEmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: 'No items yet',
                    description: 'Scan the receipt, or add each line by hand.',
                  ),
                ),
              for (final item in _it.items) ...[
                _ItemRow(
                  item: item,
                  weights: _it.weightsFor(item.id),
                  members: widget.members,
                  currency: widget.currency,
                  onEdit: () => _editItem(item),
                  onToggle: (memberId) => _set(_it.toggle(item.id, memberId)),
                  onPortions: () => _editPortions(item),
                ),
                const Divider(height: 1),
              ],
              const SizedBox(height: kSpace3),
              WabwayButton(
                label: 'Add item',
                icon: Icons.add_rounded,
                variant: WabwayButtonVariant.ghost,
                fullWidth: true,
                onPressed: () => _editItem(null),
              ),
              const SizedBox(height: kSpace4),
              WabwayCard(
                onTap: _editExtras,
                padding: const EdgeInsets.all(kSpace3),
                child: Column(
                  children: [
                    _AmountLine('Items', _fmt(_it.itemsTotal)),
                    _AmountLine('Tax', _fmt(_it.tax)),
                    _AmountLine('Tip / service', _fmt(_it.tip)),
                    if (_it.discount > 0) _AmountLine('Discount', '−${_fmt(_it.discount)}'),
                    const Divider(height: kSpace4),
                    _AmountLine('Total', _fmt(_it.total), bold: true),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text('Tap to edit tax, tip & discount',
                          style: kStyleCaption.copyWith(color: kColorInkSoft)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: kSpace5),
              Text('Each person owes', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
              const SizedBox(height: kSpace2),
              for (final m in widget.members)
                _PersonTotal(
                  member: m,
                  total: totals[m.id] ?? 0,
                  itemCount: shares[m.id]?.length ?? 0,
                  currency: widget.currency,
                ),
              if (_it.extras.abs() > 0.005)
                Text('Tax, tip and discount are shared in proportion to what each person had.',
                    style: kStyleCaption.copyWith(color: kColorInkSoft)),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, kSpace3 + navBarPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (unclaimed > 0.005)
                Padding(
                  padding: const EdgeInsets.only(bottom: kSpace2),
                  child: Text(
                    '${_fmt(unclaimed)} of items not claimed yet — the payer covers it unless someone takes it.',
                    style: kStyleCaption.copyWith(color: kColorWarning),
                  ),
                ),
              WabwayButton(
                label: 'Use this split · ${_fmt(_it.total)}',
                icon: Icons.check_rounded,
                fullWidth: true,
                size: WabwayButtonSize.lg,
                onPressed: _it.items.isEmpty ? null : () => widget.onDone(_it),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Item row ─────────────────────────────────────────────────────────────────

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.weights,
    required this.members,
    required this.currency,
    required this.onEdit,
    required this.onToggle,
    required this.onPortions,
  });

  final ReceiptItem item;
  final Map<String, double> weights;
  final List<TripMember> members;
  final String currency;
  final VoidCallback onEdit;
  final ValueChanged<String> onToggle;
  final VoidCallback onPortions;

  @override
  Widget build(BuildContext context) {
    final claimed = weights.values.fold(0.0, (a, b) => a + b);
    final multi = item.quantity > 1;
    final vals = weights.values.toList();
    final custom = vals.isNotEmpty && vals.any((v) => (v - vals.first).abs() > 1e-9);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: kSpace3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onEdit,
            borderRadius: kRadiusSm,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    multi ? '${fmtQty(item.quantity)}× ${item.name}' : item.name,
                    style: kStyleBodyMedium,
                  ),
                ),
                const SizedBox(width: kSpace2),
                Text(fmtAmount(item.totalPrice, currency),
                    style: GoogleFonts.ibmPlexMono(fontSize: kTextSm, fontWeight: FontWeight.w600)),
                const SizedBox(width: kSpace1),
                const Icon(Icons.edit_rounded, size: 14, color: kColorInkSoft),
              ],
            ),
          ),
          const SizedBox(height: kSpace2),
          Wrap(
            spacing: kSpace2,
            runSpacing: kSpace2,
            children: [
              for (final m in members)
                _MemberChip(
                  member: m,
                  selected: weights.containsKey(m.id),
                  portion: multi || custom ? weights[m.id] : null,
                  onTap: () => onToggle(m.id),
                ),
              if (multi || custom)
                ActionChip(
                  avatar: const Icon(Icons.tune_rounded, size: 14),
                  label: const Text('Portions'),
                  labelStyle: kStyleCaption,
                  visualDensity: VisualDensity.compact,
                  onPressed: onPortions,
                ),
            ],
          ),
          if (claimed <= 0)
            Padding(
              padding: const EdgeInsets.only(top: kSpace1),
              child: Text('Nobody yet', style: kStyleCaption.copyWith(color: kColorWarning)),
            )
          else if (multi && claimed < item.quantity - 1e-6)
            Padding(
              padding: const EdgeInsets.only(top: kSpace1),
              child: Text('${fmtQty(item.quantity - claimed)} of ${fmtQty(item.quantity)} unclaimed',
                  style: kStyleCaption.copyWith(color: kColorWarning)),
            ),
        ],
      ),
    );
  }
}

class _MemberChip extends StatelessWidget {
  const _MemberChip({
    required this.member,
    required this.selected,
    required this.onTap,
    this.portion,
  });

  final TripMember member;
  final bool selected;
  final double? portion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = member.isYou ? 'You' : member.name.split(' ').first;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: kSpace2, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? kColorPrimary : kColorSurfaceSunken,
          borderRadius: kRadiusPill,
          border: Border.all(color: selected ? kColorPrimary : kColorBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            WabwayAvatar(name: member.name, size: WabwayAvatarSize.xs),
            const SizedBox(width: 4),
            Text(
              selected && portion != null ? '$label ×${fmtQty(portion!)}' : label,
              style: kStyleCaption.copyWith(color: selected ? kColorTextOnPrimary : kColorInk),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonTotal extends StatelessWidget {
  const _PersonTotal({
    required this.member,
    required this.total,
    required this.itemCount,
    required this.currency,
  });

  final TripMember member;
  final double total;
  final int itemCount;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: kSpace2),
      child: Row(
        children: [
          WabwayAvatar(name: member.name, size: WabwayAvatarSize.sm),
          const SizedBox(width: kSpace2),
          Expanded(child: Text(member.label, style: kStyleBodyMedium)),
          if (itemCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: kSpace2),
              child: Text(pluralize(itemCount, 'item'), style: kStyleCaption),
            ),
          Text(
            fmtAmount(total, currency),
            style: kStyleBodySemibold.copyWith(
                color: total > 0.005 ? kColorPrimary : kColorInkSoft),
          ),
        ],
      ),
    );
  }
}

class _AmountLine extends StatelessWidget {
  const _AmountLine(this.label, this.value, {this.bold = false});
  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: bold ? kStyleBodySemibold : kStyleBody)),
          Text(value, style: bold ? kStyleBodySemibold : kStyleBody),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.soft, required this.text});
  final IconData icon;
  final Color color;
  final Color soft;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: kSpace3),
      padding: const EdgeInsets.all(kSpace3),
      decoration: BoxDecoration(color: soft, borderRadius: kRadiusMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: kSpace2),
          Expanded(child: Text(text, style: kStyleCaption.copyWith(color: kColorInk))),
        ],
      ),
    );
  }
}

// ─── Small forms ──────────────────────────────────────────────────────────────

class _ItemEdit {
  const _ItemEdit({this.name = '', this.quantity = 1, this.price = 0, this.delete = false});
  final String name;
  final double quantity;
  final double price;
  final bool delete;
}

final _decimal = [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))];

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.showDragHandle, required this.children});
  final String title;
  final bool showDragHandle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(kSpace4, 0, kSpace4, kSpace4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDragHandle) const WabwayDragHandle() else const SizedBox(height: kSpace4),
            Text(title, style: kStyleTitle),
            const SizedBox(height: kSpace4),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ItemForm extends StatefulWidget {
  const _ItemForm({required this.item, required this.currency, required this.showDragHandle});
  final ReceiptItem? item;
  final String currency;
  final bool showDragHandle;

  @override
  State<_ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends State<_ItemForm> {
  late final _name = TextEditingController(text: widget.item?.name ?? '');
  late final _qty = TextEditingController(text: fmtQty(widget.item?.quantity ?? 1));
  late final _price = TextEditingController(
      text: widget.item == null ? '' : widget.item!.totalPrice.toStringAsFixed(currencyDecimals(widget.currency)));

  @override
  void dispose() {
    _name.dispose();
    _qty.dispose();
    _price.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final price = double.tryParse(_price.text.trim());
    final qty = double.tryParse(_qty.text.trim()) ?? 1;
    if (name.isEmpty || price == null) {
      showWabwaySnack(context, 'Enter a name and a price', error: true);
      return;
    }
    Navigator.pop(context, _ItemEdit(name: name, quantity: qty > 0 ? qty : 1, price: price));
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: widget.item == null ? 'Add item' : 'Edit item',
      showDragHandle: widget.showDragHandle,
      children: [
        WabwayTextField(label: 'Name', controller: _name, autofocus: widget.item == null,
            textInputAction: TextInputAction.next),
        const SizedBox(height: kSpace3),
        Row(
          children: [
            Expanded(
              child: WabwayTextField(
                label: 'Quantity',
                controller: _qty,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: _decimal,
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(width: kSpace3),
            Expanded(
              flex: 2,
              child: WabwayTextField(
                label: 'Line total (${widget.currency})',
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: _decimal,
                onSubmitted: (_) => _save(),
              ),
            ),
          ],
        ),
        const SizedBox(height: kSpace4),
        WabwayButton(label: 'Save item', fullWidth: true, onPressed: _save),
        if (widget.item != null) ...[
          const SizedBox(height: kSpace2),
          WabwayButton(
            label: 'Remove item',
            icon: Icons.delete_outline_rounded,
            variant: WabwayButtonVariant.dangerOutline,
            fullWidth: true,
            onPressed: () => Navigator.pop(context, const _ItemEdit(delete: true)),
          ),
        ],
      ],
    );
  }
}

class _ExtrasForm extends StatefulWidget {
  const _ExtrasForm({required this.it, required this.showDragHandle});
  final ReceiptItemization it;
  final bool showDragHandle;

  @override
  State<_ExtrasForm> createState() => _ExtrasFormState();
}

class _ExtrasFormState extends State<_ExtrasForm> {
  String _s(double v) => v == 0 ? '' : v.toStringAsFixed(2);
  late final _tax = TextEditingController(text: _s(widget.it.tax));
  late final _tip = TextEditingController(text: _s(widget.it.tip));
  late final _discount = TextEditingController(text: _s(widget.it.discount));

  @override
  void dispose() {
    _tax.dispose();
    _tip.dispose();
    _discount.dispose();
    super.dispose();
  }

  double _v(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    Widget field(String label, TextEditingController c) => Padding(
          padding: const EdgeInsets.only(bottom: kSpace3),
          child: WabwayTextField(
            label: label,
            hint: '0',
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: _decimal,
            textInputAction: TextInputAction.next,
          ),
        );
    return _SheetFrame(
      title: 'Tax, tip & discount',
      showDragHandle: widget.showDragHandle,
      children: [
        field('Tax', _tax),
        field('Tip / service charge', _tip),
        field('Discount', _discount),
        WabwayButton(
          label: 'Save',
          fullWidth: true,
          onPressed: () => Navigator.pop(context, (_v(_tax), _v(_tip), _v(_discount))),
        ),
      ],
    );
  }
}

class _PortionsForm extends StatefulWidget {
  const _PortionsForm({
    required this.item,
    required this.members,
    required this.weights,
    required this.showDragHandle,
  });
  final ReceiptItem item;
  final List<TripMember> members;
  final Map<String, double> weights;
  final bool showDragHandle;

  @override
  State<_PortionsForm> createState() => _PortionsFormState();
}

class _PortionsFormState extends State<_PortionsForm> {
  late final Map<String, double> _w = Map.of(widget.weights);

  double get _claimed => _w.values.fold(0.0, (a, b) => a + b);

  /// Whole units for whole-number items; halves otherwise.
  double get _step => widget.item.quantity == widget.item.quantity.roundToDouble() ? 1 : 0.5;

  @override
  Widget build(BuildContext context) {
    final qty = widget.item.quantity;
    return _SheetFrame(
      title: '${fmtQty(qty)}× ${widget.item.name}',
      showDragHandle: widget.showDragHandle,
      children: [
        Text('How many each person had. Unclaimed units are left for the payer.',
            style: kStyleCaption),
        const SizedBox(height: kSpace3),
        for (final m in widget.members)
          Padding(
            padding: const EdgeInsets.only(bottom: kSpace2),
            child: Row(
              children: [
                WabwayAvatar(name: m.name, size: WabwayAvatarSize.sm),
                const SizedBox(width: kSpace2),
                Expanded(child: Text(m.label, style: kStyleBodyMedium)),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  color: kColorInkSoft,
                  onPressed: (_w[m.id] ?? 0) <= 0
                      ? null
                      : () => setState(() {
                            final v = (_w[m.id] ?? 0) - _step;
                            if (v <= 1e-9) {
                              _w.remove(m.id);
                            } else {
                              _w[m.id] = v;
                            }
                          }),
                ),
                SizedBox(
                  width: 36,
                  child: Text(fmtQty(_w[m.id] ?? 0),
                      textAlign: TextAlign.center, style: kStyleBodySemibold),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  color: kColorPrimary,
                  onPressed: () => setState(() => _w[m.id] = (_w[m.id] ?? 0) + _step),
                ),
              ],
            ),
          ),
        Text(
          _claimed > qty + 1e-6
              ? '${fmtQty(_claimed)} claimed of ${fmtQty(qty)} — shared in proportion'
              : '${fmtQty(_claimed)} of ${fmtQty(qty)} claimed',
          style: kStyleCaption,
        ),
        const SizedBox(height: kSpace4),
        WabwayButton(
          label: 'Save portions',
          fullWidth: true,
          onPressed: () => Navigator.pop(context, _w),
        ),
      ],
    );
  }
}
