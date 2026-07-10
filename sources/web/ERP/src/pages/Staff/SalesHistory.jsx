import React, { useState } from 'react';
import { Calendar, Filter, Download, ReceiptText, Search, Clock, CheckCircle2, AlertCircle } from 'lucide-react';
import { SALES_HISTORY, STAFF_STATS } from '../../data/mockData';
import KpiCard from '../../components/ui/KpiCard';

export default function SalesHistory() {
  const [filter, setFilter] = useState('today'); // today, week, month
  const [searchQuery, setSearchQuery] = useState('');

  const filteredHistory = SALES_HISTORY.filter(sale => {
    return sale.id.toLowerCase().includes(searchQuery.toLowerCase());
  });

  return (
    <div className="p-6 md:p-8 max-w-7xl mx-auto pb-24">
      {/* Header */}
      <div className="mb-8 flex flex-col md:flex-row md:items-end justify-between">
        <div>
          <h1 className="text-3xl font-bold text-slate-800 font-heading">My Sales History</h1>
          <p className="text-slate-500 mt-2">View and manage your recent transactions.</p>
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
          value={STAFF_STATS.salesToday}
          icon={ReceiptText}
          trend="up"
          trendValue="12%"
          colorClass="bg-blue-100 text-blue-600"
        />
        <KpiCard
          title="Revenue Today"
          value={`₹${STAFF_STATS.revenueToday.toLocaleString()}`}
          icon={ReceiptText}
          trend="up"
          trendValue={`${STAFF_STATS.trendPct}%`}
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
              placeholder="Search Invoice ID..."
              className="w-full pl-9 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-lg focus:ring-2 focus:ring-primary/50 focus:border-primary/50 text-sm"
              value={searchQuery}
              onChange={e => setSearchQuery(e.target.value)}
            />
          </div>
        </div>

        {/* Transactions List */}
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse min-w-[600px]">
            <thead>
              <tr className="bg-slate-50 border-b border-slate-100">
                <th className="p-4 text-xs font-semibold text-slate-500 uppercase tracking-wider">Invoice ID</th>
                <th className="p-4 text-xs font-semibold text-slate-500 uppercase tracking-wider">Time</th>
                <th className="p-4 text-xs font-semibold text-slate-500 uppercase tracking-wider">Items</th>
                <th className="p-4 text-xs font-semibold text-slate-500 uppercase tracking-wider text-right">Total</th>
                <th className="p-4 text-xs font-semibold text-slate-500 uppercase tracking-wider text-center">Status</th>
                <th className="p-4 text-xs font-semibold text-slate-500 uppercase tracking-wider text-right">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {filteredHistory.map((sale) => (
                <tr key={sale.id} className="hover:bg-slate-50/50 transition-colors">
                  <td className="p-4">
                    <span className="font-semibold text-slate-800">{sale.id}</span>
                  </td>
                  <td className="p-4">
                    <div className="flex items-center text-slate-500">
                      <Clock className="w-4 h-4 mr-2" />
                      {sale.time}
                    </div>
                  </td>
                  <td className="p-4 text-slate-600">{sale.items} items</td>
                  <td className="p-4 font-bold text-slate-800 text-right">₹{sale.total}</td>
                  <td className="p-4 text-center">
                    {sale.status === 'synced' ? (
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
                    <button className="text-primary hover:text-primary-dark font-medium text-sm">
                      View Receipt
                    </button>
                  </td>
                </tr>
              ))}
              {filteredHistory.length === 0 && (
                <tr>
                  <td colSpan="6" className="p-8 text-center text-slate-500">
                    No transactions found for the selected criteria.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
