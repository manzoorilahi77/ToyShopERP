import React, { useState } from 'react';
import { 
  LineChart, TrendingUp, TrendingDown, 
  Package, Users, AlertTriangle, FileText, 
  IndianRupee, ChevronDown, Award
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

const PERIODS = ['Today', 'Yesterday', 'Last 7 Days', 'This Month'];
const BRANCHES = ['All Branches', 'Main Branch', 'Downtown', 'Mall Kiosk'];

const BRANCH_MULTIPLIER = {
  'All Branches': 1,
  'Main Branch': 0.5,
  'Downtown': 0.3,
  'Mall Kiosk': 0.2
};

// Mock Data
const SUMMARY_DATA_BY_PERIOD = {
  'Today': {
    revenue: 45200, orders: 28, avgValue: 1614, tax: 8136, trend: 12.5,
  },
  'Yesterday': {
    revenue: 38500, orders: 24, avgValue: 1604, tax: 6930, trend: -2.1,
  },
  'Last 7 Days': {
    revenue: 285000, orders: 195, avgValue: 1461, tax: 51300, trend: 8.4,
  },
  'This Month': {
    revenue: 1125000, orders: 840, avgValue: 1339, tax: 202500, trend: 15.2,
  }
};

const TOP_PRODUCTS = [
  { id: 1, name: 'Remote Control Car', qty: 45, revenue: 22500 },
  { id: 2, name: 'Lego Creator Set', qty: 32, revenue: 15900 },
  { id: 3, name: 'Barbie Dreamhouse', qty: 12, revenue: 11400 },
  { id: 4, name: 'Nerf Elite Blaster', qty: 28, revenue: 8400 },
];

const TOP_STAFF = [
  { id: 1, name: 'Rahul S.', points: 450, sales: 25000, initial: 'R', color: 'bg-blue-500' },
  { id: 2, name: 'Priya M.', points: 380, sales: 18500, initial: 'P', color: 'bg-green-500' },
  { id: 3, name: 'Amit K.', points: 310, sales: 15200, initial: 'A', color: 'bg-purple-500' },
];

const LOW_STOCK = [
  { id: 1, name: 'Marvel Action Figure', stock: 2, min: 10 },
  { id: 2, name: 'Uno Cards', stock: 4, min: 20 },
  { id: 3, name: 'Hot Wheels 5-Pack', stock: 1, min: 15 },
];

const AGING_STOCK = [
  { id: 1, name: 'Giant Teddy Bear', days: 95, qty: 3 },
  { id: 2, name: 'Summer Water Gun', days: 120, qty: 15 },
];

const GST_SNAPSHOT = [
  { month: 'Jun 2026', collected: 24500, paid: 18200, balance: 6300 },
  { month: 'May 2026', collected: 22100, paid: 22100, balance: 0 },
];

export default function Reports() {
  const [period, setPeriod] = useState('Today');
  const [branch, setBranch] = useState('All Branches');
  
  const baseSummary = SUMMARY_DATA_BY_PERIOD[period];
  const mult = BRANCH_MULTIPLIER[branch];

  const currentSummary = {
    revenue: baseSummary.revenue * mult,
    orders: Math.max(1, Math.floor(baseSummary.orders * mult)),
    avgValue: baseSummary.avgValue, // avg value doesn't scale with branch size linearly, keeps realistic
    tax: baseSummary.tax * mult,
    trend: baseSummary.trend
  };

  return (
    <div className="max-w-7xl mx-auto pb-24">
      {/* Header & Filters */}
      <div className="flex flex-col xl:flex-row xl:items-center justify-between gap-4 mb-8">
        <div>
          <h1 className="text-3xl font-bold text-slate-800 font-heading">Reports & Analytics</h1>
          <p className="text-slate-500 mt-2">Comprehensive view of your business performance {period.toLowerCase()} at {branch}.</p>
        </div>
        
        <div className="flex flex-col sm:flex-row gap-2">
          <div className="relative">
            <select 
              value={branch} 
              onChange={(e) => setBranch(e.target.value)}
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
        </div>
      </div>

      {/* KPI Cards */}
      <AnimatePresence mode="wait">
        <motion.div 
          key={`${period}-${branch}`}
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: -10 }}
          transition={{ duration: 0.2 }}
          className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6 mb-8"
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
            {TOP_PRODUCTS.map((prod, i) => (
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
            ))}
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
            {TOP_STAFF.map((staff, i) => (
              <div key={staff.id} className="flex items-center justify-between p-3 hover:bg-slate-50 rounded-xl transition-colors">
                <div className="flex items-center gap-3">
                  <div className="w-8 text-center font-bold text-slate-400">#{i + 1}</div>
                  <div className={`w-10 h-10 rounded-full flex items-center justify-center text-white font-bold ${staff.color}`}>
                    {staff.initial}
                  </div>
                  <div>
                    <p className="font-semibold text-slate-800">{staff.name}</p>
                    <p className="text-xs text-slate-500">{staff.points} pts</p>
                  </div>
                </div>
                <div className="font-bold text-slate-800">₹{staff.sales.toLocaleString()}</div>
              </div>
            ))}
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
            {LOW_STOCK.map((item) => (
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
            ))}
          </div>
        </div>

        {/* Aging Stock */}
        <div className="card p-6">
          <div className="flex items-center justify-between mb-6">
            <h3 className="text-lg font-bold text-slate-800 font-heading flex items-center">
              <Package className="w-5 h-5 mr-2 text-orange-500" /> Aging Stock (90 days)
            </h3>
          </div>
          <div className="space-y-4">
            {AGING_STOCK.map((item) => (
              <div key={item.id} className="flex items-center justify-between p-3 border border-orange-100 bg-orange-50/30 rounded-xl">
                <div>
                  <p className="font-semibold text-slate-800">{item.name}</p>
                  <p className="text-xs text-orange-600 font-medium">{item.days} days old</p>
                </div>
                <div className="font-bold text-slate-700 bg-white px-3 py-1 rounded-md shadow-sm">
                  {item.qty} qty
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* GST Snapshot */}
        <div className="card p-6 bg-slate-800 text-white">
          <div className="flex items-center justify-between mb-6">
            <h3 className="text-lg font-bold font-heading flex items-center">
              <FileText className="w-5 h-5 mr-2 text-slate-300" /> GST Snapshot
            </h3>
          </div>
          <div className="space-y-4">
            {GST_SNAPSHOT.map((snap, i) => (
              <div key={i} className="flex flex-col p-4 bg-slate-700/50 rounded-xl border border-slate-600/50">
                <p className="text-sm font-semibold text-slate-300 mb-3">{snap.month}</p>
                <div className="flex justify-between items-center text-sm mb-1">
                  <span className="text-slate-400">Collected:</span>
                  <span className="font-semibold">₹{snap.collected.toLocaleString()}</span>
                </div>
                <div className="flex justify-between items-center text-sm mb-3">
                  <span className="text-slate-400">Paid:</span>
                  <span className="font-semibold text-emerald-400">₹{snap.paid.toLocaleString()}</span>
                </div>
                <div className="flex justify-between items-center pt-2 border-t border-slate-600">
                  <span className="text-slate-300 font-semibold">Balance:</span>
                  <span className={`font-bold ${snap.balance > 0 ? 'text-amber-400' : 'text-slate-300'}`}>
                    ₹{snap.balance.toLocaleString()}
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
