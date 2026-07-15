import React from 'react';
import { motion } from 'framer-motion';
import { ArrowUpRight, ArrowDownRight } from 'lucide-react';

export default function KpiCard({ title, value, icon: Icon, trend, trendValue, colorClass }) {
  const isPositive = trend === 'up';

  return (
    <motion.div 
      whileHover={{ y: -2, boxShadow: '0 12px 32px -8px rgba(0,0,0,0.08)' }}
      className="card p-6 flex flex-col justify-between h-full"
    >
      <div className="flex justify-between items-start">
        <div>
          <p className="text-sm font-medium text-slate-500 mb-1">{title}</p>
          <h3 className="text-2xl font-bold text-slate-800 font-heading">{value}</h3>
        </div>
        <div className={`p-3 rounded-xl ${colorClass}`}>
          <Icon className="w-6 h-6" />
        </div>
      </div>
      
      <div className="mt-4 flex items-center text-sm">
        <span className={`flex items-center font-medium ${isPositive ? 'text-support-green' : 'text-red-500'}`}>
          {isPositive ? <ArrowUpRight className="w-4 h-4 mr-1" /> : <ArrowDownRight className="w-4 h-4 mr-1" />}
          {trendValue}
        </span>
        <span className="text-slate-400 ml-2">vs last month</span>
      </div>
    </motion.div>
  );
}
