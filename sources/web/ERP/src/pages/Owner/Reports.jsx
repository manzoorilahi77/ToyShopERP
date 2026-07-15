import { useState, useEffect } from 'react';
import { 
  LineChart, TrendingUp, TrendingDown, 
  Package, Users, AlertTriangle, FileText, 
  IndianRupee, ChevronDown, Award, Loader2, Download
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import api from '../../services/api';
import * as XLSX from 'xlsx';

const PERIODS = ['Today', 'Yesterday', 'Last 7 Days', 'This Month'];

export default function Reports() {
  const [period, setPeriod] = useState('Today');
  const [branchFilter, setBranchFilter] = useState('All Branches');
  
  const [sales, setSales] = useState([]);
  const [products, setProducts] = useState([]);
  const [branches, setBranches] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchData = async () => {
      try {
        setLoading(true);
        const [salesRes, productsRes, branchesRes] = await Promise.all([
          api.get('/sales').catch(() => ({ data: { data: [] } })),
          api.get('/products').catch(() => ({ data: { data: [] } })),
          api.get('/branches').catch(() => ({ data: { data: [] } }))
        ]);
        
        setSales(salesRes.data?.data || []);
        setProducts(productsRes.data?.data || []);
        setBranches(branchesRes.data?.data || []);
      } catch (error) {
        console.error('Failed to fetch report data:', error);
      } finally {
        setLoading(false);
      }
    };
    fetchData();
  }, []);

  const getPeriodDate = (periodStr) => {
    const date = new Date();
    date.setHours(0, 0, 0, 0);
    switch (periodStr) {
      case 'Today': {
        const start = new Date(date);
        const end = new Date(start);
        end.setHours(23, 59, 59, 999);
        return { start, end };
      }
      case 'Yesterday': {
        const start = new Date(date);
        start.setDate(start.getDate() - 1);
        const end = new Date(start);
        end.setHours(23, 59, 59, 999);
        return { start, end };
      }
      case 'Last 7 Days': {
        const start = new Date(date);
        start.setDate(start.getDate() - 7);
        const end = new Date(date);
        end.setHours(23, 59, 59, 999);
        return { start, end };
      }
      case 'This Month': {
        const start = new Date(date.getFullYear(), date.getMonth(), 1);
        const end = new Date(date.getFullYear(), date.getMonth() + 1, 0, 23, 59, 59, 999);
        return { start, end };
      }
      default: {
        const start = new Date(date);
        const end = new Date(date);
        end.setHours(23, 59, 59, 999);
        return { start, end };
      }
    }
  };

  const getPreviousPeriodDate = (periodStr) => {
    const date = new Date();
    date.setHours(0, 0, 0, 0);
    switch (periodStr) {
      case 'Today': {
        const start = new Date(date);
        start.setDate(start.getDate() - 1);
        const end = new Date(start);
        end.setHours(23, 59, 59, 999);
        return { start, end };
      }
      case 'Yesterday': {
        const start = new Date(date);
        start.setDate(start.getDate() - 2);
        const end = new Date(start);
        end.setHours(23, 59, 59, 999);
        return { start, end };
      }
      case 'Last 7 Days': {
        const start = new Date(date);
        start.setDate(start.getDate() - 14);
        const end = new Date(start);
        end.setDate(end.getDate() + 7);
        end.setHours(23, 59, 59, 999);
        return { start, end };
      }
      case 'This Month': {
        const start = new Date(date.getFullYear(), date.getMonth() - 1, 1);
        const end = new Date(date.getFullYear(), date.getMonth(), 0);
        end.setHours(23, 59, 59, 999);
        return { start, end };
      }
      default:
        return { start: date, end: new Date() };
    }
  };

  const getFilteredSales = (salesList, start, end, selectedBranch) => {
    return salesList.filter(s => {
      const sDate = new Date(s.createdAt);
      const inDateRange = sDate >= start && sDate <= end;
      const branchObj = branches.find(b => b.name === selectedBranch);
      const inBranch = selectedBranch === 'All Branches' || (branchObj && s.branchId === branchObj.id);
      return inDateRange && inBranch;
    });
  };

  const currentPeriodDates = getPeriodDate(period);
  const prevPeriodDates = getPreviousPeriodDate(period);

  const currentSales = getFilteredSales(sales, currentPeriodDates.start, currentPeriodDates.end, branchFilter);
  const prevSales = getFilteredSales(sales, prevPeriodDates.start, prevPeriodDates.end, branchFilter);

  const currentRevenue = currentSales.reduce((sum, s) => sum + Number(s.totalAmount || 0), 0);
  const prevRevenue = prevSales.reduce((sum, s) => sum + Number(s.totalAmount || 0), 0);

  let trend = 0;
  if (prevRevenue > 0) {
    trend = ((currentRevenue - prevRevenue) / prevRevenue) * 100;
  } else if (currentRevenue > 0) {
    trend = 100;
  }

  const currentSummary = {
    revenue: currentRevenue,
    orders: currentSales.length,
    avgValue: currentSales.length > 0 ? currentRevenue / currentSales.length : 0,
    tax: currentRevenue * 0.18,
    trend: Number(trend.toFixed(1)),
    totalInventoryCost: products.reduce((sum, p) => sum + ((p.stock || 0) * (p.costPrice || 0)), 0)
  };

  const productSalesMap = {};
  currentSales.forEach(sale => {
    sale.items?.forEach(item => {
      if (!productSalesMap[item.productId]) {
        productSalesMap[item.productId] = {
          id: item.productId,
          name: item.product?.name || 'Unknown',
          qty: 0,
          revenue: 0
        };
      }
      productSalesMap[item.productId].qty += Number(item.quantity);
      productSalesMap[item.productId].revenue += Number(item.subTotal);
    });
  });
  
  const topProducts = Object.values(productSalesMap)
    .sort((a, b) => b.revenue - a.revenue)
    .slice(0, 5);

  const staffSalesMap = {};
  currentSales.forEach(sale => {
    const u = sale.user;
    if (u) {
      if (!staffSalesMap[u.id]) {
        const colors = ['bg-blue-500', 'bg-green-500', 'bg-purple-500', 'bg-amber-500', 'bg-rose-500'];
        staffSalesMap[u.id] = {
          id: u.id,
          name: u.name,
          initial: u.name ? u.name.charAt(0).toUpperCase() : 'U',
          color: colors[u.id % colors.length],
          sales: 0,
          points: 0
        };
      }
      staffSalesMap[u.id].sales += Number(sale.totalAmount);
      staffSalesMap[u.id].points += Math.floor(Number(sale.totalAmount) / 100);
    }
  });

  const topStaff = Object.values(staffSalesMap)
    .sort((a, b) => b.sales - a.sales)
    .slice(0, 5);

  const lowStock = products
    .filter(p => p.stock < (p.minStock || 10))
    .slice(0, 5)
    .map(p => ({
      id: p.id,
      name: p.name,
      stock: p.stock,
      min: p.minStock || 10
    }));

  const ninetyDaysAgo = new Date();
  ninetyDaysAgo.setDate(ninetyDaysAgo.getDate() - 90);
  
  const agingStock = products
    .filter(p => new Date(p.createdAt) < ninetyDaysAgo && p.stock > 0)
    .map(p => ({
      id: p.id,
      name: p.name,
      days: Math.floor((new Date() - new Date(p.createdAt)) / (1000 * 60 * 60 * 24)),
      qty: p.stock
    }))
    .sort((a, b) => b.days - a.days)
    .slice(0, 5);

  const getGstSnapshot = () => {
    const date = new Date();
    const currentMonthStr = date.toLocaleString('default', { month: 'short', year: 'numeric' });
    
    const lastMonthDate = new Date();
    lastMonthDate.setMonth(lastMonthDate.getMonth() - 1);
    const lastMonthStr = lastMonthDate.toLocaleString('default', { month: 'short', year: 'numeric' });

    const startOfCurrentMonth = new Date(date.getFullYear(), date.getMonth(), 1);
    const currentMonthSales = sales.filter(s => new Date(s.createdAt) >= startOfCurrentMonth);
    const currentMonthCollected = currentMonthSales.reduce((sum, s) => sum + (Number(s.totalAmount) * 0.18), 0);

    const startOfLastMonth = new Date(lastMonthDate.getFullYear(), lastMonthDate.getMonth(), 1);
    const endOfLastMonth = new Date(date.getFullYear(), date.getMonth(), 0, 23, 59, 59);
    const lastMonthSales = sales.filter(s => {
      const d = new Date(s.createdAt);
      return d >= startOfLastMonth && d <= endOfLastMonth;
    });
    const lastMonthCollected = lastMonthSales.reduce((sum, s) => sum + (Number(s.totalAmount) * 0.18), 0);

    return [
      { month: currentMonthStr, collected: currentMonthCollected, paid: 0, balance: currentMonthCollected },
      { month: lastMonthStr, collected: lastMonthCollected, paid: lastMonthCollected * 0.8, balance: lastMonthCollected * 0.2 }
    ];
  };

  const gstSnapshotData = getGstSnapshot();

  const BRANCHES = ['All Branches', ...branches.map(b => b.name)];

  if (loading) {
    return (
      <div className="max-w-7xl mx-auto pb-24 flex items-center justify-center min-h-[60vh]">
        <div className="flex flex-col items-center text-slate-500">
          <Loader2 className="w-10 h-10 animate-spin mb-4 text-primary-500" />
          <p className="font-medium">Gathering insights...</p>
        </div>
      </div>
    );
  }

  const generateExcelReport = () => {
    // 1. Stock List Sheet
    const stockData = products.map(p => ({
      'Product Name': p.name,
      'Current Stock': p.stock,
      'Min Stock': p.minStock || 10,
      'Status': p.stock <= (p.minStock || 10) ? 'Low Stock' : 'Healthy',
      'Cost Price': p.costPrice || 0,
      'Sell Price': p.price,
      'Added On': new Date(p.createdAt).toLocaleDateString()
    }));

    // 2. Sales Sheet
    const salesData = currentSales.map(s => ({
      'Order ID': s.id,
      'Date': new Date(s.createdAt).toLocaleString(),
      'Staff': s.user?.name || 'Unknown',
      'Branch': branches.find(b => b.id === s.branchId)?.name || 'Unknown',
      'Items': s.items?.length || 0,
      'Total Amount': Number(s.totalAmount)
    }));

    // 3. Top Salesman
    const staffData = Object.values(staffSalesMap).map(st => ({
      'Staff Name': st.name,
      'Total Sales Amount': st.sales,
      'Points Earned': st.points
    })).sort((a, b) => b['Total Sales Amount'] - a['Total Sales Amount']);

    // 4. Top Products
    const productsSalesData = Object.values(productSalesMap).map(ps => ({
      'Product Name': ps.name,
      'Quantity Sold': ps.qty,
      'Revenue Generated': ps.revenue
    })).sort((a, b) => b['Revenue Generated'] - a['Revenue Generated']);

    // 5. Financial Summary
    const financialData = [
      { Metric: 'Total Revenue', Value: currentSummary.revenue },
      { Metric: 'Total Orders', Value: currentSummary.orders },
      { Metric: 'Average Order Value', Value: currentSummary.avgValue },
      { Metric: 'Estimated Tax (GST 18%)', Value: currentSummary.tax },
      { Metric: 'Total Inventory Value (Cost)', Value: currentSummary.totalInventoryCost },
      { Metric: 'Growth Trend (%)', Value: currentSummary.trend }
    ];

    const wb = XLSX.utils.book_new();

    XLSX.utils.book_append_sheet(wb, XLSX.utils.json_to_sheet(stockData), 'Stock List');
    XLSX.utils.book_append_sheet(wb, XLSX.utils.json_to_sheet(salesData), 'Sales');
    XLSX.utils.book_append_sheet(wb, XLSX.utils.json_to_sheet(staffData), 'Staff Performance');
    XLSX.utils.book_append_sheet(wb, XLSX.utils.json_to_sheet(productsSalesData), 'Product Performance');
    XLSX.utils.book_append_sheet(wb, XLSX.utils.json_to_sheet(financialData), 'Financial Summary');
    XLSX.writeFile(wb, `Business_Report_${period.replace(/ /g, '_')}_${branchFilter.replace(/ /g, '_')}.xlsx`);
  };

  return (
    <div className="max-w-7xl mx-auto pb-24">
      {/* Header & Filters */}
      <div className="flex flex-col xl:flex-row xl:items-center justify-between gap-4 mb-8">
        <div>
          <h1 className="text-3xl font-bold text-slate-800 font-heading">Reports & Analytics</h1>
          <p className="text-slate-500 mt-2">Comprehensive view of your business performance {period.toLowerCase()} at {branchFilter}.</p>
        </div>
        
        <div className="flex flex-col sm:flex-row gap-2">
          <div className="relative">
            <select 
              value={branchFilter} 
              onChange={(e) => setBranchFilter(e.target.value)}
              className="appearance-none bg-white border border-slate-200 rounded-lg pl-4 pr-10 py-2.5 text-sm font-semibold text-slate-700 focus:outline-none focus:ring-2 focus:ring-primary-500/50 shadow-sm cursor-pointer"
            >
              {BRANCHES.map(b => <option key={b}>{b}</option>)}
            </select>
            <ChevronDown className="w-4 h-4 text-slate-400 absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none" />
          </div>

          <div className="bg-slate-200/50 p-1 rounded-lg flex inline-flex overflow-x-auto hide-scrollbar">
            {PERIODS.map(p => (
              <button
                key={p}
                onClick={() => setPeriod(p)}
                className={`px-4 py-1.5 rounded-md text-sm font-semibold transition-all whitespace-nowrap ${
                  period === p 
                    ? 'bg-white text-slate-800 shadow-sm' 
                    : 'text-slate-500 hover:text-slate-700'
                }`}
              >
                {p}
              </button>
            ))}
          </div>

          <button
            onClick={generateExcelReport}
            className="flex items-center justify-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors text-sm font-semibold whitespace-nowrap shadow-sm"
          >
            <Download className="w-4 h-4" />
            Generate Report
          </button>
        </div>
      </div>

      {/* KPI Cards */}
      <AnimatePresence mode="wait">
        <motion.div 
          key={`${period}-${branchFilter}`}
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: -10 }}
          transition={{ duration: 0.2 }}
          className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-6 mb-8"
        >
          <div className="card p-6 flex flex-col justify-between">
            <div className="flex justify-between items-start mb-4">
              <div className="p-3 bg-blue-50 rounded-xl text-blue-600">
                <IndianRupee className="w-6 h-6" />
              </div>
              <span className={`flex items-center text-sm font-bold px-2 py-1 rounded-md ${currentSummary.trend >= 0 ? 'text-emerald-600 bg-emerald-50' : 'text-red-600 bg-red-50'}`}>
                {currentSummary.trend >= 0 ? <TrendingUp className="w-3 h-3 mr-1" /> : <TrendingDown className="w-3 h-3 mr-1" />} {Math.abs(currentSummary.trend)}%
              </span>
            </div>
            <p className="text-sm font-semibold text-slate-500 mb-1">Gross Revenue</p>
            <h3 className="text-3xl font-bold text-slate-800 font-heading">₹{currentSummary.revenue.toLocaleString(undefined, { maximumFractionDigits: 0 })}</h3>
          </div>

          <div className="card p-6 flex flex-col justify-between">
            <div className="flex justify-between items-start mb-4">
              <div className="p-3 bg-purple-50 rounded-xl text-purple-600">
                <Package className="w-6 h-6" />
              </div>
            </div>
            <p className="text-sm font-semibold text-slate-500 mb-1">Total Orders</p>
            <h3 className="text-3xl font-bold text-slate-800 font-heading">{currentSummary.orders}</h3>
          </div>

          <div className="card p-6 flex flex-col justify-between">
            <div className="flex justify-between items-start mb-4">
              <div className="p-3 bg-amber-50 rounded-xl text-amber-600">
                <LineChart className="w-6 h-6" />
              </div>
            </div>
            <p className="text-sm font-semibold text-slate-500 mb-1">Avg. Order Value</p>
            <h3 className="text-3xl font-bold text-slate-800 font-heading">₹{currentSummary.avgValue.toLocaleString(undefined, { maximumFractionDigits: 0 })}</h3>
          </div>

          <div className="card p-6 flex flex-col justify-between">
            <div className="flex justify-between items-start mb-4">
              <div className="p-3 bg-emerald-50 rounded-xl text-emerald-600">
                <FileText className="w-6 h-6" />
              </div>
            </div>
            <p className="text-sm font-semibold text-slate-500 mb-1">Tax Collected (GST)</p>
            <h3 className="text-3xl font-bold text-slate-800 font-heading">₹{currentSummary.tax.toLocaleString(undefined, { maximumFractionDigits: 0 })}</h3>
          </div>

          <div className="card p-6 flex flex-col justify-between">
            <div className="flex justify-between items-start mb-4">
              <div className="p-3 bg-indigo-50 rounded-xl text-indigo-600">
                <Package className="w-6 h-6" />
              </div>
            </div>
            <p className="text-sm font-semibold text-slate-500 mb-1">Inventory Value</p>
            <h3 className="text-3xl font-bold text-slate-800 font-heading">₹{currentSummary.totalInventoryCost.toLocaleString(undefined, { maximumFractionDigits: 0 })}</h3>
          </div>
        </motion.div>
      </AnimatePresence>

      {/* Main Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 mb-8">
        
        {/* Top Products */}
        <div className="card p-6">
          <div className="flex items-center justify-between mb-6">
            <h3 className="text-lg font-bold text-slate-800 font-heading flex items-center">
              <Award className="w-5 h-5 mr-2 text-amber-500" /> Top Products
            </h3>
          </div>
          <div className="space-y-4">
            {topProducts.length === 0 ? (
              <p className="text-sm text-slate-500 text-center py-4">No products sold in this period.</p>
            ) : (
              topProducts.map((prod, i) => (
                <div key={prod.id} className="flex items-center justify-between p-3 hover:bg-slate-50 rounded-xl transition-colors">
                  <div className="flex items-center gap-3">
                    <div className="w-8 text-center font-bold text-slate-400">#{i + 1}</div>
                    <div>
                      <p className="font-semibold text-slate-800">{prod.name}</p>
                      <p className="text-xs text-slate-500">{prod.qty} units sold</p>
                    </div>
                  </div>
                  <div className="font-bold text-slate-800">₹{prod.revenue.toLocaleString()}</div>
                </div>
              ))
            )}
          </div>
        </div>

        {/* Top Staff */}
        <div className="card p-6">
          <div className="flex items-center justify-between mb-6">
            <h3 className="text-lg font-bold text-slate-800 font-heading flex items-center">
              <Users className="w-5 h-5 mr-2 text-blue-500" /> Top Staff
            </h3>
          </div>
          <div className="space-y-4">
            {topStaff.length === 0 ? (
              <p className="text-sm text-slate-500 text-center py-4">No staff sales in this period.</p>
            ) : (
              topStaff.map((staff, i) => (
                <div key={staff.id} className="flex items-center justify-between p-3 hover:bg-slate-50 rounded-xl transition-colors">
                  <div className="flex items-center gap-3">
                    <div className="w-8 text-center font-bold text-slate-400">#{i + 1}</div>
                    <div className={`w-10 h-10 rounded-full flex items-center justify-center text-white font-bold ${staff.color}`}>
                      {staff.initial}
                    </div>
                    <div>
                      <p className="font-semibold text-slate-800">{staff.name}</p>
                      <p className="text-xs text-slate-500">{staff.points} pts earned</p>
                    </div>
                  </div>
                  <div className="font-bold text-slate-800">₹{staff.sales.toLocaleString()}</div>
                </div>
              ))
            )}
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* Low Stock Alerts */}
        <div className="card p-6">
          <div className="flex items-center justify-between mb-6">
            <h3 className="text-lg font-bold text-slate-800 font-heading flex items-center">
              <AlertTriangle className="w-5 h-5 mr-2 text-red-500" /> Low Stock
            </h3>
          </div>
          <div className="space-y-4">
            {lowStock.length === 0 ? (
              <p className="text-sm text-slate-500 text-center py-4">All stocks are at healthy levels.</p>
            ) : (
              lowStock.map((item) => (
                <div key={item.id} className="flex flex-col p-3 border border-red-100 bg-red-50/30 rounded-xl">
                  <div className="flex justify-between items-start mb-2">
                    <p className="font-semibold text-slate-800">{item.name}</p>
                    <span className="text-xs font-bold px-2 py-1 bg-red-100 text-red-600 rounded-md">
                      {item.stock} left
                    </span>
                  </div>
                  <div className="w-full bg-slate-200 rounded-full h-1.5">
                    <div className="bg-red-500 h-1.5 rounded-full" style={{ width: `${(item.stock / item.min) * 100}%` }}></div>
                  </div>
                  <p className="text-[10px] text-slate-500 mt-2 text-right">Min: {item.min}</p>
                </div>
              ))
            )}
          </div>
        </div>

        {/* Aging Stock */}
        <div className="card p-6">
          <div className="flex items-center justify-between mb-6">
            <h3 className="text-lg font-bold text-slate-800 font-heading flex items-center">
              <Package className="w-5 h-5 mr-2 text-orange-500" /> Aging Stock (&gt;90 days)
            </h3>
          </div>
          <div className="space-y-4">
            {agingStock.length === 0 ? (
              <p className="text-sm text-slate-500 text-center py-4">No aging stocks found.</p>
            ) : (
              agingStock.map((item) => (
                <div key={item.id} className="flex items-center justify-between p-3 border border-orange-100 bg-orange-50/30 rounded-xl">
                  <div>
                    <p className="font-semibold text-slate-800">{item.name}</p>
                    <p className="text-xs text-orange-600 font-medium">{item.days} days old</p>
                  </div>
                  <div className="font-bold text-slate-700 bg-white px-3 py-1 rounded-md shadow-sm">
                    {item.qty} qty
                  </div>
                </div>
              ))
            )}
          </div>
        </div>

        {/* GST Snapshot */}
        <div className="card p-6 bg-slate-800 text-white">
          <div className="flex items-center justify-between mb-6">
            <h3 className="text-lg font-bold font-heading flex items-center">
              <FileText className="w-5 h-5 mr-2 text-slate-300" /> GST Snapshot (Est.)
            </h3>
          </div>
          <div className="space-y-4">
            {gstSnapshotData.map((snap, i) => (
              <div key={i} className="flex flex-col p-4 bg-slate-700/50 rounded-xl border border-slate-600/50">
                <p className="text-sm font-semibold text-slate-300 mb-3">{snap.month}</p>
                <div className="flex justify-between items-center text-sm mb-1">
                  <span className="text-slate-400">Collected:</span>
                  <span className="font-semibold">₹{snap.collected.toLocaleString(undefined, { maximumFractionDigits: 0 })}</span>
                </div>
                <div className="flex justify-between items-center text-sm mb-3">
                  <span className="text-slate-400">Est. Paid:</span>
                  <span className="font-semibold text-emerald-400">₹{snap.paid.toLocaleString(undefined, { maximumFractionDigits: 0 })}</span>
                </div>
                <div className="flex justify-between items-center pt-2 border-t border-slate-600">
                  <span className="text-slate-300 font-semibold">Balance:</span>
                  <span className={`font-bold ${snap.balance > 0 ? 'text-amber-400' : 'text-slate-300'}`}>
                    ₹{snap.balance.toLocaleString(undefined, { maximumFractionDigits: 0 })}
                  </span>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

