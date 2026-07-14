import React, { useState } from 'react';
import {
  Calendar, Filter, Download, ReceiptText, Search,
  Clock, CheckCircle2, AlertCircle, X, Printer, Package
} from 'lucide-react';
import KpiCard from '../../components/ui/KpiCard';
import { getMySales } from '../../services/saleService';
import { getStaffDashboard } from '../../services/dashboardService';
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
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md animate-fade-in">
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

/* ────────────────────────── Main Component ──────────────────────────── */
export default function SalesHistory() {
  const [filter, setFilter] = useState('today'); // today, week, month
  const [searchQuery, setSearchQuery] = useState('');
  const [salesHistory, setSalesHistory] = useState([]);
  const [staffStats, setStaffStats] = useState({ salesToday: 0, revenueToday: 0 });
  const [loading, setLoading] = useState(true);
  const [selectedSale, setSelectedSale] = useState(null);

  React.useEffect(() => {
    const loadData = async () => {
      try {
        const [salesRes, statsRes] = await Promise.all([
          getMySales(),
          getStaffDashboard()
        ]);
        setSalesHistory(salesRes.data || []);
        setStaffStats(statsRes.data || { salesToday: 0, revenueToday: 0 });
      } catch (error) {
        toast.error('Failed to load sales history');
      } finally {
        setLoading(false);
      }
    };
    loadData();
  }, []);

  /* ── Filter by time period ── */
  const getFilteredByPeriod = (sales) => {
    const now = new Date();
    return sales.filter(sale => {
      const saleDate = new Date(sale.createdAt);
      if (filter === 'today') {
        return saleDate.toDateString() === now.toDateString();
      } else if (filter === 'week') {
        const weekAgo = new Date(now);
        weekAgo.setDate(weekAgo.getDate() - 7);
        return saleDate >= weekAgo;
      } else if (filter === 'month') {
        return saleDate.getMonth() === now.getMonth() && saleDate.getFullYear() === now.getFullYear();
      }
      return true;
    });
  };

  const filteredHistory = getFilteredByPeriod(salesHistory).filter(sale =>
    sale.invoiceNumber?.toLowerCase().includes(searchQuery.toLowerCase()) ||
    sale.items?.some(item => item.product?.name?.toLowerCase().includes(searchQuery.toLowerCase()))
  );

  /* ── Helper: get comma-separated product names ── */
  const getProductNames = (sale) => {
    const names = sale.items?.map(i => i.product?.name).filter(Boolean) || [];
    if (names.length === 0) return '—';
    if (names.length <= 2) return names.join(', ');
    return `${names.slice(0, 2).join(', ')} +${names.length - 2} more`;
  };

  return (
    <div className="p-6 md:p-8 max-w-7xl mx-auto pb-24">
      {/* Header */}
      <div className="mb-8 flex flex-col md:flex-row md:items-end justify-between">
        <div>
          <h1 className="text-3xl font-bold text-slate-800 font-heading">My Sales History</h1>
          <p className="text-slate-500 mt-2">Your personal transaction history.</p>
        </div>
        <div className="mt-4 md:mt-0 flex gap-2">
          <button className="btn-secondary inline-flex items-center">
            <Filter className="w-4 h-4 mr-2" />
            Filter
          </button>
          <button className="btn-secondary inline-flex items-center">
            <Download className="w-4 h-4 mr-2" />
            Export
          </button>
        </div>
      </div>

      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <KpiCard
          title="Sales Today"
          value={staffStats.salesToday}
          icon={ReceiptText}
          colorClass="bg-blue-100 text-blue-600"
        />
        <KpiCard
          title="Revenue Today"
          value={`₹${staffStats.revenueToday.toLocaleString()}`}
          icon={ReceiptText}
          colorClass="bg-green-100 text-green-600"
        />
        <div className="card p-6 flex flex-col justify-center">
          <h3 className="text-sm font-medium text-slate-500 mb-2">Sync Status</h3>
          <div className="flex items-center justify-between">
            <div className="flex items-center text-support-green">
              <CheckCircle2 className="w-5 h-5 mr-2" />
              <span className="font-semibold">All Synced</span>
            </div>
            <span className="text-xs text-slate-400">Just now</span>
          </div>
        </div>
      </div>

      {/* Main Content Area */}
      <div className="card">
        {/* Table Controls */}
        <div className="p-4 border-b border-slate-100 flex flex-col sm:flex-row justify-between items-center gap-4">
          <div className="flex items-center bg-slate-100 p-1 rounded-xl w-full sm:w-auto">
            {['today', 'week', 'month'].map(f => (
              <button
                key={f}
                onClick={() => setFilter(f)}
                className={`px-4 py-2 rounded-lg text-sm font-semibold capitalize transition-colors flex-1 sm:flex-none ${
                  filter === f ? 'bg-white text-primary shadow-sm' : 'text-slate-500 hover:text-slate-700'
                }`}
              >
                {f}
              </button>
            ))}
          </div>

          <div className="relative w-full sm:w-64">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
            <input
              type="text"
              placeholder="Search Invoice ID or Product..."
              className="w-full pl-9 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-lg focus:ring-2 focus:ring-primary/50 focus:border-primary/50 text-sm"
              value={searchQuery}
              onChange={e => setSearchQuery(e.target.value)}
            />
          </div>
        </div>

        {/* Transactions Table */}
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse min-w-[750px]">
            <thead>
              <tr className="bg-slate-50 border-b border-slate-100">
                <th className="p-4 text-xs font-semibold text-slate-500 uppercase tracking-wider">Invoice ID</th>
                <th className="p-4 text-xs font-semibold text-slate-500 uppercase tracking-wider">Time</th>
                <th className="p-4 text-xs font-semibold text-slate-500 uppercase tracking-wider">Products</th>
                <th className="p-4 text-xs font-semibold text-slate-500 uppercase tracking-wider">Items</th>
                <th className="p-4 text-xs font-semibold text-slate-500 uppercase tracking-wider text-right">Total</th>
                <th className="p-4 text-xs font-semibold text-slate-500 uppercase tracking-wider text-center">Status</th>
                <th className="p-4 text-xs font-semibold text-slate-500 uppercase tracking-wider text-right">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {loading ? (
                <tr>
                  <td colSpan="7" className="p-8 text-center text-slate-500">
                    <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600 mx-auto"></div>
                  </td>
                </tr>
              ) : filteredHistory.map((sale) => (
                <tr key={sale.id} className="hover:bg-slate-50/50 transition-colors">
                  <td className="p-4">
                    <span className="font-semibold text-slate-800">{sale.invoiceNumber}</span>
                  </td>
                  <td className="p-4">
                    <div className="flex items-center text-slate-500">
                      <Clock className="w-4 h-4 mr-2" />
                      {new Date(sale.createdAt).toLocaleTimeString()}
                    </div>
                  </td>
                  <td className="p-4">
                    <div className="flex items-center gap-1.5 text-slate-700">
                      <Package className="w-4 h-4 text-slate-400 flex-shrink-0" />
                      <span className="text-sm">{getProductNames(sale)}</span>
                    </div>
                  </td>
                  <td className="p-4 text-slate-600">{sale.items?.length || 0} items</td>
                  <td className="p-4 font-bold text-slate-800 text-right">
                    ₹{parseFloat(sale.totalAmount).toLocaleString()}
                  </td>
                  <td className="p-4 text-center">
                    {sale.status === 'completed' ? (
                      <span className="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-green-100 text-green-700">
                        <CheckCircle2 className="w-3 h-3 mr-1" /> Synced
                      </span>
                    ) : (
                      <span className="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-red-100 text-red-700">
                        <AlertCircle className="w-3 h-3 mr-1" /> Failed
                      </span>
                    )}
                  </td>
                  <td className="p-4 text-right">
                    <button
                      onClick={() => setSelectedSale(sale)}
                      className="inline-flex items-center text-primary hover:text-primary-dark font-medium text-sm gap-1.5 hover:underline"
                    >
                      <ReceiptText className="w-4 h-4" />
                      View Receipt
                    </button>
                  </td>
                </tr>
              ))}
              {!loading && filteredHistory.length === 0 && (
                <tr>
                  <td colSpan="7" className="p-8 text-center text-slate-500">
                    No transactions found for the selected criteria.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Receipt Modal */}
      {selectedSale && (
        <ReceiptModal sale={selectedSale} onClose={() => setSelectedSale(null)} />
      )}
    </div>
  );
}
