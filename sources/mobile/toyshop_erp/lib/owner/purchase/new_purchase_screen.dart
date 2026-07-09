import 'package:flutter/material.dart';

import '../../core/core.dart';
import 'new_purchase_data.dart';

/// Owner "New Purchase" — the stock-in flow (Requirement 4). Choose/add a
/// supplier, add line items with **duplicate auto-suggest** before any new
/// product is created, capture GST, and confirm — which (in production)
/// appends `stock_movements(purchase_in)` and updates stock instantly.
///
/// Doc: docs/mobile/owner/purchase/new-purchase.md
///
/// PROTOTYPE NOTE: the doc's 4-step wizard is flattened into one scrollable
/// screen (supplier → items → GST filing) with the running summary always
/// visible in the bottom bar, so the whole draft stays reviewable at a
/// glance — still satisfying "confirm before commit" (design-system.md §1.3).
class NewPurchaseScreen extends StatefulWidget {
  const NewPurchaseScreen({super.key});

  @override
  State<NewPurchaseScreen> createState() => _NewPurchaseScreenState();
}

class _NewPurchaseScreenState extends State<NewPurchaseScreen> {
  final _repo = const NewPurchaseRepository();
  static final DateTime _today = DateTime(2026, 7, 3);

  bool _loading = true;
  bool _saving = false;

  List<Supplier> _suppliers = [];
  List<Product> _catalog = [];
  List<OwnerGstin> _gstins = [];

  Supplier? _supplier;
  final List<PurchaseLine> _lines = [];
  OwnerGstin? _gstin;

  final _supplierGstinCtrl = TextEditingController();
  final _invoiceNoCtrl = TextEditingController();
  DateTime _invoiceDate = _today;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _supplierGstinCtrl.dispose();
    _invoiceNoCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final suppliers = await _repo.suppliers();
    final catalog = await _repo.existingProducts();
    final gstins = await _repo.ownerGstins();
    if (!mounted) return;
    setState(() {
      _suppliers = suppliers;
      _catalog = catalog;
      _gstins = gstins;
      _gstin = gstins.firstWhere((g) => g.active, orElse: () => gstins.first);
      _loading = false;
    });
  }

  // ---- derived totals ----------------------------------------------------
  double get _subtotal => _lines.fold(0, (a, l) => a + l.lineSubtotal);
  double get _totalGst => _lines.fold(0, (a, l) => a + l.gstAmount);
  double get _grandTotal => _subtotal + _totalGst;
  int get _totalUnits => _lines.fold(0, (a, l) => a + l.qty);

  /// Non-null while confirm is blocked — surfaced as a warning caption + a
  /// disabled button rather than a dead-end (design-system.md §1.4).
  String? get _blockReason {
    if (_supplier == null) return 'Choose a supplier to continue';
    if (_lines.isEmpty) return 'Add at least one item';
    if (_gstin == null) return 'Select a GSTIN to file this purchase under';
    if (!_gstin!.active) return 'Selected GSTIN is inactive — pick an active one';
    return null;
  }

  // ---- actions -------------------------------------------------------
  Future<void> _pickSupplier() async {
    final result = await showModalBottomSheet<Supplier>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SupplierPickerSheet(suppliers: _suppliers, repo: _repo),
    );
    if (result == null || !mounted) return;
    setState(() {
      _supplier = result;
      if (!_suppliers.any((s) => s.id == result.id)) {
        _suppliers = [..._suppliers, result];
      }
      _supplierGstinCtrl.text = result.gstin ?? '';
    });
  }

  Future<void> _pickGstin() async {
    final result = await showModalBottomSheet<OwnerGstin>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GstinPickerSheet(gstins: _gstins),
    );
    if (result == null || !mounted) return;
    setState(() => _gstin = result);
  }

  Future<void> _pickInvoiceDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _invoiceDate,
      firstDate: DateTime(2020),
      lastDate: _today,
    );
    if (picked != null && mounted) setState(() => _invoiceDate = picked);
  }

  void _addItemGuarded() {
    if (_supplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a supplier before adding items')),
      );
      return;
    }
    _openItemSheet();
  }

  Future<void> _openItemSheet({PurchaseLine? edit}) async {
    final result = await showModalBottomSheet<PurchaseLine>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddItemSheet(repo: _repo, catalog: _catalog, initial: edit),
    );
    if (result == null || !mounted) return;
    setState(() {
      final idx = edit == null ? -1 : _lines.indexWhere((l) => l.id == edit.id);
      if (idx != -1) {
        _lines[idx] = result;
      } else {
        _lines.add(result);
      }
    });
  }

  void _removeLine(int index) {
    final removed = _lines[index];
    setState(() => _lines.removeAt(index));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed ${removed.name}'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => setState(() => _lines.insert(index, removed)),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_blockReason != null || _saving) return;
    setState(() => _saving = true);
    final receipt = await _repo.confirmPurchase(
      supplier: _supplier!,
      lines: List.of(_lines),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PurchaseSuccessSheet(receipt: receipt),
    );
    if (!mounted) return;
    setState(() {
      _supplier = null;
      _lines.clear();
      _supplierGstinCtrl.clear();
      _invoiceNoCtrl.clear();
      _invoiceDate = _today;
      _gstin = _gstins.firstWhere((g) => g.active, orElse: () => _gstins.first);
    });
  }

  // ---- build -------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'New Purchase',
      subtitle: _loading
          ? null
          : (_lines.isEmpty
              ? 'Stock-in · no items yet'
              : '${_lines.length} item${_lines.length == 1 ? '' : 's'} · $_totalUnits units'),
      body: _loading ? _buildLoading() : _buildBody(),
      bottomBar: _loading ? null : _buildBottomBar(),
    );
  }

  Widget _buildLoading() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: const [
        SkeletonBox(height: 88, radius: 12),
        SizedBox(height: AppSpacing.xl),
        SkeletonBox(height: 130, radius: 12),
        SizedBox(height: AppSpacing.md),
        SkeletonBox(height: 130, radius: 12),
      ],
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        SectionHeader(title: 'Supplier', padding: const EdgeInsets.only(bottom: AppSpacing.sm)),
        _supplierCard(),
        const SizedBox(height: AppSpacing.xl),
        SectionHeader(
          title: _lines.isEmpty ? 'Items' : 'Items (${_lines.length})',
          actionLabel: 'Add item',
          onAction: _addItemGuarded,
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        ),
        if (_lines.isEmpty)
          EmptyState(
            icon: Icons.inventory_2_rounded,
            title: 'No items yet',
            message: "Add your first item — we'll check for duplicates automatically.",
            actionLabel: 'Add item',
            onAction: _addItemGuarded,
          )
        else
          for (var i = 0; i < _lines.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == _lines.length - 1 ? 0 : AppSpacing.md),
              child: _lineCard(i),
            ),
        const SizedBox(height: AppSpacing.xl),
        SectionHeader(
          title: 'Invoice & GST filing',
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        ),
        _invoiceCard(),
      ],
    );
  }

  Widget _supplierCard() {
    final p = context.palette;
    final s = _supplier;
    if (s == null) {
      return AppCard(
        onTap: _pickSupplier,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: p.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.local_shipping_rounded, color: p.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text('Choose a supplier', style: AppType.body.copyWith(color: p.inkMuted)),
            ),
            Icon(Icons.chevron_right_rounded, color: p.inkMuted),
          ],
        ),
      );
    }
    final hasGstin = s.gstin != null;
    return AppCard(
      onTap: _pickSupplier,
      highlight: true,
      child: Row(
        children: [
          AvatarBadge(initials: _initials(s.name), color: p.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name, style: AppType.title.copyWith(color: p.ink)),
                const SizedBox(height: 4),
                TonePill.tone(
                  hasGstin ? Tone.success : Tone.warning,
                  hasGstin ? s.gstin! : 'GSTIN missing · ITC risk',
                  icon: hasGstin ? Icons.verified_rounded : Icons.warning_amber_rounded,
                  dense: true,
                ),
              ],
            ),
          ),
          Icon(Icons.edit_rounded, size: 18, color: p.inkMuted),
        ],
      ),
    );
  }

  Widget _lineCard(int i) {
    final p = context.palette;
    final l = _lines[i];
    return AppCard(
      onTap: () => _openItemSheet(edit: l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProductThumb(
                product: Product(
                  id: l.id,
                  name: l.name,
                  category: l.category,
                  price: l.sellPrice,
                  colorTag: l.colorTag,
                ),
                size: 48,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.title.copyWith(color: p.ink),
                          ),
                        ),
                        const SizedBox(width: 6),
                        TonePill.tone(
                          l.isNew ? Tone.info : Tone.success,
                          l.isNew ? 'NEW' : 'EXISTING',
                          dense: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${l.category} · GST ${l.gstRate}%',
                      style: AppType.caption.copyWith(color: p.inkMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _removeLine(i),
                icon: Icon(Icons.close_rounded, size: 18, color: p.inkMuted),
                tooltip: 'Remove line',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text('Qty', style: AppType.caption.copyWith(color: p.inkMuted)),
              const SizedBox(width: 6),
              QtyStepper(
                value: l.qty,
                size: 32,
                onChanged: (v) => setState(() => _lines[i] = l.copyWith(qty: v)),
              ),
              const Spacer(),
              MoneyText(Fmt.money(l.lineTotal), style: AppType.title),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${Fmt.money(l.costPrice)} × ${l.qty} + GST ${Fmt.money(l.gstAmount)} '
            '· sells @ ${Fmt.money(l.sellPrice)}',
            style: AppType.caption.copyWith(color: p.inkMuted),
          ),
        ],
      ),
    );
  }

  Widget _invoiceCard() {
    final p = context.palette;
    final gstin = _gstin;
    final supplierGstinText = _supplierGstinCtrl.text.trim();
    final supplierGstinEmpty = supplierGstinText.isEmpty;
    final supplierGstinValid = _gstinFormat.hasMatch(supplierGstinText);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _pickGstin,
            borderRadius: AppRadii.card,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('File under GSTIN', style: AppType.caption.copyWith(color: p.inkMuted)),
                      const SizedBox(height: 2),
                      Text(
                        gstin?.gstin ?? 'Select a GSTIN',
                        style: AppType.title.copyWith(color: p.ink),
                      ),
                    ],
                  ),
                ),
                if (gstin != null) ...[
                  TonePill.tone(
                    gstin.active ? Tone.success : Tone.warning,
                    gstin.active ? 'Active' : 'Inactive',
                    dense: true,
                  ),
                  const SizedBox(width: 6),
                ],
                Icon(Icons.chevron_right_rounded, color: p.inkMuted),
              ],
            ),
          ),
          const Divider(height: AppSpacing.xl),
          TextField(
            controller: _supplierGstinCtrl,
            onChanged: (_) => setState(() {}),
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Supplier GSTIN (ITC)',
              helperText: supplierGstinEmpty ? 'Blank flags an ITC-risk at filing time' : null,
              helperStyle: AppType.caption.copyWith(color: p.warning),
              suffixIcon: supplierGstinEmpty
                  ? null
                  : Icon(
                      supplierGstinValid ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                      color: supplierGstinValid ? p.success : p.warning,
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _invoiceNoCtrl,
            decoration: const InputDecoration(labelText: 'Invoice no (optional)'),
          ),
          const SizedBox(height: AppSpacing.md),
          InkWell(
            onTap: _pickInvoiceDate,
            borderRadius: AppRadii.card,
            child: Row(
              children: [
                Icon(Icons.event_rounded, size: 18, color: p.inkMuted),
                const SizedBox(width: 8),
                Text('Invoice date', style: AppType.body.copyWith(color: p.inkMuted)),
                const Spacer(),
                Text(
                  Fmt.date(_invoiceDate),
                  style: AppType.body.copyWith(color: p.ink, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final p = context.palette;
    final reason = _blockReason;
    return AppBottomBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LabeledRow('Subtotal', MoneyText(Fmt.money(_subtotal))),
          LabeledRow('Total GST', MoneyText(Fmt.money(_totalGst))),
          const Divider(height: AppSpacing.lg),
          LabeledRow(
            'Grand total',
            MoneyText(Fmt.money(_grandTotal), style: AppType.h2),
            emphasize: true,
          ),
          if (reason != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: p.warning),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(reason, style: AppType.caption.copyWith(color: p.warning)),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: reason == null && !_saving ? _save : null,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_rounded),
              label: Text(_saving ? 'Saving…' : 'Save purchase · ${Fmt.money0(_grandTotal)}'),
            ),
          ),
        ],
      ),
    );
  }
}

final RegExp _gstinFormat =
    RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$');

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.substring(0, parts.first.length > 1 ? 2 : 1).toUpperCase();
  }
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

/// Shared rounded-sheet chrome (drag handle + title) for every bottom sheet
/// on this screen — mirrors `showOwnerPinSheet`'s DIY chrome since
/// `bottomSheetTheme` is bypassed via `backgroundColor: Colors.transparent`.
class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.title, this.subtitle, required this.child});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        child: Container(
          decoration: BoxDecoration(color: p.surface, borderRadius: AppRadii.sheet),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: p.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(title, style: AppType.h2.copyWith(color: p.ink)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: AppType.caption.copyWith(color: p.inkMuted)),
                ],
                const SizedBox(height: AppSpacing.lg),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Supplier search + select + "add new" (doc §5a).
class _SupplierPickerSheet extends StatefulWidget {
  const _SupplierPickerSheet({required this.suppliers, required this.repo});
  final List<Supplier> suppliers;
  final NewPurchaseRepository repo;

  @override
  State<_SupplierPickerSheet> createState() => _SupplierPickerSheetState();
}

class _SupplierPickerSheetState extends State<_SupplierPickerSheet> {
  late final List<Supplier> _list = List.of(widget.suppliers);
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _addNew() async {
    final created = await showModalBottomSheet<Supplier>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddSupplierSheet(repo: widget.repo),
    );
    if (created == null || !mounted) return;
    Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final q = _searchCtrl.text.trim().toLowerCase();
    final filtered =
        q.isEmpty ? _list : _list.where((s) => s.name.toLowerCase().contains(q)).toList();
    return _SheetShell(
      title: 'Choose supplier',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Search supplier',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text('No suppliers match', style: AppType.body.copyWith(color: p.inkMuted)),
            )
          else
            for (final s in filtered)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppCard(
                  onTap: () => Navigator.of(context).pop(s),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      AvatarBadge(initials: _initials(s.name), color: p.primary, size: 40),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.name,
                              style: AppType.body.copyWith(color: p.ink, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              s.gstin ?? 'No GSTIN on file',
                              style: AppType.caption.copyWith(
                                color: s.gstin == null ? p.warning : p.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addNew,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add new supplier'),
            ),
          ),
        ],
      ),
    );
  }
}

/// New-supplier form (doc §5a row 3) — missing GSTIN allowed, flagged later.
class _AddSupplierSheet extends StatefulWidget {
  const _AddSupplierSheet({required this.repo});
  final NewPurchaseRepository repo;

  @override
  State<_AddSupplierSheet> createState() => _AddSupplierSheetState();
}

class _AddSupplierSheetState extends State<_AddSupplierSheet> {
  final _name = TextEditingController();
  final _gstin = TextEditingController();
  final _phone = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _gstin.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _saving) return;
    setState(() => _saving = true);
    final s = await widget.repo.addSupplier(
      name: _name.text.trim(),
      gstin: _gstin.text.trim(),
      phone: _phone.text.trim(),
    );
    if (!mounted) return;
    Navigator.of(context).pop(s);
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title: 'Add new supplier',
      subtitle: 'Missing GSTIN is allowed but flags ITC risk later',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Supplier name *'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _gstin,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'GSTIN (optional)'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone (optional)'),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _name.text.trim().isEmpty || _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save supplier'),
            ),
          ),
        ],
      ),
    );
  }
}

/// "File under GSTIN" picker — inactive registrations are shown but blocked
/// with a message rather than hidden (doc §8.4, §5d field 19).
class _GstinPickerSheet extends StatelessWidget {
  const _GstinPickerSheet({required this.gstins});
  final List<OwnerGstin> gstins;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return _SheetShell(
      title: 'File under GSTIN',
      subtitle: 'Only an active registration can be selected',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final g in gstins)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                onTap: () {
                  if (!g.active) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('This GSTIN is inactive — activate it on web first'),
                      ),
                    );
                    return;
                  }
                  Navigator.of(context).pop(g);
                },
                child: Opacity(
                  opacity: g.active ? 1.0 : 0.55,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(g.gstin, style: AppType.title.copyWith(color: p.ink)),
                            Text(g.label, style: AppType.caption.copyWith(color: p.inkMuted)),
                          ],
                        ),
                      ),
                      TonePill.tone(
                        g.active ? Tone.success : Tone.neutral,
                        g.active ? 'Active' : 'Inactive',
                        icon: g.active ? Icons.check_circle_rounded : Icons.lock_rounded,
                        dense: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Add / edit a purchase line. Typing a product name runs the on-device
/// duplicate-check (foundation/duplicate-detection.md §2); "From catalog"
/// short-circuits straight to an existing product (like a QR-scan resolve,
/// doc §5b note — identity already certain, dup-check skipped).
class _AddItemSheet extends StatefulWidget {
  const _AddItemSheet({required this.repo, required this.catalog, this.initial});
  final NewPurchaseRepository repo;
  final List<Product> catalog;
  final PurchaseLine? initial;

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _costCtrl;
  late final TextEditingController _sellCtrl;
  final _catalogSearchCtrl = TextEditingController();

  String? _category;
  int _qty = 1;
  int _gstRate = 18;
  Color _colorTag = kPurchaseColorTags.first;
  bool _fromCatalog = false;
  DuplicateMatch? _match;
  DuplicateMatch? _resolved;
  int _checkGen = 0;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _nameCtrl = TextEditingController(text: init?.name ?? '');
    _costCtrl = TextEditingController(text: init != null ? init.costPrice.toStringAsFixed(2) : '');
    _sellCtrl = TextEditingController(text: init != null ? init.sellPrice.toStringAsFixed(2) : '');
    _category = init?.category;
    _qty = init?.qty ?? 1;
    _gstRate = init?.gstRate ?? 18;
    _colorTag = init?.colorTag ?? kPurchaseColorTags.first;
    if (init != null && init.productId != null) {
      _resolved = DuplicateMatch(
        productId: init.productId!,
        name: init.name,
        category: init.category,
        costPrice: init.costPrice,
        sellPrice: init.sellPrice,
        colorTag: init.colorTag,
        gstRate: init.gstRate,
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _costCtrl.dispose();
    _sellCtrl.dispose();
    _catalogSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _onNameChanged(String v) async {
    setState(() => _match = null);
    final text = v.trim();
    if (text.length < 3) return;
    final gen = ++_checkGen;
    final m = await widget.repo.checkDuplicate(text);
    if (!mounted || gen != _checkGen) return;
    setState(() => _match = m);
  }

  void _useMatch(DuplicateMatch m) {
    setState(() {
      _resolved = m;
      _match = null;
      _nameCtrl.text = m.name;
      _category = m.category;
      _costCtrl.text = m.costPrice.toStringAsFixed(2);
      _sellCtrl.text = m.sellPrice.toStringAsFixed(2);
      _gstRate = m.gstRate;
      _colorTag = m.colorTag;
    });
  }

  void _pickFromCatalog(Product prod) {
    // PROTOTYPE: wholesale cost isn't in the sale-price catalog record, so we
    // estimate it — the owner can still correct it below before saving.
    final suggestedCost = ((prod.price * 0.65) / 5).round() * 5.0;
    setState(() {
      _resolved = DuplicateMatch(
        productId: prod.id,
        name: prod.name,
        category: prod.category,
        costPrice: suggestedCost,
        sellPrice: prod.price,
        colorTag: prod.colorTag,
        gstRate: prod.gstRate,
      );
      _nameCtrl.text = prod.name;
      _category = prod.category;
      _costCtrl.text = suggestedCost.toStringAsFixed(2);
      _sellCtrl.text = prod.price.toStringAsFixed(2);
      _gstRate = prod.gstRate;
      _colorTag = prod.colorTag;
      _fromCatalog = false;
    });
  }

  void _clearResolved() {
    setState(() {
      _resolved = null;
      _nameCtrl.clear();
      _category = null;
    });
  }

  bool get _valid {
    final cost = double.tryParse(_costCtrl.text.trim());
    final sell = double.tryParse(_sellCtrl.text.trim());
    return _nameCtrl.text.trim().isNotEmpty &&
        _category != null &&
        cost != null &&
        cost >= 0 &&
        sell != null &&
        sell >= 0 &&
        _qty > 0;
  }

  void _submit() {
    if (!_valid) return;
    final line = PurchaseLine(
      id: widget.initial?.id ?? 'L-${DateTime.now().microsecondsSinceEpoch}',
      productId: _resolved?.productId,
      name: _nameCtrl.text.trim(),
      category: _category!,
      colorTag: _colorTag,
      qty: _qty,
      costPrice: double.parse(_costCtrl.text.trim()),
      sellPrice: double.parse(_sellCtrl.text.trim()),
      gstRate: _gstRate,
      isNew: _resolved == null,
    );
    Navigator.of(context).pop(line);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final showPriceFields = _resolved != null || !_fromCatalog;
    return _SheetShell(
      title: widget.initial == null ? 'Add item' : 'Edit item',
      subtitle: widget.initial == null ? 'Type a name or pick from the existing catalog' : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_resolved == null) ...[
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Type name'),
                    selected: !_fromCatalog,
                    onSelected: (_) => setState(() => _fromCatalog = false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('From catalog'),
                    selected: _fromCatalog,
                    onSelected: (_) => setState(() => _fromCatalog = true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (_resolved != null) _resolvedBanner(p, _resolved!),
          if (_resolved == null && _fromCatalog) _catalogPicker(p),
          if (_resolved == null && !_fromCatalog) ...[
            TextField(
              controller: _nameCtrl,
              autofocus: widget.initial == null,
              onChanged: (v) {
                setState(() {});
                _onNameChanged(v);
              },
              decoration: const InputDecoration(
                labelText: 'Product name',
                hintText: 'e.g. Blue Jeep Racer',
              ),
            ),
            if (_match != null) ...[
              const SizedBox(height: AppSpacing.md),
              _duplicateCard(p, _match!),
            ],
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [for (final c in kPurchaseCategories) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (showPriceFields) ..._priceQtyFields(p),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _valid ? _submit : null,
              child: Text(widget.initial == null ? 'Add line' : 'Save changes'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resolvedBanner(AppPalette p, DuplicateMatch m) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        borderColor: p.success,
        child: Row(
          children: [
            ProductThumb(
              product: Product(
                id: m.productId,
                name: m.name,
                category: m.category,
                price: m.sellPrice,
                colorTag: m.colorTag,
              ),
              size: 40,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.name, style: AppType.title.copyWith(color: p.ink)),
                  Text(m.category, style: AppType.caption.copyWith(color: p.inkMuted)),
                ],
              ),
            ),
            TextButton(onPressed: _clearResolved, child: const Text('Change')),
          ],
        ),
      ),
    );
  }

  Widget _duplicateCard(AppPalette p, DuplicateMatch m) {
    return AppCard(
      borderColor: p.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.search_rounded, color: p.warning, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Possible duplicate found',
                  style: AppType.label.copyWith(color: p.ink, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              ProductThumb(
                product: Product(
                  id: m.productId,
                  name: m.name,
                  category: m.category,
                  price: m.sellPrice,
                  colorTag: m.colorTag,
                ),
                size: 40,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.name,
                      style: AppType.body.copyWith(color: p.ink, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${m.category} · ${Fmt.money(m.sellPrice)}',
                      style: AppType.caption.copyWith(color: p.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text("Same item as what you're entering?", style: AppType.caption.copyWith(color: p.inkMuted)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _match = null),
                  child: const Text("No, it's new"),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: () => _useMatch(m),
                  child: const Text('Yes, use existing'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _catalogPicker(AppPalette p) {
    final q = _catalogSearchCtrl.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.catalog
        : widget.catalog.where((c) => c.name.toLowerCase().contains(q)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _catalogSearchCtrl,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Search catalog',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Text('No matching products', style: AppType.body.copyWith(color: p.inkMuted)),
          )
        else
          for (final prod in filtered)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.sm),
                onTap: () => _pickFromCatalog(prod),
                child: Row(
                  children: [
                    ProductThumb(product: prod, size: 44),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            prod.name,
                            style: AppType.body.copyWith(color: p.ink, fontWeight: FontWeight.w600),
                          ),
                          Text(prod.category, style: AppType.caption.copyWith(color: p.inkMuted)),
                        ],
                      ),
                    ),
                    StockPill(prod.stock, qty: prod.stockQty, dense: true),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  List<Widget> _priceQtyFields(AppPalette p) {
    final cost = double.tryParse(_costCtrl.text.trim());
    final showPreview = cost != null;
    return [
      Row(
        children: [
          Text('Quantity', style: AppType.body.copyWith(color: p.inkMuted)),
          const Spacer(),
          QtyStepper(value: _qty, onChanged: (v) => setState(() => _qty = v)),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _costCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Cost price', prefixText: '₹ '),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: TextField(
              controller: _sellCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Sell price', prefixText: '₹ '),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      DropdownButtonFormField<int>(
        initialValue: _gstRate,
        decoration: const InputDecoration(labelText: 'GST rate'),
        items: [for (final r in kGstRates) DropdownMenuItem(value: r, child: Text('$r%'))],
        onChanged: (v) => setState(() => _gstRate = v ?? _gstRate),
      ),
      const SizedBox(height: AppSpacing.md),
      Text('Color tag', style: AppType.caption.copyWith(color: p.inkMuted)),
      const SizedBox(height: 6),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final c in kPurchaseColorTags)
            GestureDetector(
              onTap: () => setState(() => _colorTag = c),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _colorTag == c ? p.ink : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: _colorTag == c
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                    : null,
              ),
            ),
        ],
      ),
      if (showPreview) ...[
        const SizedBox(height: AppSpacing.md),
        _linePreview(p, cost),
      ],
    ];
  }

  Widget _linePreview(AppPalette p, double cost) {
    final subtotal = cost * _qty;
    final gst = double.parse((subtotal * _gstRate / 100).toStringAsFixed(2));
    final total = subtotal + gst;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(10)),
      child: Text(
        '${Fmt.money(cost)} × $_qty + GST ${Fmt.money(gst)} = ${Fmt.money(total)}',
        style: AppType.caption.copyWith(color: p.inkMuted),
      ),
    );
  }
}

/// Success confirmation — toast-equivalent for the mobile prototype (doc §6).
class _PurchaseSuccessSheet extends StatelessWidget {
  const _PurchaseSuccessSheet({required this.receipt});
  final PurchaseReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return _SheetShell(
      title: 'Purchase saved',
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: p.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_rounded, color: p.success, size: 34),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('${receipt.totalUnits} units in', style: AppType.h2.copyWith(color: p.ink)),
            const SizedBox(height: 4),
            Text(
              'Subtotal ${Fmt.money(receipt.subtotal)} + GST ${Fmt.money(receipt.totalGst)} '
              '= ${Fmt.money(receipt.totalCost)}',
              textAlign: TextAlign.center,
              style: AppType.body.copyWith(color: p.inkMuted),
            ),
            const SizedBox(height: 4),
            Text(
              'Stock updated instantly · ${receipt.id}',
              style: AppType.caption.copyWith(color: p.inkMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
