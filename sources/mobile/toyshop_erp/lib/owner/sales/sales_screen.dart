import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/core.dart';
import 'sales_data.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  bool _isLoading = true;
  String? _error;
  List<Sale> _sales = [];

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final service = SalesService();
      final sales = await service.fetchSales();
      setState(() {
        _sales = sales;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    
    return AppScaffold(
      title: 'Sales History',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: p.danger),
                      const SizedBox(height: 16),
                      Text('Failed to load sales', style: AppType.title),
                      const SizedBox(height: 8),
                      Text(_error!, style: AppType.body.copyWith(color: p.inkMuted)),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loadSales,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _sales.isEmpty
                  ? Center(
                      child: Text('No sales found',
                          style: AppType.title.copyWith(color: p.inkMuted)),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadSales,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _sales.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final sale = _sales[index];
                          return _SaleCard(sale: sale);
                        },
                      ),
                    ),
    );
  }
}

class _SaleCard extends StatelessWidget {
  final Sale sale;

  const _SaleCard({required this.sale});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final currencyFormatter = NumberFormat.currency(symbol: '\$');
    final dateFormatter = DateFormat('MMM d, y, h:mm a');

    return AppCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                sale.invoiceNumber,
                style: AppType.title.copyWith(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              currencyFormatter.format(sale.totalAmount),
              style: AppType.title.copyWith(color: p.success, fontSize: 16),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(dateFormatter.format(sale.createdAt),
                  style: AppType.caption.copyWith(color: p.inkMuted)),
              TonePill.tone(
                Tone.success,
                sale.status.toUpperCase(),
                dense: true,
              ),
            ],
          ),
        ),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Staff', style: AppType.body),
                    Text(sale.staffName ?? 'Unknown',
                        style: AppType.body.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Payment', style: AppType.body),
                    Text(sale.paymentMethod.toUpperCase(),
                        style: AppType.body.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Items', style: AppType.body.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...sale.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${item.quantity}x ${item.productName}',
                              style: AppType.body,
                            ),
                          ),
                          Text(
                            currencyFormatter.format(item.subTotal),
                            style: AppType.body.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    )),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Taxable Amount', style: AppType.caption),
                    Text(currencyFormatter.format(sale.taxableAmount),
                        style: AppType.caption),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('CGST / SGST', style: AppType.caption),
                    Text(
                        '${currencyFormatter.format(sale.cgst)} / ${currencyFormatter.format(sale.sgst)}',
                        style: AppType.caption),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
