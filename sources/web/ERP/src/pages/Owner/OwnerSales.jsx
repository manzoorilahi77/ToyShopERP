import React, { useState } from 'react';
import { ReceiptText, X, Printer } from 'lucide-react';
import DataTable from '../../components/ui/DataTable';
import { getSalesHistory } from '../../services/saleService';
import toast from 'react-hot-toast';

/* ─────────────────────────── Receipt Modal ─────────────────────────── */
function ReceiptModal({ sale, onClose }) {
  if (!sale) return null;

  const handlePrint = () => {
    const printContent = document.getElementById('receipt-content').innerHTML;
    const printWindow = window.open('', '_blank', 'width=400,height=600');
    printWindow.document.write(`
      <html>
        <head>
          <title>Receipt – ${sale.invoiceNumber}</title>
          <style>
            body { font-family: 'Courier New', monospace; font-size: 13px; margin: 20px; }
            h2 { text-align: center; margin-bottom: 4px; }
            p  { margin: 2px 0; }
            .divider { border-top: 1px dashed #000; margin: 8px 0; }
            table { width: 100%; border-collapse: collapse; }
            th, td { text-align: left; padding: 4px 2px; font-size: 12px; }
            th { border-bottom: 1px solid #000; }
            .right { text-align: right; }
            .total { font-weight: bold; font-size: 14px; }
          </style>
        </head>
        <body>${printContent}</body>
      </html>
    `);
    printWindow.document.close();
    printWindow.print();
  };

  const saleDate = new Date(sale.createdAt);

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/40 backdrop-blur-sm">
      <div className="card border-0 shadow-2xl w-full max-w-md animate-fade-in">
        {/* Modal Header */}
        <div className="flex items-center justify-between p-5 border-b border-slate-100">
          <div className="flex items-center gap-2">
            <ReceiptText className="w-5 h-5 text-primary" />
            <h2 className="text-lg font-bold text-slate-800">Sale Receipt</h2>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={handlePrint}
              className="btn-secondary inline-flex items-center text-sm px-3 py-1.5"
            >
              <Printer className="w-4 h-4 mr-1.5" /> Print
            </button>
            <button
              onClick={onClose}
              className="p-1.5 rounded-lg hover:bg-slate-100 text-slate-500 transition-colors"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        {/* Receipt Content */}
        <div id="receipt-content" className="p-6 font-mono text-sm">
          <h2 className="text-center text-base font-bold text-slate-800 mb-1">🧸 ToyShop ERP</h2>
          <p className="text-center text-slate-500 text-xs mb-4">Official Sales Receipt</p>

          <div className="border-t border-dashed border-slate-300 my-3" />

          <div className="space-y-1 text-slate-600 text-xs mb-3">
            <div className="flex justify-between">
              <span className="font-semibold">Invoice No.</span>
              <span>{sale.invoiceNumber}</span>
            </div>
            <div className="flex justify-between">
              <span className="font-semibold">Date</span>
              <span>{saleDate.toLocaleDateString()}</span>
            </div>
            <div className="flex justify-between">
              <span className="font-semibold">Time</span>
              <span>{saleDate.toLocaleTimeString()}</span>
            </div>
            {sale.customerMobile && (
              <div className="flex justify-between">
                <span className="font-semibold">Customer</span>
                <span>{sale.customerMobile}</span>
              </div>
            )}
            <div className="flex justify-between">
              <span className="font-semibold">Payment</span>
              <span className="capitalize">{sale.paymentMethod}</span>
            </div>
            {sale.user && (
              <div className="flex justify-between">
                <span className="font-semibold">Staff</span>
                <span>{sale.user.name}</span>
              </div>
            )}
          </div>

          <div className="border-t border-dashed border-slate-300 my-3" />

          {/* Items Table */}
          <table className="w-full text-xs">
            <thead>
              <tr className="border-b border-slate-200">
                <th className="text-left py-1 text-slate-600">Item</th>
                <th className="text-center py-1 text-slate-600">Qty</th>
                <th className="text-right py-1 text-slate-600">Price</th>
                <th className="text-right py-1 text-slate-600">Sub Total</th>
              </tr>
            </thead>
            <tbody>
              {sale.items?.map((item, idx) => (
                <tr key={idx} className="border-b border-slate-100">
                  <td className="py-1.5 text-slate-800 font-medium">
                    {item.product?.name || `Product #${item.productId}`}
                  </td>
                  <td className="py-1.5 text-center text-slate-600">{item.quantity}</td>
                  <td className="py-1.5 text-right text-slate-600">₹{parseFloat(item.unitPrice).toLocaleString()}</td>
                  <td className="py-1.5 text-right font-semibold text-slate-800">₹{parseFloat(item.subTotal).toLocaleString()}</td>
                </tr>
              ))}
            </tbody>
          </table>

          <div className="border-t border-dashed border-slate-300 my-3" />

          <div className="flex justify-between items-center text-slate-800 font-bold text-sm">
            <span>TOTAL</span>
            <span>₹{parseFloat(sale.totalAmount).toLocaleString()}</span>
          </div>

          <div className="border-t border-dashed border-slate-300 my-3" />

          <p className="text-center text-xs text-slate-400 mt-2">Thank you for shopping! 🎉</p>
        </div>
      </div>
    </div>
  );
}

export default function OwnerSales() {
  const [salesItems, setSalesItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedSale, setSelectedSale] = useState(null);

  React.useEffect(() => {
    const loadData = async () => {
      try {
        const res = await getSalesHistory();
        const sales = res.data || [];
        
        // Flatten sales into individual products sold
        const flattenedItems = [];
        sales.forEach(sale => {
          if (sale.items && sale.items.length > 0) {
            sale.items.forEach(item => {
              flattenedItems.push({
                id: item.id,
                productId: item.productId,
                productName: item.product?.name || 'Unknown Product',
                originalAmount: item.product?.costPrice || item.product?.price || 0, // Fallback to price if costPrice is 0/null
                updatedAmount: parseFloat(item.unitPrice),
                salesmanName: sale.user?.name || 'Unknown Staff',
                saleDate: new Date(sale.createdAt).toLocaleString(),
                saleObj: sale, // Keep reference to original sale for receipt
              });
            });
          }
        });
        
        setSalesItems(flattenedItems);
      } catch (error) {
        toast.error('Failed to load sales history');
      } finally {
        setLoading(false);
      }
    };
    loadData();
  }, []);

  const columns = React.useMemo(
    () => [
      {
        accessorKey: 'productId',
        header: 'Product ID',
        cell: info => <span className="font-mono text-sm">TY-{(info.getValue() || '').toString().padStart(3, '0')}</span>,
      },
      {
        accessorKey: 'productName',
        header: 'Product Name',
        cell: info => <span className="font-medium text-slate-900">{info.getValue()}</span>,
      },
      {
        accessorKey: 'originalAmount',
        header: 'Original Amount (Cost)',
        cell: info => `₹${Number(info.getValue() || 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`,
      },
      {
        accessorKey: 'updatedAmount',
        header: 'Sold Amount',
        cell: info => `₹${Number(info.getValue() || 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`,
      },
      {
        accessorKey: 'salesmanName',
        header: 'Salesman Name',
        cell: info => <span className="text-slate-600">{info.getValue()}</span>,
      },
      {
        accessorKey: 'saleDate',
        header: 'Date & Time',
        cell: info => <span className="text-slate-500 text-sm">{info.getValue()}</span>,
      },
      {
        id: 'actions',
        header: 'Actions',
        cell: (info) => (
          <button
            onClick={() => setSelectedSale(info.row.original.saleObj)}
            className="inline-flex items-center text-primary hover:text-primary-dark font-medium text-sm gap-1.5 hover:bg-primary-50 px-3 py-1.5 rounded-lg transition-colors"
          >
            <ReceiptText className="w-4 h-4" />
            View Receipt
          </button>
        )
      }
    ],
    []
  );

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-end">
        <div>
          <h1 className="text-2xl font-bold text-slate-800 font-heading">Products Sold</h1>
          <p className="text-slate-500 mt-1 text-sm">View all individual products sold across the shop.</p>
        </div>
      </div>

      {loading ? (
        <div className="flex justify-center py-12">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
        </div>
      ) : (
        <DataTable 
          data={salesItems} 
          columns={columns} 
          filters={[]}
        />
      )}

      {selectedSale && (
        <ReceiptModal sale={selectedSale} onClose={() => setSelectedSale(null)} />
      )}
    </div>
  );
}
