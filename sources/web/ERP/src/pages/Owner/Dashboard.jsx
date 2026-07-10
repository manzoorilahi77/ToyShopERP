import React from 'react';
import { motion } from 'framer-motion';
import { DollarSign, ShoppingBag, ShoppingCart, Package, TrendingUp } from 'lucide-react';
import { 
  AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
  BarChart, Bar, Legend
} from 'recharts';
import KpiCard from '../../components/ui/KpiCard';

const revenueData = [
  { name: 'Jan', total: 12000 },
  { name: 'Feb', total: 19000 },
  { name: 'Mar', total: 15000 },
  { name: 'Apr', total: 28000 },
  { name: 'May', total: 22000 },
  { name: 'Jun', total: 32000 },
];

const salesData = [
  { name: 'Mon', sales: 4000, purchases: 2400 },
  { name: 'Tue', sales: 3000, purchases: 1398 },
  { name: 'Wed', sales: 2000, purchases: 9800 },
  { name: 'Thu', sales: 2780, purchases: 3908 },
  { name: 'Fri', sales: 1890, purchases: 4800 },
  { name: 'Sat', sales: 2390, purchases: 3800 },
  { name: 'Sun', sales: 3490, purchases: 4300 },
];

export default function Dashboard() {
  return (
    <div className="space-y-6">
      <div className="flex justify-between items-end">
        <div>
          <h1 className="text-2xl font-bold text-slate-800 font-heading">Dashboard Overview</h1>
          <p className="text-slate-500 mt-1 text-sm">Welcome back, here's what's happening today.</p>
        </div>
        <button className="btn-primary">
          <TrendingUp className="w-4 h-4 mr-2" />
          Generate Report
        </button>
      </div>

      {/* KPI Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-6">
        <KpiCard 
          title="Today's Sales" 
          value="$4,250.00" 
          icon={DollarSign} 
          trend="up" 
          trendValue="12.5%" 
          colorClass="bg-blue-100 text-blue-600"
        />
        <KpiCard 
          title="Today's Orders" 
          value="156" 
          icon={ShoppingCart} 
          trend="up" 
          trendValue="8.2%" 
          colorClass="bg-green-100 text-green-600"
        />
        <KpiCard 
          title="Today's Purchases" 
          value="$1,840.00" 
          icon={ShoppingBag} 
          trend="down" 
          trendValue="4.1%" 
          colorClass="bg-orange-100 text-orange-600"
        />
        <KpiCard 
          title="Inventory Alerts" 
          value="12 items" 
          icon={Package} 
          trend="down" 
          trendValue="2.0%" 
          colorClass="bg-red-100 text-red-600"
        />
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 xl:grid-cols-3 gap-6 mt-8">
        <motion.div 
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="card p-6 xl:col-span-2"
        >
          <h3 className="text-lg font-semibold text-slate-800 mb-6">Revenue Analytics</h3>
          <div className="h-[300px] w-full">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={revenueData} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
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
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.1 }}
          className="card p-6"
        >
          <h3 className="text-lg font-semibold text-slate-800 mb-6">Sales vs Purchases</h3>
          <div className="h-[300px] w-full">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={salesData} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#e2e8f0" />
                <XAxis dataKey="name" stroke="#94a3b8" fontSize={12} tickLine={false} axisLine={false} />
                <YAxis stroke="#94a3b8" fontSize={12} tickLine={false} axisLine={false} tickFormatter={(value) => `$${value/1000}k`} />
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
