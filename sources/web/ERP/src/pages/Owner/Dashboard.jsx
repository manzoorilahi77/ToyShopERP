import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { DollarSign, ShoppingBag, ShoppingCart, Package, TrendingUp, ChevronDown } from 'lucide-react';
import { 
  AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
  BarChart, Bar, Legend
} from 'recharts';
import KpiCard from '../../components/ui/KpiCard';

const PERIODS = ['Today', 'Yesterday', 'Last 7 Days', 'This Month'];
const BRANCHES = ['All Branches', 'Main Branch', 'Downtown', 'Mall Kiosk'];

const BRANCH_MULTIPLIER = {
  'All Branches': 1,
  'Main Branch': 0.5,
  'Downtown': 0.3,
  'Mall Kiosk': 0.2
};

const MOCK_DATA_BY_PERIOD = {
  'Today': {
    revenue: 4250, orders: 156, purchases: 1840, alerts: 12,
    revenueData: [
      { name: '8 AM', total: 500 }, { name: '10 AM', total: 1200 }, { name: '12 PM', total: 2500 },
      { name: '2 PM', total: 3200 }, { name: '4 PM', total: 4000 }, { name: 'Now', total: 4250 },
    ],
    salesData: [
      { name: 'Morning', sales: 1500, purchases: 800 },
      { name: 'Afternoon', sales: 2750, purchases: 1040 },
    ]
  },
  'Yesterday': {
    revenue: 3800, orders: 142, purchases: 1500, alerts: 8,
    revenueData: [
      { name: '8 AM', total: 400 }, { name: '10 AM', total: 1000 }, { name: '12 PM', total: 2000 },
      { name: '2 PM', total: 2800 }, { name: '4 PM', total: 3500 }, { name: '8 PM', total: 3800 },
    ],
    salesData: [
      { name: 'Morning', sales: 1200, purchases: 600 },
      { name: 'Afternoon', sales: 2600, purchases: 900 },
    ]
  },
  'Last 7 Days': {
    revenue: 28450, orders: 945, purchases: 12300, alerts: 24,
    revenueData: [
      { name: 'Mon', total: 4200 }, { name: 'Tue', total: 3800 }, { name: 'Wed', total: 4500 },
      { name: 'Thu', total: 3900 }, { name: 'Fri', total: 5100 }, { name: 'Sat', total: 6200 },
      { name: 'Sun', total: 4800 },
    ],
    salesData: [
      { name: 'Mon', sales: 4200, purchases: 1800 }, { name: 'Tue', sales: 3800, purchases: 1500 },
      { name: 'Wed', sales: 4500, purchases: 2000 }, { name: 'Thu', sales: 3900, purchases: 1600 },
      { name: 'Fri', sales: 5100, purchases: 2200 }, { name: 'Sat', sales: 6200, purchases: 2500 },
      { name: 'Sun', sales: 4800, purchases: 2000 },
    ]
  },
  'This Month': {
    revenue: 112500, orders: 3850, purchases: 48200, alerts: 45,
    revenueData: [
      { name: 'Week 1', total: 28000 }, { name: 'Week 2', total: 32000 }, 
      { name: 'Week 3', total: 29000 }, { name: 'Week 4', total: 33500 },
    ],
    salesData: [
      { name: 'Week 1', sales: 28000, purchases: 12000 }, { name: 'Week 2', sales: 32000, purchases: 14000 },
      { name: 'Week 3', sales: 29000, purchases: 11500 }, { name: 'Week 4', sales: 33500, purchases: 15000 },
    ]
  }
};

export default function Dashboard() {
  const [period, setPeriod] = useState('Today');
  const [branch, setBranch] = useState('All Branches');
  
  const baseData = MOCK_DATA_BY_PERIOD[period];
  const mult = BRANCH_MULTIPLIER[branch];

  const currentData = {
    revenue: `$${(baseData.revenue * mult).toLocaleString()}`,
    orders: Math.floor(baseData.orders * mult),
    purchases: `$${(baseData.purchases * mult).toLocaleString()}`,
    alerts: Math.max(1, Math.floor(baseData.alerts * mult)),
    revenueData: baseData.revenueData.map(d => ({ ...d, total: d.total * mult })),
    salesData: baseData.salesData.map(d => ({ ...d, sales: d.sales * mult, purchases: d.purchases * mult }))
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-end justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-800 font-heading">Dashboard Overview</h1>
          <p className="text-slate-500 mt-1 text-sm">Welcome back, here's what's happening {period.toLowerCase()} at {branch}.</p>
        </div>
        <div className="flex flex-wrap items-center gap-3">
          <div className="relative">
            <select 
              value={branch} 
              onChange={(e) => setBranch(e.target.value)}
              className="appearance-none bg-white border border-slate-200 rounded-lg pl-4 pr-10 py-2.5 text-sm font-semibold text-slate-700 focus:outline-none focus:ring-2 focus:ring-primary-500/50 shadow-sm cursor-pointer hover:bg-slate-50 transition-colors"
            >
              {BRANCHES.map(b => <option key={b} value={b}>{b}</option>)}
            </select>
            <ChevronDown className="w-4 h-4 text-slate-400 absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none" />
          </div>
          <div className="relative">
            <select 
              value={period} 
              onChange={(e) => setPeriod(e.target.value)}
              className="appearance-none bg-white border border-slate-200 rounded-lg pl-4 pr-10 py-2.5 text-sm font-semibold text-slate-700 focus:outline-none focus:ring-2 focus:ring-primary-500/50 shadow-sm cursor-pointer hover:bg-slate-50 transition-colors"
            >
              {PERIODS.map(p => <option key={p} value={p}>{p}</option>)}
            </select>
            <ChevronDown className="w-4 h-4 text-slate-400 absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none" />
          </div>
          <button className="btn-primary">
            <TrendingUp className="w-4 h-4 mr-2" />
            Generate Report
          </button>
        </div>
      </div>

      {/* KPI Grid */}
      <AnimatePresence mode="wait">
        <motion.div 
          key={`${period}-${branch}`}
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: -10 }}
          transition={{ duration: 0.2 }}
          className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-6"
        >
          <KpiCard 
            title="Revenue" 
            value={currentData.revenue} 
            icon={DollarSign} 
            trend="up" 
            trendValue="12.5%" 
            colorClass="bg-blue-100 text-blue-600"
          />
          <KpiCard 
            title="Orders" 
            value={currentData.orders} 
            icon={ShoppingCart} 
            trend="up" 
            trendValue="8.2%" 
            colorClass="bg-green-100 text-green-600"
          />
          <KpiCard 
            title="Purchases" 
            value={currentData.purchases} 
            icon={ShoppingBag} 
            trend="down" 
            trendValue="4.1%" 
            colorClass="bg-orange-100 text-orange-600"
          />
          <KpiCard 
            title="Inventory Alerts" 
            value={`${currentData.alerts} items`} 
            icon={Package} 
            trend="down" 
            trendValue="2.0%" 
            colorClass="bg-red-100 text-red-600"
          />
        </motion.div>
      </AnimatePresence>

      {/* Charts */}
      <div className="grid grid-cols-1 xl:grid-cols-3 gap-6 mt-8">
        <motion.div 
          key={`revenue-${period}-${branch}`}
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="card p-6 xl:col-span-2"
        >
          <h3 className="text-lg font-semibold text-slate-800 mb-6">Revenue Analytics ({period})</h3>
          <div className="h-[300px] w-full">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={currentData.revenueData} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                <defs>
                  <linearGradient id="colorTotal" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#2563eb" stopOpacity={0.3}/>
                    <stop offset="95%" stopColor="#2563eb" stopOpacity={0}/>
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#e2e8f0" />
                <XAxis dataKey="name" stroke="#94a3b8" fontSize={12} tickLine={false} axisLine={false} />
                <YAxis stroke="#94a3b8" fontSize={12} tickLine={false} axisLine={false} tickFormatter={(value) => `$${value}`} />
                <Tooltip 
                  contentStyle={{ borderRadius: '8px', border: 'none', boxShadow: 'var(--shadow-card)' }}
                  formatter={(value) => [`$${value}`, 'Revenue']}
                />
                <Area type="monotone" dataKey="total" stroke="#2563eb" strokeWidth={3} fillOpacity={1} fill="url(#colorTotal)" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </motion.div>

        <motion.div 
          key={`sales-${period}-${branch}`}
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.1 }}
          className="card p-6"
        >
          <h3 className="text-lg font-semibold text-slate-800 mb-6">Sales vs Purchases</h3>
          <div className="h-[300px] w-full">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={currentData.salesData} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#e2e8f0" />
                <XAxis dataKey="name" stroke="#94a3b8" fontSize={12} tickLine={false} axisLine={false} />
                <YAxis stroke="#94a3b8" fontSize={12} tickLine={false} axisLine={false} tickFormatter={(value) => `$${value > 1000 ? value/1000 + 'k' : value}`} />
                <Tooltip cursor={{fill: '#f1f5f9'}} contentStyle={{ borderRadius: '8px', border: 'none', boxShadow: 'var(--shadow-card)' }} />
                <Legend iconType="circle" wrapperStyle={{ fontSize: '12px' }} />
                <Bar dataKey="sales" name="Sales" fill="#2563eb" radius={[4, 4, 0, 0]} barSize={12} />
                <Bar dataKey="purchases" name="Purchases" fill="#38bdf8" radius={[4, 4, 0, 0]} barSize={12} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </motion.div>
      </div>

    </div>
  );
}
