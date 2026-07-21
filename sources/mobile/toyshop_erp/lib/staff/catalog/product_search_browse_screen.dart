import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../sales/new_sale_screen.dart';
import 'product_search_browse_data.dart';

/// Staff Product Search & Browse — read-only catalog explorer.
/// Doc: docs/mobile/staff/catalog/product-search-browse.md (Requirement 3 —
/// easier-than-photo product ID: QR, color, shelf, voice, favorites).
class ProductSearchBrowseScreen extends StatefulWidget {
  const ProductSearchBrowseScreen({super.key});

  @override
  State<ProductSearchBrowseScreen> createState() => _ProductSearchBrowseScreenState();
}

class _ProductSearchBrowseScreenState extends State<ProductSearchBrowseScreen> {
  final _repo = const ProductSearchBrowseRepository();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<Product>? _all;
  List<ProductCategory>? _categories;

  String _query = '';
  String? _selectedCategoryId;
  Color? _selectedColor;
  String? _selectedShelf;
  bool _favoritesOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final cats = await _repo.categories();
    final products = await _repo.search();
    if (!mounted) return;
    setState(() {
      _categories = cats;
      _all = products;
    });
  }

  Future<void> _refresh() async {
    final products = await _repo.search();
    if (!mounted) return;
    setState(() => _all = products);
  }

  void _onQueryChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _query = v);
    });
  }

  void _clearQuery() {
    _debounce?.cancel();
    _searchCtrl.clear();
    setState(() => _query = '');
  }

  void _clearAllFilters() {
    _debounce?.cancel();
    _searchCtrl.clear();
    setState(() {
      _query = '';
      _selectedCategoryId = null;
      _selectedColor = null;
      _selectedShelf = null;
      _favoritesOnly = false;
    });
  }

  List<Product> get _filtered {
    final all = _all;
    if (all == null) return const [];
    final categoryName = _selectedCategoryId == null
        ? null
        : _categories!
            .firstWhere((c) => c.id == _selectedCategoryId, orElse: () => _categories!.first)
            .name;
    return filterProducts(
      all,
      query: _query,
      categoryName: categoryName,
      color: _selectedColor,
      shelf: _selectedShelf,
      favoritesOnly: _favoritesOnly,
    );
  }

  Future<Product> _toggleFavorite(Product product) async {
    final updated = await _repo.toggleFavorite(product.id);
    if (!mounted) return updated;
    setState(() {
      _all = _all?.map((p) => p.id == updated.id ? updated : p).toList();
    });
    final online = SessionScope.of(context).isOnline;
    final msg = updated.isFavorite ? 'Added to favorites' : 'Removed from favorites';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(online ? msg : '$msg · will sync when online'),
        duration: const Duration(seconds: 2),
      ),
    );
    return updated;
  }

  void _addToSale(Product product) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => NewSaleScreen(preAdd: product)));
  }

  /// One-tap add straight from a tile — skips the detail sheet for the
  /// common "I already know this item" case. Still goes through
  /// `ItemConfirmCard` in New Sale (confirm-before-commit, new-sale doc rule 2).
  void _quickAddToSale(Product product) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => NewSaleScreen(preAdd: product)));
  }

  Future<void> _openDetail(Product product) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductDetailSheet(
        product: product,
        onToggleFavorite: _toggleFavorite,
        onAddToSale: _addToSale,
      ),
    );
  }

  Future<void> _openQuickInfo(Product product) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuickInfoSheet(
        product: product,
        onViewDetails: () {
          Navigator.of(context).pop();
          _openDetail(product);
        },
      ),
    );
  }

  Future<void> _openScanner() async {
    final product = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScannerSheet(onResolve: _repo.resolveQr),
    );
    if (product != null && mounted) _openDetail(product);
  }

  Future<void> _openVoiceSearch() async {
    final transcript = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _VoiceSearchSheet(),
    );
    if (transcript == null || !mounted) return;
    _searchCtrl.text = transcript;
    setState(() => _query = transcript);
  }

  /// Combined color + shelf filter sheet — one entry point instead of two,
  /// so busy staff have fewer top-level controls to scan.
  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<_FilterSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FiltersSheet(
        colorOptions: _repo.colorOptions,
        shelfOptions: _repo.shelfOptions,
        initialColor: _selectedColor,
        initialShelf: _selectedShelf,
      ),
    );
    if (result == null) return;
    setState(() {
      _selectedColor = result.color;
      _selectedShelf = result.shelf;
    });
  }

  String _sectionTitle() {
    if (_favoritesOnly) return 'Favorites';
    if (_selectedCategoryId == null) return 'All toys';
    return _categories!.firstWhere((c) => c.id == _selectedCategoryId).name;
  }

  @override
  Widget build(BuildContext context) {
    final all = _all;
    final cats = _categories;
    final ready = all != null && cats != null;
    return AppScaffold(
      title: 'Catalog',
      subtitle: ready ? '${_filtered.length} of ${all.length} toys' : null,
      body: ready ? _content() : _loadingBody(),
    );
  }

  Widget _loadingBody() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const SkeletonBox(height: 48, radius: 24),
        const SizedBox(height: AppSpacing.lg),
        const SkeletonBox(height: 60, radius: 30),
        const SizedBox(height: AppSpacing.lg),
        const SkeletonBox(height: 36, radius: 18),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: const [
            Expanded(child: SkeletonBox(height: 160, radius: 14)),
            SizedBox(width: AppSpacing.md),
            Expanded(child: SkeletonBox(height: 160, radius: 14)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: const [
            Expanded(child: SkeletonBox(height: 160, radius: 14)),
            SizedBox(width: AppSpacing.md),
            Expanded(child: SkeletonBox(height: 160, radius: 14)),
          ],
        ),
      ],
    );
  }

  Widget _content() {
    final filtered = _filtered;
    final favorites = _all!.where((p) => p.isFavorite).toList();
    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedHeaderDelegate(height: 64, child: _searchBar()),
          ),
          SliverToBoxAdapter(child: _filterBarRow()),
          SliverToBoxAdapter(child: _activeFiltersRow()),
          if (!_favoritesOnly && favorites.isNotEmpty)
            SliverToBoxAdapter(child: _favoritesStrip(favorites)),
          SliverToBoxAdapter(child: _categoryChipsRow()),
          SliverToBoxAdapter(
            child: SectionHeader(
              title: _sectionTitle(),
              subtitle: '${filtered.length} item${filtered.length == 1 ? '' : 's'}',
            ),
          ),
          if (filtered.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: _emptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                  childAspectRatio: 0.74,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final product = filtered[i];
                    return ProductTile(
                      product: product,
                      onTap: () => _openDetail(product),
                      onLongPress: () => _openQuickInfo(product),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _FavoriteToggle(
                            isFavorite: product.isFavorite,
                            onTap: () => _toggleFavorite(product),
                          ),
                          const SizedBox(width: 4),
                          _QuickAddButton(
                            enabled: product.stockQty != 0,
                            onTap: () => _quickAddToSale(product),
                          ),
                        ],
                      ),
                    );
                  },
                  childCount: filtered.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: AppRadii.chip,
                border: Border.all(color: p.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 20, color: p.inkMuted),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: _onQueryChanged,
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
                  if (_query.isNotEmpty || _searchCtrl.text.isNotEmpty)
                    InkWell(
                      onTap: _clearQuery,
                      child: Icon(Icons.close_rounded, size: 18, color: p.inkMuted),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _RoundIconButton(icon: Icons.mic_rounded, onTap: _openVoiceSearch, tooltip: 'Voice search'),
          const SizedBox(width: AppSpacing.sm),
          _RoundIconButton(
            icon: Icons.qr_code_scanner_rounded,
            onTap: _openScanner,
            tooltip: 'Scan QR',
          ),
        ],
      ),
    );
  }

  /// Compact filter bar — Scan/Voice already live in the pinned search bar,
  /// so this only offers what isn't there: color+shelf (combined into one
  /// "Filters" sheet) and the favorites toggle. Two pills instead of five
  /// icon tiles, freeing up screen space for the product grid.
  Widget _filterBarRow() {
    final filtersActive = _selectedColor != null || _selectedShelf != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
      child: Row(
        children: [
          _FilterBarButton(
            icon: Icons.tune_rounded,
            label: 'Filters',
            active: filtersActive,
            onTap: _openFilters,
          ),
          const SizedBox(width: AppSpacing.sm),
          _FilterBarButton(
            icon: Icons.star_rounded,
            label: 'Favorites',
            active: _favoritesOnly,
            onTap: () => setState(() => _favoritesOnly = !_favoritesOnly),
          ),
        ],
      ),
    );
  }

  Widget _activeFiltersRow() {
    final chips = <Widget>[];
    if (_selectedColor != null) {
      chips.add(_Chip(
        label: colorLabel(_selectedColor!),
        selected: true,
        dotColor: _selectedColor,
        trailing: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
        onTap: () => setState(() => _selectedColor = null),
      ));
    }
    if (_selectedShelf != null) {
      chips.add(_Chip(
        label: 'Rack $_selectedShelf',
        selected: true,
        icon: Icons.inventory_2_rounded,
        trailing: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
        onTap: () => setState(() => _selectedShelf = null),
      ));
    }
    if (_query.isNotEmpty) {
      chips.add(_Chip(
        label: '"$_query"',
        selected: true,
        icon: Icons.search_rounded,
        trailing: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
        onTap: _clearQuery,
      ));
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...chips,
          TextButton(onPressed: _clearAllFilters, child: const Text('Clear all')),
        ],
      ),
    );
  }

  Widget _favoritesStrip(List<Product> favorites) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
            child: Row(
              children: [
                const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                const SizedBox(width: 6),
                Text('Favorites', style: AppType.title.copyWith(color: p.ink)),
              ],
            ),
          ),
          SizedBox(
            height: 172,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              scrollDirection: Axis.horizontal,
              itemCount: favorites.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (_, i) => SizedBox(
                width: 128,
                child: ProductTile(
                  product: favorites[i],
                  onTap: () => _openDetail(favorites[i]),
                  onLongPress: () => _openQuickInfo(favorites[i]),
                  trailing: _QuickAddButton(
                    enabled: favorites[i].stockQty != 0,
                    onTap: () => _quickAddToSale(favorites[i]),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChipsRow() {
    final cats = _categories!;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          scrollDirection: Axis.horizontal,
          itemCount: cats.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
          itemBuilder: (_, i) {
            if (i == 0) {
              return _Chip(
                label: 'All',
                selected: _selectedCategoryId == null,
                icon: Icons.apps_rounded,
                onTap: () => setState(() => _selectedCategoryId = null),
              );
            }
            final c = cats[i - 1];
            return _Chip(
              label: c.name,
              selected: _selectedCategoryId == c.id,
              icon: c.icon,
              dotColor: c.color,
              onTap: () => setState(() => _selectedCategoryId = c.id),
            );
          },
        ),
      ),
    );
  }

  Widget _emptyState() {
    final hasFilters = _selectedCategoryId != null ||
        _selectedColor != null ||
        _selectedShelf != null ||
        _favoritesOnly ||
        _query.isNotEmpty;
    return EmptyState(
      icon: Icons.search_off_rounded,
      title: 'No toys found',
      message: hasFilters
          ? 'Try clearing filters, or use voice/QR search instead.'
          : 'No products in this catalog yet.',
      actionLabel: hasFilters ? 'Clear all filters' : null,
      onAction: hasFilters ? _clearAllFilters : null,
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

/// Compact pill used in the filter bar (Filters / Favorites) — icon + label
/// in one 40dp-tall control instead of the old icon-circle-plus-caption
/// column, so the row takes noticeably less vertical space.
class _FilterBarButton extends StatelessWidget {
  const _FilterBarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = active ? p.primaryInk : p.ink;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.chip,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: active ? p.primary : p.surface,
          borderRadius: AppRadii.chip,
          border: Border.all(color: active ? p.primary : p.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 6),
            Text(label, style: AppType.label.copyWith(color: fg, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// One-tap "add to sale" affordance on a tile — the fast path for a known
/// item, skipping the detail sheet. Hidden behind [enabled] for out-of-stock
/// tiles, which already block [ProductTile.onTap].
class _QuickAddButton extends StatelessWidget {
  const _QuickAddButton({required this.enabled, required this.onTap});
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (!enabled) return const SizedBox(width: 22, height: 22);
    return Tooltip(
      message: 'Add to sale',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle),
          child: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}

/// Pins [child] to a fixed height at the top of a [CustomScrollView] — used
/// so the search/scan/voice bar stays reachable while a long catalog scrolls
/// underneath it (busy staff shouldn't have to scroll back up to search).
class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  _PinnedHeaderDelegate({required this.child, required this.height});
  final Widget child;
  final double height;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ColoredBox(color: context.palette.bg, child: child);
  }

  @override
  bool shouldRebuild(covariant _PinnedHeaderDelegate oldDelegate) => true;
}

class _FavoriteToggle extends StatelessWidget {
  const _FavoriteToggle({required this.isFavorite, required this.onTap});
  final bool isFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(
          isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
          size: 18,
          color: isFavorite ? Colors.amber : p.inkMuted,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.dotColor,
    this.trailing,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? dotColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = selected ? p.primaryInk : p.ink;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.chip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? p.primary : p.surface,
          borderRadius: AppRadii.chip,
          border: Border.all(color: selected ? p.primary : p.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
              ),
              const SizedBox(width: 6),
            ] else if (icon != null) ...[
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
            ],
            Text(label, style: AppType.label.copyWith(color: fg, fontWeight: FontWeight.w600)),
            if (trailing != null) ...[const SizedBox(width: 4), trailing!],
          ],
        ),
      ),
    );
  }
}

/// Consistent bottom-sheet chrome — drag handle + surface + rounded top.
class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(color: p.surface, borderRadius: AppRadii.sheet),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
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
                decoration: BoxDecoration(color: p.border, borderRadius: BorderRadius.circular(999)),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

/// Mock `ScannerOverlay` (design-system.md §6) — no camera plugin in this
/// prototype, so it offers a "simulate scan" demo path plus the manual-entry
/// fallback the doc calls out for damaged stickers (doc §7).
class _ScannerSheet extends StatefulWidget {
  const _ScannerSheet({required this.onResolve});
  final Future<Product?> Function(String code) onResolve;

  @override
  State<_ScannerSheet> createState() => _ScannerSheetState();
}

class _ScannerSheetState extends State<_ScannerSheet> {
  final _codeCtrl = TextEditingController();
  bool _checking = false;
  bool _notFound = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookup(String code) async {
    if (code.trim().isEmpty) return;
    setState(() {
      _checking = true;
      _notFound = false;
    });
    final product = await widget.onResolve(code);
    if (!mounted) return;
    if (product != null) {
      Navigator.of(context).pop(product);
    } else {
      setState(() {
        _checking = false;
        _notFound = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return _SheetShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.qr_code_scanner_rounded, color: p.primary),
              const SizedBox(width: AppSpacing.sm),
              Text('Scan QR sticker', style: AppType.h2.copyWith(color: p.ink)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AspectRatio(
            aspectRatio: 1.7,
            child: Container(
              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(16)),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.qr_code_2_rounded, size: 64, color: Colors.white24),
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
                      icon: Icon(
                        Icons.flash_on_rounded,
                        color: _torchOn ? Colors.amber : Colors.white70,
                      ),
                      tooltip: 'Torch',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _checking ? null : () => _lookup('TSK-000123'),
              icon: const Icon(Icons.qr_code_2_rounded, size: 18),
              label: const Text('Simulate scan (demo)'),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Sticker damaged? Enter the code manually', style: AppType.label.copyWith(color: p.inkMuted)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    hintText: 'e.g. TSK-000123',
                  ),
                  onSubmitted: _lookup,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                onPressed: _checking ? null : () => _lookup(_codeCtrl.text),
                child: _checking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Look up'),
              ),
            ],
          ),
          if (_notFound) ...[
            const SizedBox(height: AppSpacing.sm),
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

/// Mock `VoiceSearchButton` (design-system.md §6) — simulates on-device STT
/// with a progressively-revealed partial transcript (doc §5 row 2).
class _VoiceSearchSheet extends StatefulWidget {
  const _VoiceSearchSheet();

  @override
  State<_VoiceSearchSheet> createState() => _VoiceSearchSheetState();
}

class _VoiceSearchSheetState extends State<_VoiceSearchSheet> {
  static const _demoPhrases = ['red', 'red rac', 'red racer', 'red racer car'];
  int _step = 0;
  bool _listening = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 380), (t) {
      if (!mounted) return;
      setState(() {
        if (_step < _demoPhrases.length - 1) {
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
    final transcript = _demoPhrases[_step];
    return _SheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.mic_rounded, color: p.primary),
              const SizedBox(width: AppSpacing.sm),
              Text('Voice search', style: AppType.h2.copyWith(color: p.ink)),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
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
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Text(
              _listening ? 'Listening…' : 'Heard you',
              style: AppType.label.copyWith(color: p.inkMuted),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Text(
              '"$transcript"',
              style: AppType.h1.copyWith(color: p.ink),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
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

/// Result of [_FiltersSheet] — both fields together so Apply is a single
/// round-trip instead of two separate sheets.
class _FilterSelection {
  const _FilterSelection({this.color, this.shelf});
  final Color? color;
  final String? shelf;
}

/// R3 color + shelf filter sheet, combined — one bottom sheet instead of two
/// separate entry points, so busy staff have one place to set both.
class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet({
    required this.colorOptions,
    required this.shelfOptions,
    required this.initialColor,
    required this.initialShelf,
  });
  final List<ColorTagOption> colorOptions;
  final List<String> shelfOptions;
  final Color? initialColor;
  final String? initialShelf;

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late Color? _color = widget.initialColor;
  late String? _shelf = widget.initialShelf;

  void _clear() => setState(() {
        _color = null;
        _shelf = null;
      });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return _SheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, color: p.primary),
              const SizedBox(width: AppSpacing.sm),
              Text('Filters', style: AppType.h2.copyWith(color: p.ink)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Color', style: AppType.label.copyWith(color: p.inkMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final o in widget.colorOptions)
                _Chip(
                  label: o.label,
                  selected: _color == o.color,
                  dotColor: o.color,
                  onTap: () => setState(() => _color = _color == o.color ? null : o.color),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Shelf', style: AppType.label.copyWith(color: p.inkMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final s in widget.shelfOptions)
                _Chip(
                  label: 'Rack $s',
                  selected: _shelf == s,
                  icon: Icons.inventory_2_rounded,
                  onTap: () => setState(() => _shelf = _shelf == s ? null : s),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _clear,
                  child: const Text('Clear all'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: () => Navigator.of(context)
                      .pop(_FilterSelection(color: _color, shelf: _shelf)),
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Long-press quick info (doc §5 row 8) — lighter glance than the full detail
/// sheet, with an escape hatch to it.
class _QuickInfoSheet extends StatelessWidget {
  const _QuickInfoSheet({required this.product, required this.onViewDetails});
  final Product product;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final prod = product;
    return _SheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProductThumb(product: prod, size: 60),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(prod.name, style: AppType.title.copyWith(color: p.ink)),
                    const SizedBox(height: 2),
                    Text(Fmt.money0(prod.price), style: AppType.money.copyWith(color: p.ink)),
                  ],
                ),
              ),
              if (prod.isFavorite) const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              StockPill(prod.stock, qty: prod.stockQty, dense: true),
              TonePill(
                label: prod.shelf != null ? 'Rack ${prod.shelf}' : 'No shelf yet',
                color: p.info,
                icon: Icons.inventory_2_rounded,
                dense: true,
              ),
              TonePill(
                label: colorLabel(prod.colorTag),
                color: prod.colorTag,
                icon: Icons.circle,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onViewDetails,
              icon: const Icon(Icons.info_outline_rounded, size: 18),
              label: const Text('View full details'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full product detail sheet (doc §4 wireframe / §5 rows 11–13) — price, GST,
/// HSN, stock, shelf, color, QR, favorite toggle, and the hand-off to New
/// Sale (which owns the `ItemConfirmCard` flow per doc row 13).
class _ProductDetailSheet extends StatefulWidget {
  const _ProductDetailSheet({
    required this.product,
    required this.onToggleFavorite,
    required this.onAddToSale,
  });
  final Product product;
  final Future<Product> Function(Product product) onToggleFavorite;
  final ValueChanged<Product> onAddToSale;

  @override
  State<_ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends State<_ProductDetailSheet> {
  late Product _product = widget.product;
  bool _busy = false;

  Future<void> _toggle() async {
    setState(() => _busy = true);
    final updated = await widget.onToggleFavorite(_product);
    if (!mounted) return;
    setState(() {
      _product = updated;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final prod = _product;
    return _SheetShell(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProductThumb(product: prod, size: 84),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(prod.name, style: AppType.h2.copyWith(color: p.ink)),
                      const SizedBox(height: 2),
                      Text(prod.category, style: AppType.caption.copyWith(color: p.inkMuted)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(Fmt.money(prod.price), style: AppType.h1.copyWith(color: p.ink)),
                          if (prod.mrp != null && prod.mrp! > prod.price) ...[
                            const SizedBox(width: 8),
                            Text(
                              Fmt.money0(prod.mrp!),
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
                IconButton(
                  onPressed: _busy ? null : _toggle,
                  icon: Icon(
                    prod.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                    color: prod.isFavorite ? Colors.amber : p.inkMuted,
                  ),
                  tooltip: prod.isFavorite ? 'Remove favorite' : 'Add favorite',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Divider(color: p.border, height: 1),
            const SizedBox(height: AppSpacing.sm),
            LabeledRow('GST rate', Text('${prod.gstRate}%')),
            // HSN isn't modeled on Product yet; toy HSN 9503 stands in (prototype).
            const LabeledRow('HSN code', Text('9503')),
            LabeledRow('Stock', StockPill(prod.stock, qty: prod.stockQty)),
            LabeledRow('Shelf', Text(prod.shelf != null ? 'Rack ${prod.shelf}' : 'Not shelved yet')),
            LabeledRow(
              'Color',
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: prod.colorTag, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(colorLabel(prod.colorTag)),
                ],
              ),
            ),
            LabeledRow('QR code', Text(prod.qrCode ?? 'No QR yet')),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: AppSpacing.primaryAction,
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => widget.onAddToSale(prod),
                icon: const Icon(Icons.point_of_sale_rounded, size: 20),
                label: const Text('Add to sale'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
