import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  final _costPriceCtrl = TextEditingController();
  final _priceCtrl = TextEditingController(); // Sell Price
  final _hsnCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '100');

  String _gstRate = '0%';
  final List<String> _gstRates = ['0%', '5%', '12%', '18%', '28%'];

  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();

  Color _colorTag = kStockColorTags.first;
  bool _saving = false;
  
  List<ProductCategory> _categories = [];
  String? _selectedCategoryId;
  bool _loadingCategories = true;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }
  
  Future<void> _fetchCategories() async {
    final cats = await _repo.getCategories();
    if (mounted) {
      setState(() {
        _categories = cats;
        _loadingCategories = false;
        if (_categories.isNotEmpty) {
          _selectedCategoryId = _categories.first.id;
        }
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _costPriceCtrl.dispose();
    _priceCtrl.dispose();
    _hsnCtrl.dispose();
    _companyCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _imageFile = pickedFile;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open image picker: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  bool get _isValid {
    final price = double.tryParse(_priceCtrl.text.trim());
    final costPrice = double.tryParse(_costPriceCtrl.text.trim());
    final qty = int.tryParse(_qtyCtrl.text.trim());
    return _nameCtrl.text.trim().isNotEmpty &&
           _selectedCategoryId != null &&
           _companyCtrl.text.trim().isNotEmpty &&
           price != null && price >= 0 &&
           costPrice != null && costPrice >= 0 &&
           qty != null && qty > 0;
  }

  Future<void> _save() async {
    if (!_isValid || _saving) return;
    setState(() => _saving = true);
    
    final price = double.parse(_priceCtrl.text.trim());
    final costPrice = double.parse(_costPriceCtrl.text.trim());
    final qty = int.parse(_qtyCtrl.text.trim());
    final gstInt = int.parse(_gstRate.replaceAll('%', ''));
    
    try {
      final product = await _repo.addStock(
        name: _nameCtrl.text.trim(),
        category: _selectedCategoryId ?? '1',
        colorTag: _colorTag,
        price: price,
        costPrice: costPrice,
        hsnCode: _hsnCtrl.text.trim(),
        gstRate: gstInt,
        sourceCompany: _companyCtrl.text.trim(),
        quantity: qty,
        imagePath: _imageFile?.path,
      );
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.name} added to stock!')),
      );
      
      // Clear form
      _nameCtrl.clear();
      _priceCtrl.clear();
      _costPriceCtrl.clear();
      _hsnCtrl.clear();
      _companyCtrl.clear();
      _qtyCtrl.text = '100';
      setState(() {
        _colorTag = kStockColorTags.first;
        _imageFile = null;
        _gstRate = '0%';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding stock: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
                _loadingCategories 
                  ? const CircularProgressIndicator() 
                  : DropdownButtonFormField<String>(
                      value: _selectedCategoryId,
                      decoration: const InputDecoration(labelText: 'Category *', hintText: 'Select Category'),
                      items: _categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedCategoryId = val;
                        });
                      },
                    ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _costPriceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Cost Price *', prefixText: '₹ ', hintText: 'Buying amount'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: TextField(
                        controller: _priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Sell Price *', prefixText: '₹ ', hintText: 'Selling amount'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _hsnCtrl,
                  decoration: const InputDecoration(labelText: 'HSN Code', hintText: 'e.g. 9503'),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  value: _gstRate,
                  decoration: const InputDecoration(labelText: 'GST Rate *'),
                  items: _gstRates.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _gstRate = val);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _pickImage,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Product Image', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    child: Row(
                      children: [
                        const Icon(Icons.image_outlined, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _imageFile != null ? _imageFile!.name : 'Choose File (No file chosen)',
                            style: TextStyle(color: _imageFile != null ? p.ink : p.ink.withOpacity(0.5)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
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
