import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/core.dart';
import 'new_sale_data.dart';
import 'receipt_data.dart';
import 'receipt_screen.dart';
import '../../core/models/branches_data.dart';

/// Staff New Sale — the billing engine. A single screen with a sheet stack
/// (not a wizard): find item (quick-pick / category / search / QR / voice) →
/// `ItemConfirmCard` → cart → optional owner-gated discount → payment →
/// confirm → receipt. Doc: docs/mobile/staff/sales/new-sale.md (Requirement 4
/// — the Sales Flow, the highest-criticality staff screen).
class NewSaleScreen extends StatefulWidget {
  const NewSaleScreen({super.key, this.preAdd});

  /// A product pre-added to the cart when arriving from a quick-pick tile.
  /// Shown via [ItemConfirmCard] immediately on open — even quick-pick items
  /// are confirmed before they enter the cart (new-sale doc rule 2).
  final Product? preAdd;

  @override
  State<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends State<NewSaleScreen> {
  final _repo = const NewSaleRepository();
  final _searchCtrl = TextEditingController();

  NewSaleCatalog? _catalog;
  List<CartLine> _cart = [];
  ProductCategory? _selectedCategory;
  String _query = '';
  PaymentMode _paymentMode = PaymentMode.cash;
  String? _selectedBranchId;

  double get _subtotal => _cart.fold(0.0, (a, l) => a + l.lineTotal);
  double get _gstTotal => _cart.fold(0.0, (a, l) => a + l.toReceiptLine().gstAmount);
  double get _cartTotal => _subtotal;
  int get _cartUnits => _cart.fold(0, (a, l) => a + l.qty);

  @override
  void initState() {
    super.initState();
    _repo.loadCatalog().then((c) {
      if (mounted) setState(() => _catalog = c);
    });
    final pre = widget.preAdd;
    if (pre != null) {
      // Defer to the first frame so the sheet animates in over a built screen.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openConfirm(pre);
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Cart operations
  // ---------------------------------------------------------------------

  /// `ItemConfirmCard` precedes every add — even quick-pick/QR — so a wrong
  /// item is caught by eye before it enters the cart (new-sale doc rule 2).
  void _openConfirm(Product product, {int initialQty = 1}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ItemConfirmCard(
        product: product,
        initialQty: initialQty,
        onAdd: (qty, unitPrice) {
          _addToCart(product, qty, unitPrice);
          Navigator.pop(context);
        },
      ),
    );
  }

  /// Merges into an existing line for the same product **at the same unit
  /// price** rather than adding a duplicate row (new-sale doc rule 4) — a
  /// custom-priced add stays on its own line so a price override never
  /// silently blends into catalog-priced units. Add-to-cart is instant, no
  /// spinner (rule 1 / design-system law 1).
  void _addToCart(Product product, int qty, [double? unitPriceOverride]) {
    final effectivePrice = unitPriceOverride ?? product.price;
    setState(() {
      final i = _cart.indexWhere(
        (l) => l.product.id == product.id && (l.unitPrice - effectivePrice).abs() < 0.005,
      );
      if (i >= 0) {
        _cart[i].qty += qty;
      } else {
        _cart.add(CartLine(product: product, qty: qty, priceOverride: unitPriceOverride));
      }
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: const Duration(milliseconds: 1100),
        content: Text(
          'Added ${qty > 1 ? '$qty × ' : ''}${product.name}'
          '${unitPriceOverride != null ? ' @ ${Fmt.money0(effectivePrice)}' : ''}',
        ),
      ));
  }

  /// The expanded `CartSheet` (design-system §6) — running total, swipe-to-
  /// remove lines, payment mode and Confirm, all rebuilt live via
  /// [StatefulBuilder] over the shared `_cart`/`_paymentMode` fields.
  void _openCart() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (_) => StatefulBuilder(builder: _cartSheetContent),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  Widget _cartSheetContent(BuildContext _, StateSetter setSheetState) {
    final p = context.palette;
    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(color: p.surface, borderRadius: AppRadii.sheet),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: p.border, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.shopping_cart_rounded, color: p.primary, size: 18),
                  const SizedBox(width: 8),
                  Text('Cart', style: AppType.title.copyWith(color: p.ink)),
                  const Spacer(),
                  Text(
                    '$_cartUnits item${_cartUnits == 1 ? '' : 's'}',
                    style: AppType.caption.copyWith(color: p.inkMuted),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: p.border),
            Expanded(
              child: _cart.isEmpty
                  ? const EmptyState(
                      icon: Icons.shopping_cart_outlined,
                      title: 'Cart is empty',
                      message: 'Add an item to start billing.',
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      itemCount: _cart.length,
                      itemBuilder: (_, i) => _cartLineTile(_cart[i], setSheetState),
                    ),
            ),
            _cartFooter(setSheetState),
          ],
        ),
      ),
    );
  }

  Widget _cartLineTile(CartLine line, StateSetter setSheetState) {
    final p = context.palette;
    return Dismissible(
      // Identity-based, not product id — a price-overridden line lives
      // alongside a catalog-priced line for the same product (see
      // `_addToCart`), so the product id alone is no longer unique per line.
      key: ObjectKey(line),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: p.danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete_outline_rounded, color: p.danger),
      ),
      onDismissed: (_) {
        final removedIndex = _cart.indexOf(line);
        setSheetState(() => _cart.remove(line));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Removed ${line.product.name}'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => setSheetState(
              () => _cart.insert(removedIndex.clamp(0, _cart.length).toInt(), line),
            ),
          ),
        ));
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: AppCard(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ProductThumb(product: line.product, size: 44),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.product.name,
                      style: AppType.body.copyWith(color: p.ink, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => _editPrice(line, setSheetState),
                      child: Text(
                        '${Fmt.money0(line.unitPrice)} each',
                        style: AppType.caption.copyWith(
                          color: line.isPriceOverridden ? p.info : p.inkMuted,
                          fontWeight: line.isPriceOverridden ? FontWeight.w700 : null,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    if (line.isPriceOverridden) ...[
                      const SizedBox(height: 4),
                      TonePill(
                        label: 'Custom price · was ${Fmt.money0(line.product.price)}',
                        color: p.info,
                        icon: Icons.flag_rounded,
                        dense: true,
                      ),
                    ],
                    if (line.product.stockQty != null && line.qty > line.product.stockQty!) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 13, color: p.warning),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Only ${line.product.stockQty} in stock — selling anyway',
                              style: AppType.caption.copyWith(color: p.warning, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  QtyStepper(
                    value: line.qty,
                    size: 34,
                    onChanged: (v) => setSheetState(() => line.qty = v),
                    onTapValue: () => _editQty(line, setSheetState),
                  ),
                  const SizedBox(height: 4),
                  MoneyText(Fmt.money(line.lineTotal)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tapping the qty number opens the `NumericPad` for bulk entry (new-sale
  /// doc §7 / §5 row 9) — `+`/`-` on [QtyStepper] stays for fast small edits.
  Future<void> _editQty(CartLine line, StateSetter setSheetState) async {
    String buffer = '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (sheetCtx, setQtyState) {
          final p = context.palette;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              20,
              24,
              20 + MediaQuery.of(sheetCtx).viewInsets.bottom + MediaQuery.of(sheetCtx).padding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Set quantity', style: AppType.title.copyWith(color: p.ink)),
                const SizedBox(height: 4),
                Text(line.product.name, style: AppType.caption.copyWith(color: p.inkMuted)),
                const SizedBox(height: 16),
                Text(buffer.isEmpty ? '${line.qty}' : buffer, style: AppType.display.copyWith(color: p.ink)),
                const SizedBox(height: 16),
                NumericPad(
                  onKey: (d) => setQtyState(() {
                    if (buffer.length < 3) buffer += d;
                  }),
                  onDelete: () => setQtyState(
                    () => buffer = buffer.isEmpty ? '' : buffer.substring(0, buffer.length - 1),
                  ),
                  confirmLabel: 'Set',
                  onConfirm: () {
                    final v = int.tryParse(buffer);
                    if (v != null && v > 0) {
                      setSheetState(() => line.qty = v.clamp(1, 999).toInt());
                    }
                    Navigator.of(sheetCtx).pop();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Tapping the "₹X each" label opens a price override for that line — up
  /// or down, no owner PIN — so a floor-negotiated or markdown price can be
  /// rung in without leaving the cart. The line is flagged ("Custom price")
  /// and carried onto the receipt for the owner to review later.
  Future<void> _editPrice(CartLine line, StateSetter setSheetState) async {
    final result = await showPriceEditSheet(
      context,
      productName: line.product.name,
      catalogPrice: line.product.price,
      currentPrice: line.unitPrice,
    );
    if (result == null) return;
    setSheetState(() => line.priceOverride = result == line.product.price ? null : result);
  }

  Widget _cartFooter(StateSetter setSheetState) {
    final p = context.palette;
    final subtotal = _subtotal;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: p.border))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LabeledRow('Subtotal', MoneyText(Fmt.money(subtotal))),
          LabeledRow(
            'GST (incl.)',
            Text('(${Fmt.money(_gstTotal)})', style: AppType.caption.copyWith(color: p.inkMuted)),
          ),
          Divider(color: p.border),
          LabeledRow('TOTAL', MoneyText(Fmt.money(_cartTotal), style: AppType.h2), emphasize: true),
          const SizedBox(height: 10),
          _Segmented<PaymentMode>(
            value: _paymentMode,
            options: {for (final m in PaymentMode.values) m: m.label},
            onChanged: (v) => setSheetState(() => _paymentMode = v),
          ),
          const SizedBox(height: 12),
          ListenableBuilder(
            listenable: branchesData,
            builder: (context, _) {
              final branches = branchesData.branches;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _selectedBranchId == null ? p.danger : p.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _selectedBranchId,
                    isExpanded: true,
                    hint: const Text('Select Branch (Required)'),
                    icon: Icon(Icons.store_rounded, color: p.primary),
                    items: branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                    onChanged: (val) => setSheetState(() => _selectedBranchId = val),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          if (_cart.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Add an item to start', style: AppType.caption.copyWith(color: p.inkMuted)),
            ),
          SizedBox(
            height: AppSpacing.primaryAction,
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (_cart.isEmpty || _selectedBranchId == null) ? null : _confirmSale,
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text('CONFIRM SALE'),
            ),
          ),
        ],
      ),
    );
  }

  // discount request sheet removed

  /// Writes the sale (rule 1: never blocks) and routes to the receipt. If
  /// this screen was pushed on top of something (dashboard button/quick-pick/
  /// catalog "Add to sale"), it's replaced so **back from the receipt lands
  /// on that origin** (receipt doc: "from a fresh sale → dashboard"); if it's
  /// the persistent Sell tab, the receipt is simply pushed above it.
  Future<void> _confirmSale() async {
    if (_cart.isEmpty || _selectedBranchId == null) return;
    final nav = Navigator.of(context);
    final isFirstRoute = ModalRoute.of(context)?.isFirst ?? true;
    final session = SessionScope.of(context);
    
    final branchName = branchesData.branches.firstWhere((b) => b.id == _selectedBranchId).name;

    final receipt = await _repo.confirmSale(
      lines: _cart,
      paymentMode: _paymentMode,
      staffName: session.account?.name ?? 'Staff',
      branchName: branchName,
    );
    if (!mounted) return;
    setState(() {
      _cart = [];
      _paymentMode = PaymentMode.cash;
      _selectedBranchId = null;
      _selectedCategory = null;
      _query = '';
      _searchCtrl.clear();
    });
    nav.pop(); // dismiss the CartSheet
    if (isFirstRoute) {
      nav.push(MaterialPageRoute(builder: (_) => ReceiptScreen(data: receipt)));
    } else {
      nav.pushReplacement(MaterialPageRoute(builder: (_) => ReceiptScreen(data: receipt)));
    }
  }

  /// Back with a non-empty cart prompts a discard confirm — forgiving, not
  /// punishing (new-sale doc rule 16 / design-system law 4).
  Future<void> _confirmDiscard() async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard this sale?'),
        content: Text('${_cart.length} item${_cart.length == 1 ? '' : 's'} in the cart will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep editing')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard')),
        ],
      ),
    );
    if (res == true && mounted) {
      setState(() {
        _cart = [];
      });
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    }
  }

  // ---------------------------------------------------------------------
  // Find item: quick-pick / category / search / QR / voice
  // ---------------------------------------------------------------------

  Future<void> _openScannerSheet() async {
    final catalog = _catalog;
    final product = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ScanSheet(onResolve: (code) => catalog?.byQr(code)),
    );
    if (product != null && mounted) _openConfirm(product);
  }

  Future<void> _openVoiceSheet() async {
    final transcript = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _VoiceSheet(),
    );
    if (transcript == null || !mounted) return;
    _searchCtrl.text = transcript;
    setState(() => _query = transcript);
  }

  void _showQuickInfo(Product product) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => _QuickInfoSheet(
        product: product,
        onAdd: () {
          Navigator.of(sheetCtx).pop();
          _openConfirm(product);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _cart.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmDiscard();
      },
      child: AppScaffold(
        title: 'New Sale',
        body: _catalog == null ? _loadingBody() : _body(),
        bottomBar: _cartBar(),
      ),
    );
  }

  Widget _loadingBody() => ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          SkeletonBox(height: 48, radius: 24),
          SizedBox(height: 16),
          SkeletonBox(height: 150, radius: 14),
          SizedBox(height: 16),
          SkeletonBox(height: 220, radius: 14),
        ],
      );

  Widget _body() {
    return Column(
      children: [
        _searchBar(),
        Expanded(child: _mainContent()),
      ],
    );
  }

  Widget _searchBar() {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: AppRadii.chip,
                border: Border.all(color: p.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 20, color: p.inkMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _query = v),
                      textInputAction: TextInputAction.search,
                      style: AppType.body.copyWith(color: p.ink),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isCollapsed: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'Search toys…',
                        hintStyle: AppType.body.copyWith(color: p.inkMuted),
                      ),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    InkWell(
                      onTap: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                      child: Icon(Icons.close_rounded, size: 18, color: p.inkMuted),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _RoundIconButton(icon: Icons.mic_rounded, tooltip: 'Voice search', onTap: _openVoiceSheet),
          const SizedBox(width: 8),
          _RoundIconButton(icon: Icons.qr_code_scanner_rounded, tooltip: 'Scan QR', onTap: _openScannerSheet),
        ],
      ),
    );
  }

  Widget _mainContent() {
    if (_query.trim().isNotEmpty) return _searchResults();
    return _homeContent();
  }

  Widget _homeContent() {
    final catalog = _catalog!;
    final p = context.palette;
    
    final products = _selectedCategory == null 
        ? catalog.products 
        : catalog.byCategory(_selectedCategory!.name);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (catalog.quickPicks.isNotEmpty && _selectedCategory == null) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SectionHeader(
              title: 'Quick pick',
              subtitle: 'Your hot items · 1-tap add',
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: _quickPickStrip(catalog.quickPicks),
          ),
          const SizedBox(height: 16),
        ],
        SizedBox(
          height: 40,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: catalog.categories.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              if (i == 0) {
                 final sel = _selectedCategory == null;
                 return ChoiceChip(
                   label: const Text('All Products'),
                   selected: sel,
                   onSelected: (_) => setState(() => _selectedCategory = null),
                 );
              }
              final c = catalog.categories[i - 1];
              final sel = _selectedCategory == c;
              return ChoiceChip(
                label: Text(c.name),
                selected: sel,
                onSelected: (_) => setState(() => _selectedCategory = c),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _productGrid(products),
        ),
      ],
    );
  }

  Widget _quickPickStrip(List<Product> items) {
    return SizedBox(
      height: 172,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => SizedBox(
          width: 128,
          child: ProductTile(
            product: items[i],
            onTap: () => _openConfirm(items[i]),
            onLongPress: () => _showQuickInfo(items[i]),
          ),
        ),
      ),
    );
  }

  Widget _searchResults() {
    final p = context.palette;
    final results = _catalog!.search(_query);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Text(
            results.isEmpty
                ? 'No matches for "$_query"'
                : '${results.length} result${results.length == 1 ? '' : 's'} for "$_query"',
            style: AppType.label.copyWith(color: p.inkMuted),
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No toys found',
                  message: 'Try a category, QR scan or voice search instead.',
                  actionLabel: 'Clear search',
                  onAction: () {
                    _searchCtrl.clear();
                    setState(() => _query = '');
                  },
                )
              : _productGrid(results),
        ),
      ],
    );
  }

  Widget _productGrid(List<Product> products) {
    final cols = MediaQuery.sizeOf(context).width >= 600 ? 3 : 2;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: products.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (_, i) {
        final product = products[i];
        return ProductTile(
          product: product,
          onTap: () => _openConfirm(product),
          onLongPress: () => _showQuickInfo(product),
        );
      },
    );
  }

  Widget _cartBar() {
    final p = context.palette;
    final isEmpty = _cart.isEmpty;
    // Muted when empty so the bar doesn't read as an active CTA with nothing
    // to act on; still tappable (never a dead end) — it just opens to the
    // cart's own empty state.
    final accent = isEmpty ? p.inkMuted : p.primary;
    return AppBottomBar(
      child: InkWell(
        onTap: _openCart,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(Icons.shopping_cart_rounded, color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isEmpty ? 'Cart is empty' : '$_cartUnits item${_cartUnits == 1 ? '' : 's'}',
                    style: AppType.label.copyWith(color: p.inkMuted),
                  ),
                  Text(
                    Fmt.money(_cartTotal),
                    style: AppType.h2.copyWith(color: isEmpty ? p.inkMuted : p.ink),
                  ),
                ],
              ),
            ),
            if (!isEmpty) ...[
              Text('View', style: AppType.label.copyWith(color: accent, fontWeight: FontWeight.w700)),
              Icon(Icons.chevron_right_rounded, color: accent),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small reusable pieces private to this screen
// ---------------------------------------------------------------------------

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap, required this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: p.primary.withValues(alpha: 0.1),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(width: 48, height: 48, child: Icon(icon, color: p.primary, size: 22)),
        ),
      ),
    );
  }
}

/// Small pill-group toggle (Amount/Percent, payment mode) — mirrors the
/// staff dashboard's period toggle for a consistent look across screens.
class _Segmented<T> extends StatelessWidget {
  const _Segmented({required this.value, required this.options, required this.onChanged});
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: AppRadii.chip,
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          for (final e in options.entries)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: e.key == value ? p.primary : Colors.transparent,
                    borderRadius: AppRadii.chip,
                  ),
                  child: Text(
                    e.value,
                    textAlign: TextAlign.center,
                    style: AppType.label.copyWith(
                      color: e.key == value ? p.primaryInk : p.inkMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Long-press quick info (new-sale doc §5 row 6) — a lighter glance than the
/// full `ItemConfirmCard`, with a shortcut into it.
class _QuickInfoSheet extends StatelessWidget {
  const _QuickInfoSheet({required this.product, required this.onAdd});
  final Product product;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProductThumb(product: product, size: 64),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, style: AppType.title.copyWith(color: p.ink)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(Fmt.money(product.price), style: AppType.h2.copyWith(color: p.ink)),
                        if (product.mrp != null && product.mrp! > product.price) ...[
                          const SizedBox(width: 8),
                          Text(
                            Fmt.money0(product.mrp!),
                            style: AppType.caption.copyWith(
                              color: p.inkMuted,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StockPill(product.stock, qty: product.stockQty, dense: true),
              TonePill(
                label: product.shelf != null ? 'Rack ${product.shelf}' : 'No shelf yet',
                color: p.info,
                icon: Icons.inventory_2_rounded,
                dense: true,
              ),
              TonePill(
                label: '${product.gstRate}% GST',
                color: p.inkMuted,
                icon: Icons.receipt_rounded,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: AppSpacing.primaryAction,
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: product.stock == StockState.out ? null : onAdd,
              icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
              label: const Text('Add to cart'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mock QR scanner (design-system §6 `ScannerOverlay`) — no camera plugin in
/// this prototype, so it offers a "simulate scan" demo path plus the manual-
/// entry fallback the doc calls out for a damaged sticker (new-sale doc §7).
class _ScanSheet extends StatefulWidget {
  const _ScanSheet({required this.onResolve});
  final Product? Function(String code) onResolve;

  @override
  State<_ScanSheet> createState() => _ScanSheetState();
}

class _ScanSheetState extends State<_ScanSheet> {
  final _codeCtrl = TextEditingController();
  bool _notFound = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  void _lookup(String code) {
    if (code.trim().isEmpty) return;
    final product = widget.onResolve(code);
    if (product != null) {
      Navigator.of(context).pop(product);
    } else {
      setState(() => _notFound = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.qr_code_scanner_rounded, color: p.primary),
              const SizedBox(width: 8),
              Text('Scan QR sticker', style: AppType.h2.copyWith(color: p.ink)),
            ],
          ),
          const SizedBox(height: 14),
          AspectRatio(
            aspectRatio: 1.8,
            child: Container(
              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(16)),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.qr_code_2_rounded, size: 60, color: Colors.white24),
                  const Positioned(
                    bottom: 10,
                    child: Text(
                      'Camera preview unavailable in prototype',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      onPressed: () => setState(() => _torchOn = !_torchOn),
                      icon: Icon(Icons.flash_on_rounded, color: _torchOn ? Colors.amber : Colors.white70),
                      tooltip: 'Torch',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _lookup('NS-001'),
              icon: const Icon(Icons.qr_code_2_rounded, size: 18),
              label: const Text('Simulate scan (demo)'),
            ),
          ),
          const SizedBox(height: 16),
          Text('Sticker damaged? Enter the code manually', style: AppType.label.copyWith(color: p.inkMuted)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    hintText: 'e.g. NS-001',
                  ),
                  onSubmitted: _lookup,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: () => _lookup(_codeCtrl.text), child: const Text('Look up')),
            ],
          ),
          if (_notFound) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.error_outline_rounded, size: 16, color: p.danger),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Not found — try search instead.',
                    style: AppType.caption.copyWith(color: p.danger),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Mock voice search (design-system §6 `VoiceSearchButton`) — simulates
/// on-device STT with a progressively-revealed partial transcript (new-sale
/// doc §5 row 2, §7).
class _VoiceSheet extends StatefulWidget {
  const _VoiceSheet();

  @override
  State<_VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends State<_VoiceSheet> {
  static const _phrases = ['ro', 'robo', 'robot', 'robot walker'];
  int _step = 0;
  bool _listening = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 380), (t) {
      if (!mounted) return;
      setState(() {
        if (_step < _phrases.length - 1) {
          _step++;
        } else {
          _listening = false;
          t.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final transcript = _phrases[_step];
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.mic_rounded, color: p.primary),
              const SizedBox(width: 8),
              Text('Voice search', style: AppType.h2.copyWith(color: p.ink)),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: (_listening ? p.primary : p.success).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.mic_rounded, size: 36, color: _listening ? p.primary : p.success),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(_listening ? 'Listening…' : 'Heard you', style: AppType.label.copyWith(color: p.inkMuted)),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('"$transcript"', style: AppType.h1.copyWith(color: p.ink), textAlign: TextAlign.center),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _listening ? null : () => Navigator.of(context).pop(transcript),
                  icon: const Icon(Icons.search_rounded, size: 18),
                  label: const Text('Use this search'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
