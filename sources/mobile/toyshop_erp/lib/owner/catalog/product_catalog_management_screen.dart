import 'package:flutter/material.dart';

import '../../core/core.dart';
import 'product_catalog_management_data.dart';

/// Owner Product Catalog Management — browse/search the catalog, edit price
/// & attributes, add products (mandatory dup-check), and deactivate 🔒.
/// Doc: docs/mobile/owner/catalog/product-catalog-management.md
class ProductCatalogManagementScreen extends StatefulWidget {
  const ProductCatalogManagementScreen({super.key});

  @override
  State<ProductCatalogManagementScreen> createState() => _ProductCatalogManagementScreenState();
}

enum _ActiveFilter { active, inactive, all }

class _ProductCatalogManagementScreenState extends State<ProductCatalogManagementScreen> {
  final _repo = const ProductCatalogRepository();
  final _searchCtrl = TextEditingController();

  List<Product>? _products;
  List<ProductCategory> _categories = [];
  final Map<String, CatalogMeta> _meta = {};

  String _query = '';
  String? _categoryFilter;
  _ActiveFilter _activeFilter = _ActiveFilter.active;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final products = await _repo.all();
    final categories = await _repo.categories();
    if (!mounted) return;
    setState(() {
      _products = List.of(products);
      _categories = List.of(categories);
      for (final p in products) {
        _meta[p.id] = _repo.metaFor(p.id);
      }
    });
  }

  List<Product> get _filtered {
    final products = _products ?? const <Product>[];
    final q = _query.trim().toLowerCase();
    return products.where((p) {
      final meta = _meta[p.id] ?? const CatalogMeta();
      if (_activeFilter == _ActiveFilter.active && !meta.isActive) return false;
      if (_activeFilter == _ActiveFilter.inactive && meta.isActive) return false;
      if (_categoryFilter != null && p.category != _categoryFilter) return false;
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          (p.shelf?.toLowerCase().contains(q) ?? false) ||
          p.category.toLowerCase().contains(q) ||
          colorTagLabel(p.colorTag).toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final products = _products;
    return AppScaffold(
      title: 'Catalog',
      subtitle: products == null ? null : '${_filtered.length} of ${products.length} products',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddSheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add product'),
      ),
      body: products == null ? _loadingGrid() : _content(products),
    );
  }

  // ---- loading ----------------------------------------------------------

  Widget _loadingGrid() {
    return GridView.count(
      padding: const EdgeInsets.all(AppSpacing.lg),
      crossAxisCount: 2,
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 0.64,
      children: List.generate(6, (_) => _skeletonTile()),
    );
  }

  Widget _skeletonTile() {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: SkeletonBox(radius: 12)),
          SizedBox(height: 8),
          SkeletonBox(height: 13, width: 90),
          SizedBox(height: 6),
          SkeletonBox(height: 13, width: 60),
        ],
      ),
    );
  }

  // ---- filters ------------------------------------------------------------

  Widget _filterBar() {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search name, shelf, colour…',
              isDense: true,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => setState(() {
                        _query = '';
                        _searchCtrl.clear();
                      }),
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _categoryChip(null, 'All'),
                for (final c in _categories) _categoryChip(c.name, c.name, color: c.color, icon: c.icon),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            children: [
              _activeChip(_ActiveFilter.active, 'Active'),
              _activeChip(_ActiveFilter.inactive, 'Inactive'),
              _activeChip(_ActiveFilter.all, 'All'),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Tap a product to edit. Long-press for details on any tile, including out-of-stock.',
            style: AppType.caption.copyWith(color: p.inkMuted),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(String? value, String label, {Color? color, IconData? icon}) {
    final p = context.palette;
    final selected = _categoryFilter == value;
    final c = color ?? p.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: selected,
        showCheckmark: false,
        avatar: icon == null ? null : Icon(icon, size: 16, color: selected ? Colors.white : c),
        label: Text(label),
        labelStyle: AppType.label.copyWith(
          color: selected ? Colors.white : p.ink,
          fontWeight: FontWeight.w600,
        ),
        selectedColor: c,
        side: BorderSide(color: selected ? c : p.border),
        onSelected: (_) => setState(() => _categoryFilter = value),
      ),
    );
  }

  Widget _activeChip(_ActiveFilter value, String label) {
    final p = context.palette;
    final selected = _activeFilter == value;
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      labelStyle: AppType.label.copyWith(
        color: selected ? Colors.white : p.ink,
        fontWeight: FontWeight.w600,
      ),
      selectedColor: p.primary,
      side: BorderSide(color: selected ? p.primary : p.border),
      onSelected: (_) => setState(() => _activeFilter = value),
    );
  }

  // ---- content --------------------------------------------------------

  Widget _content(List<Product> products) {
    final filtered = _filtered;
    return Column(
      children: [
        _filterBar(),
        Expanded(
          child: filtered.isEmpty
              ? _emptyState(products.isEmpty)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = constraints.maxWidth >= 700 ? 4 : (constraints.maxWidth >= 480 ? 3 : 2);
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 96),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisSpacing: AppSpacing.md,
                          crossAxisSpacing: AppSpacing.md,
                          childAspectRatio: 0.64,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) => _tile(filtered[i]),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _emptyState(bool noProductsAtAll) {
    if (noProductsAtAll) {
      return EmptyState(
        icon: Icons.inventory_2_rounded,
        title: 'No products yet',
        message: 'Add your first product to start building the catalog.',
        actionLabel: 'Add product',
        onAction: _openAddSheet,
      );
    }
    return EmptyState(
      icon: Icons.search_off_rounded,
      title: 'No matches',
      message: 'Try a different search, category or filter.',
      actionLabel: 'Clear filters',
      onAction: () => setState(() {
        _query = '';
        _searchCtrl.clear();
        _categoryFilter = null;
        _activeFilter = _ActiveFilter.active;
      }),
    );
  }

  /// Grid tile with status badges. `ProductTile` (shared widget) disables its
  /// own `onTap` while `stockQty == 0` (sales-safety default) — out-of-stock
  /// tiles stay reachable via long-press (doc §7) and the explicit
  /// "View / edit" badge below, so nothing here is a dead end.
  Widget _tile(Product product) {
    final meta = _meta[product.id] ?? const CatalogMeta();
    final needsPrice = product.price <= 0;
    final isOut = product.stockQty == 0;
    final badges = <Widget>[
      if (!meta.isActive)
        TonePill.tone(Tone.neutral, 'Inactive', icon: Icons.visibility_off_rounded, dense: true),
      if (meta.isDuplicateSuspect)
        TonePill.tone(Tone.warning, 'Dup?', icon: Icons.content_copy_rounded, dense: true),
      if (needsPrice)
        TonePill.tone(Tone.danger, 'Set price', icon: Icons.price_change_rounded, dense: true),
      if (isOut)
        GestureDetector(
          onTap: () => _openDetailSheet(product),
          child: TonePill.tone(
            Tone.primary,
            'View / edit',
            icon: Icons.chevron_right_rounded,
            filled: true,
            dense: true,
          ),
        ),
    ];
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ProductTile(
          product: product,
          onTap: () => _openDetailSheet(product),
          onLongPress: () => _openDetailSheet(product),
        ),
        if (badges.isNotEmpty)
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: Wrap(spacing: 4, runSpacing: 4, children: badges),
          ),
      ],
    );
  }

  // ---- detail / edit sheet ------------------------------------------------

  Future<void> _openDetailSheet(Product product) async {
    final meta = _meta[product.id] ?? const CatalogMeta();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => _ProductDetailSheet(
        product: product,
        meta: meta,
        categories: _categories,
        onSave: (updated) async {
          await _repo.updateProduct(updated);
          if (!mounted || !sheetCtx.mounted) return;
          setState(() {
            _products = [
              for (final existing in _products!)
                existing.id == updated.id ? updated : existing,
            ];
          });
          Navigator.of(sheetCtx).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product saved')),
          );
        },
        onDeactivate: () async {
          final ok = await showOwnerPinSheet(
            sheetCtx,
            title: 'Deactivate product',
            subtitle: '${product.name} will be hidden from staff selling. This is reversible.',
          );
          if (ok != true) return;
          await _repo.setActive(product.id, false);
          if (!mounted || !sheetCtx.mounted) return;
          setState(() {
            _meta[product.id] = (_meta[product.id] ?? const CatalogMeta()).copyWith(isActive: false);
          });
          Navigator.of(sheetCtx).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${product.name} deactivated')),
          );
        },
        onReactivate: () async {
          await _repo.setActive(product.id, true);
          if (!mounted || !sheetCtx.mounted) return;
          setState(() {
            _meta[product.id] = (_meta[product.id] ?? const CatalogMeta()).copyWith(isActive: true);
          });
          Navigator.of(sheetCtx).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${product.name} reactivated')),
          );
        },
      ),
    );
  }

  // ---- add product + mandatory duplicate-check ---------------------------

  Future<void> _openAddSheet() async {
    if (_products == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => _AddProductSheet(
        categories: _categories,
        onSubmit: (draft) => _handleNewProductDraft(sheetCtx, draft),
      ),
    );
  }

  Future<void> _handleNewProductDraft(BuildContext sheetCtx, _NewProductDraft draft) async {
    final candidate = await _repo.checkDuplicate(draft.name);
    if (!mounted || !sheetCtx.mounted) return;
    if (candidate == null) {
      await _createProduct(sheetCtx, draft);
      return;
    }
    final existing = _products!.firstWhere(
      (p) => p.id == candidate.existingId,
      orElse: () => _products!.first,
    );
    final choice = await _showDuplicatePrompt(sheetCtx, draft, existing, candidate);
    if (!mounted || !sheetCtx.mounted || choice == null) return;
    if (choice) {
      final updated = await _repo.addStockTo(existing.id, qty: 1);
      if (!mounted || !sheetCtx.mounted) return;
      setState(() {
        _products = [
          for (final p in _products!) p.id == updated.id ? updated : p,
        ];
      });
      Navigator.of(sheetCtx).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stock added to ${existing.name}')),
      );
      return;
    }
    await _createProduct(sheetCtx, draft, flagDuplicateOf: existing.name);
  }

  Future<void> _createProduct(BuildContext sheetCtx, _NewProductDraft draft, {String? flagDuplicateOf}) async {
    final created = await _repo.addProduct(
      name: draft.name,
      category: draft.category,
      supplier: draft.supplier,
      price: draft.price,
      colorTag: draft.colorTag,
      gstRate: draft.gstRate,
    );
    if (!mounted || !sheetCtx.mounted) return;
    setState(() {
      _products = [..._products!, created];
      _meta[created.id] = flagDuplicateOf == null
          ? const CatalogMeta()
          : CatalogMeta(isDuplicateSuspect: true, duplicateOfName: flagDuplicateOf);
    });
    Navigator.of(sheetCtx).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          flagDuplicateOf == null ? 'Product added' : 'Product saved — flagged for duplicate review',
        ),
      ),
    );
  }

  Future<bool?> _showDuplicatePrompt(
    BuildContext sheetCtx,
    _NewProductDraft draft,
    Product existing,
    DuplicateCandidate candidate,
  ) {
    return showModalBottomSheet<bool>(
      context: sheetCtx,
      isScrollControlled: true,
      builder: (_) => _DuplicatePromptSheet(draft: draft, existing: existing, candidate: candidate),
    );
  }
}

// ============================================================================
// Shared sheet chrome
// ============================================================================

/// Padding + keyboard-avoidance + scroll + a sane max-height for bottom-sheet
/// forms (the app theme already supplies the rounded top / drag handle via
/// `BottomSheetThemeData`, see core/theme/app_theme.dart).
Widget _sheetBody(BuildContext context, Widget child) {
  return Padding(
    padding: EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.sm,
      AppSpacing.lg,
      AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom,
    ),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      child: SingleChildScrollView(child: child),
    ),
  );
}

Widget _infoBanner(BuildContext context, {required IconData icon, required Tone tone, required String text}) {
  final p = context.palette;
  final c = tone.color(p);
  return Container(
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: c.withValues(alpha: 0.3)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: c),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: AppType.caption.copyWith(color: p.ink))),
      ],
    ),
  );
}

class _ColorSwatchPicker extends StatelessWidget {
  const _ColorSwatchPicker({required this.colors, required this.selected, required this.onSelect});

  final List<Color> colors;
  final Color selected;
  final ValueChanged<Color> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final c in colors)
          Semantics(
            button: true,
            label: '${colorTagLabel(c)}'
                '${c.toARGB32() == selected.toARGB32() ? ', selected' : ''}',
            child: GestureDetector(
              onTap: () => onSelect(c),
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: c.toARGB32() == selected.toARGB32() ? p.ink : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: c.toARGB32() == selected.toARGB32()
                    ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// Product detail / edit sheet
// ============================================================================

class _ProductDetailSheet extends StatefulWidget {
  const _ProductDetailSheet({
    required this.product,
    required this.meta,
    required this.categories,
    required this.onSave,
    required this.onDeactivate,
    required this.onReactivate,
  });

  final Product product;
  final CatalogMeta meta;
  final List<ProductCategory> categories;
  final Future<void> Function(Product updated) onSave;
  final Future<void> Function() onDeactivate;
  final Future<void> Function() onReactivate;

  @override
  State<_ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends State<_ProductDetailSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _priceCtrl = TextEditingController(
    text: widget.product.price > 0 ? widget.product.price.toStringAsFixed(0) : '',
  );
  late final TextEditingController _stockCtrl = TextEditingController(
    text: widget.product.stockQty?.toString() ?? '0',
  );
  late String _category = widget.product.category;
  late Color _colorTag = widget.product.colorTag;
  bool _busy = false;

  @override
  void dispose() {
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final updated = widget.product.withCatalogEdits(
      price: double.parse(_priceCtrl.text.trim()),
      category: _category,
      colorTag: _colorTag,
      stockQty: int.tryParse(_stockCtrl.text.trim()) ?? 0,
    );
    await _runBusy(() => widget.onSave(updated));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final product = widget.product;
    final meta = widget.meta;
    final swatches = <Color>{...kCatalogColorTags, product.colorTag}.toList();
    final categoryNames = <String>{...widget.categories.map((c) => c.name), product.category}.toList();

    return _sheetBody(
      context,
      Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProductThumb(product: product, size: 64),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name, style: AppType.h2.copyWith(color: p.ink)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          TonePill.tone(Tone.neutral, product.category, dense: true),
                          if (product.stockQty != null)
                            StockPill(product.stock, qty: product.stockQty, dense: true),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            if (!meta.isActive) ...[
              const SizedBox(height: AppSpacing.md),
              _infoBanner(
                context,
                icon: Icons.visibility_off_rounded,
                tone: Tone.neutral,
                text: 'Deactivated — hidden from staff selling. Reactivate to make it sellable again.',
              ),
            ],
            if (meta.isDuplicateSuspect) ...[
              const SizedBox(height: AppSpacing.md),
              _infoBanner(
                context,
                icon: Icons.content_copy_rounded,
                tone: Tone.warning,
                text: 'Possibly a duplicate of "${meta.duplicateOfName ?? 'another product'}" — '
                    'flagged for the web review queue.',
              ),
            ],
            if (product.price <= 0) ...[
              const SizedBox(height: AppSpacing.md),
              _infoBanner(
                context,
                icon: Icons.price_change_rounded,
                tone: Tone.danger,
                text: 'No selling price set — hidden from staff quick-pick until priced.',
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text('Editable details', style: AppType.title.copyWith(color: p.ink)),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Selling price', prefixText: '₹ '),
              validator: (v) {
                final val = double.tryParse((v ?? '').trim());
                if (val == null || val <= 0) return 'Enter a valid selling price';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _stockCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Stock quantity'),
              validator: (v) {
                final val = int.tryParse((v ?? '').trim());
                if (val == null || val < 0) return 'Enter a valid stock quantity';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [for (final name in categoryNames) DropdownMenuItem(value: name, child: Text(name))],
              onChanged: (v) {
                if (v != null) setState(() => _category = v);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Color tag', style: AppType.body.copyWith(color: p.inkMuted)),
            const SizedBox(height: 8),
            _ColorSwatchPicker(
              colors: swatches,
              selected: _colorTag,
              onSelect: (c) => setState(() => _colorTag = c),
            ),
            const SizedBox(height: AppSpacing.md),
            const SizedBox(height: AppSpacing.lg),
            Text('Details', style: AppType.title.copyWith(color: p.ink)),
            const SizedBox(height: 4),
            LabeledRow('Supplier', Text(product.supplier ?? '—')),
            LabeledRow('GST rate', Text('${product.gstRate}%')),
            LabeledRow('HSN code', Text(meta.hsnCode ?? '—')),
            LabeledRow('Cost price', Text(meta.costPrice != null ? Fmt.money0(meta.costPrice!) : '—')),
            LabeledRow('Reorder threshold', Text('${meta.reorderThreshold} units')),
            LabeledRow(
              'Aging threshold',
              Text(meta.agingThresholdDays != null ? '${meta.agingThresholdDays} days' : 'Default (60d)'),
            ),
            LabeledRow('Last sold', Text(meta.lastSoldAt != null ? Fmt.ago(meta.lastSoldAt!) : 'Never')),
            LabeledRow('Internal QR', Text(product.qrCode ?? 'Not printed yet')),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(_busy ? 'Saving…' : 'Save'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: meta.isActive
                  ? OutlinedButton.icon(
                      onPressed: _busy ? null : () => _runBusy(widget.onDeactivate),
                      icon: Icon(Icons.lock_rounded, size: 18, color: p.danger),
                      label: Text('Deactivate', style: TextStyle(color: p.danger)),
                      style: OutlinedButton.styleFrom(side: BorderSide(color: p.danger.withValues(alpha: 0.5))),
                    )
                  : FilledButton.icon(
                      onPressed: _busy ? null : () => _runBusy(widget.onReactivate),
                      icon: const Icon(Icons.lock_open_rounded, size: 18),
                      label: const Text('Reactivate'),
                      style: FilledButton.styleFrom(backgroundColor: p.success),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Add product sheet (mandatory duplicate-check happens on submit)
// ============================================================================

@immutable
class _NewProductDraft {
  const _NewProductDraft({
    required this.name,
    required this.category,
    required this.supplier,
    required this.price,
    required this.colorTag,
    required this.gstRate,
  });

  final String name;
  final String category;
  final String supplier;
  final double price;
  final Color colorTag;
  final int gstRate;
}

class _AddProductSheet extends StatefulWidget {
  const _AddProductSheet({required this.categories, required this.onSubmit});

  final List<ProductCategory> categories;
  final Future<void> Function(_NewProductDraft draft) onSubmit;

  @override
  State<_AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends State<_AddProductSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _supplierCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  late String? _category = widget.categories.isNotEmpty ? widget.categories.first.name : null;
  int _gstRate = 18;
  Color _colorTag = kCatalogColorTags.first;
  bool _busy = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _supplierCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final category = _category;
    if (category == null) return;
    setState(() => _busy = true);
    try {
      await widget.onSubmit(_NewProductDraft(
        name: _nameCtrl.text.trim(),
        category: category,
        supplier: _supplierCtrl.text.trim(),
        price: double.parse(_priceCtrl.text.trim()),
        colorTag: _colorTag,
        gstRate: _gstRate,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return _sheetBody(
      context,
      Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add product', style: AppType.h2.copyWith(color: p.ink)),
            const SizedBox(height: 4),
            Text(
              'Category and supplier are required — they narrow duplicate matching (R2).',
              style: AppType.caption.copyWith(color: p.inkMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Product name', hintText: 'e.g. Red Racer Car'),
              validator: (v) =>
                  (v == null || v.trim().length < 3) ? 'Enter a product name (3+ characters)' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final c in widget.categories) DropdownMenuItem(value: c.name, child: Text(c.name)),
              ],
              validator: (v) => v == null ? 'Pick a category' : null,
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _supplierCtrl,
              decoration: const InputDecoration(labelText: 'Supplier', hintText: 'e.g. Sunrise Toys'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Supplier is required' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Selling price', prefixText: '₹ '),
                    validator: (v) {
                      final val = double.tryParse((v ?? '').trim());
                      if (val == null || val <= 0) return 'Required';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _gstRate,
                    decoration: const InputDecoration(labelText: 'GST'),
                    items: [
                      for (final r in kCatalogGstRates) DropdownMenuItem(value: r, child: Text('$r%')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _gstRate = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const SizedBox(height: AppSpacing.md),
            Text('Color tag', style: AppType.body.copyWith(color: p.inkMuted)),
            const SizedBox(height: 8),
            _ColorSwatchPicker(
              colors: kCatalogColorTags,
              selected: _colorTag,
              onSelect: (c) => setState(() => _colorTag = c),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: const Icon(Icons.rule_rounded, size: 18),
                label: Text(_busy ? 'Saving…' : 'Check & save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Duplicate prompt — mandatory dup-check result (doc §4 "ADD → DUPLICATE PROMPT")
// ============================================================================

class _DuplicatePromptSheet extends StatelessWidget {
  const _DuplicatePromptSheet({required this.draft, required this.existing, required this.candidate});

  final _NewProductDraft draft;
  final Product existing;
  final DuplicateCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final draftProduct = Product(
      id: 'draft',
      name: draft.name,
      category: draft.category,
      price: draft.price,
      colorTag: draft.colorTag,
    );
    return _sheetBody(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: p.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text('This looks similar to an existing item', style: AppType.title.copyWith(color: p.ink)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    ProductThumb(product: draftProduct, size: 88),
                    const SizedBox(height: 6),
                    Text('NEW', style: AppType.label.copyWith(color: p.inkMuted, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.compare_arrows_rounded, color: p.inkMuted),
                    const SizedBox(height: 6),
                    TonePill.tone(Tone.warning, 'score ${candidate.score.toStringAsFixed(2)}', dense: true),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    ProductThumb(product: existing, size: 88),
                    const SizedBox(height: 6),
                    Text(
                      existing.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppType.label.copyWith(color: p.ink, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Matched on ${candidate.matchType}. "Yes" adds stock to the existing product instead of '
            'creating a new one; an unresolved "No" is flagged for the web review queue.',
            style: AppType.caption.copyWith(color: p.inkMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: Text(
                'Yes — same item (add stock to ${existing.name})',
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(false),
              icon: const Icon(Icons.fiber_new_rounded, size: 18),
              label: const Text("No — it's a new product"),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }
}
