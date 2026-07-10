import 'package:flutter/material.dart';
import '../../core/core.dart';
import 'stock_addition_data.dart';

const List<Color> kStockColorTags = [
  Color(0xFFDC2626), // red
  Color(0xFF2563EB), // blue
  Color(0xFF16A34A), // green
  Color(0xFFD97706), // orange
  Color(0xFF7C3AED), // purple
  Color(0xFF0891B2), // teal
  Color(0xFFDB2777), // pink
  Color(0xFF78350F), // brown
];

class StockAdditionScreen extends StatefulWidget {
  const StockAdditionScreen({super.key});

  @override
  State<StockAdditionScreen> createState() => _StockAdditionScreenState();
}

class _StockAdditionScreenState extends State<StockAdditionScreen> {
  final _repo = const StockAdditionRepository();
  
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '100'); // Default to 100

  Color _colorTag = kStockColorTags.first;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _companyCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  bool get _isValid {
    final price = double.tryParse(_priceCtrl.text.trim());
    final qty = int.tryParse(_qtyCtrl.text.trim());
    return _nameCtrl.text.trim().isNotEmpty &&
           _companyCtrl.text.trim().isNotEmpty &&
           price != null && price >= 0 &&
           qty != null && qty > 0;
  }

  Future<void> _save() async {
    if (!_isValid || _saving) return;
    setState(() => _saving = true);
    
    final price = double.parse(_priceCtrl.text.trim());
    final qty = int.parse(_qtyCtrl.text.trim());
    
    final product = await _repo.addStock(
      name: _nameCtrl.text.trim(),
      colorTag: _colorTag,
      price: price,
      sourceCompany: _companyCtrl.text.trim(),
      quantity: qty,
    );
    
    if (!mounted) return;
    setState(() => _saving = false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${product.name} added to stock!')),
    );
    
    // Clear form
    _nameCtrl.clear();
    _priceCtrl.clear();
    _companyCtrl.clear();
    _qtyCtrl.text = '100';
    setState(() => _colorTag = kStockColorTags.first);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    
    return AppScaffold(
      title: 'Stock Addition',
      subtitle: 'Add new stock to warehouse',
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          SectionHeader(title: 'Product Details', padding: const EdgeInsets.only(bottom: AppSpacing.sm)),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Product Name *', hintText: 'e.g. Red Toy Car'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Price *', prefixText: '₹ '),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(title: 'Stock Source', padding: const EdgeInsets.only(bottom: AppSpacing.sm)),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _companyCtrl,
                  decoration: const InputDecoration(labelText: 'Source Company *', hintText: 'e.g. Sunrise Toys'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantity *'),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(title: 'Product Color', padding: const EdgeInsets.only(bottom: AppSpacing.sm)),
          AppCard(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final c in kStockColorTags)
                  GestureDetector(
                    onTap: () => setState(() => _colorTag = c),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _colorTag == c ? p.ink : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: _colorTag == c
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                          : null,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 100), // padding for bottom bar
        ],
      ),
      bottomBar: AppBottomBar(
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isValid && !_saving ? _save : null,
            icon: _saving 
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_circle_rounded),
            label: Text(_saving ? 'Adding Stock...' : 'Add Stock'),
          ),
        ),
      ),
    );
  }
}
