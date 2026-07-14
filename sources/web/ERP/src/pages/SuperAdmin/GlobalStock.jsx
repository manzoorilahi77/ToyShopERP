import React, { useState, useEffect } from 'react';
import { Package, Search, Filter, ArrowDownToLine, MoreVertical, Loader2 } from 'lucide-react';
import { motion } from 'framer-motion';
import api from '../../services/api';

export default function GlobalStock() {
  const [searchTerm, setSearchTerm] = useState('');
  const [stockData, setStockData] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchStockData();
  }, []);

  const fetchStockData = async () => {
    try {
      setLoading(true);
      const response = await api.get('/superadmin/stock');
      if (response.data.success) {
        setStockData(response.data.data);
      }
    } catch (error) {
      console.error('Failed to fetch stock data:', error);
    } finally {
      setLoading(false);
    }
  };

  const filteredStock = stockData.filter(item => 
    item.name.toLowerCase().includes(searchTerm.toLowerCase()) || 
    item.id.toLowerCase().includes(searchTerm.toLowerCase()) ||
    item.tenant.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="max-w-7xl mx-auto pb-24">
      <div className="flex flex-col md:flex-row md:items-center justify-between mb-8 gap-4">
        <div>
          <h1 className="text-3xl font-bold text-slate-900 font-heading">Global Stock</h1>
          <p className="text-slate-500 mt-2">Aggregate view of all inventory across tenants.</p>
        </div>
        <div className="flex items-center gap-3">
          <button className="flex items-center gap-2 bg-white border border-slate-200 text-slate-700 px-4 py-2 rounded-xl text-sm font-medium hover:bg-slate-50 transition-colors shadow-sm">
            <Filter className="w-4 h-4" /> Filter
          </button>
          <button className="flex items-center gap-2 bg-primary-600 text-white px-4 py-2 rounded-xl text-sm font-medium hover:bg-primary-700 transition-colors shadow-sm">
            <ArrowDownToLine className="w-4 h-4" /> Export CSV
          </button>
        </div>
      </div>

      <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
        <div className="p-4 border-b border-slate-100 flex items-center justify-between bg-slate-50/50">
          <div className="relative w-full max-w-md">
            <Search className="w-5 h-5 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
            <input 
              type="text" 
              placeholder="Search products by name, SKU, or tenant..." 
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full pl-10 pr-4 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-500/20 focus:border-primary-500 transition-all shadow-sm"
            />
          </div>
        </div>
        
        <div className="overflow-x-auto min-h-[200px] relative">
          {loading ? (
            <div className="absolute inset-0 flex items-center justify-center bg-white/50">
              <Loader2 className="w-8 h-8 animate-spin text-primary-500" />
            </div>
          ) : (
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="bg-slate-50 border-b border-slate-200">
                  <th className="px-6 py-4 text-xs font-bold text-slate-500 uppercase tracking-wider">Product Info</th>
                  <th className="px-6 py-4 text-xs font-bold text-slate-500 uppercase tracking-wider">Tenant / Branch</th>
                  <th className="px-6 py-4 text-xs font-bold text-slate-500 uppercase tracking-wider">Stock</th>
                  <th className="px-6 py-4 text-xs font-bold text-slate-500 uppercase tracking-wider">Price (₹)</th>
                  <th className="px-6 py-4 text-xs font-bold text-slate-500 uppercase tracking-wider text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {filteredStock.map((item, idx) => (
                  <motion.tr 
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: idx * 0.05 }}
                    key={item.id} 
                    className="hover:bg-slate-50/80 transition-colors group"
                  >
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-xl bg-primary-50 flex items-center justify-center flex-shrink-0 border border-primary-100">
                          <Package className="w-5 h-5 text-primary-600" />
                        </div>
                        <div>
                          <p className="font-semibold text-slate-900 text-sm">{item.name}</p>
                          <p className="text-xs text-slate-500">{item.id} &bull; {item.category}</p>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <p className="font-medium text-slate-800 text-sm">{item.tenant}</p>
                      <p className="text-xs text-slate-500">{item.branch}</p>
                    </td>
                    <td className="px-6 py-4">
                      <div className="flex flex-col items-start gap-1">
                        <span className="font-bold text-slate-900">{item.stock} units</span>
                        <span className={`text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full ${
                          item.stock > 20 ? 'bg-emerald-100 text-emerald-700' : 
                          item.stock > 0 ? 'bg-amber-100 text-amber-700' : 'bg-red-100 text-red-700'
                        }`}>
                          {item.status}
                        </span>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <p className="font-medium text-slate-900">₹{item.price.toLocaleString()}</p>
                    </td>
                    <td className="px-6 py-4 text-right">
                      <button className="text-slate-400 hover:text-primary-600 transition-colors p-2 rounded-lg hover:bg-primary-50">
                        <MoreVertical className="w-5 h-5" />
                      </button>
                    </td>
                  </motion.tr>
                ))}
                {!loading && filteredStock.length === 0 && (
                  <tr>
                    <td colSpan="5" className="p-8 text-center text-slate-500">
                      No products found.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          )}
        </div>
        <div className="p-4 border-t border-slate-100 flex items-center justify-between bg-slate-50/50">
          <p className="text-sm text-slate-500">Showing <span className="font-medium text-slate-900">{filteredStock.length}</span> of {stockData.length} products</p>
          <div className="flex gap-2">
            <button className="px-3 py-1 text-sm border border-slate-200 rounded-lg text-slate-600 bg-white hover:bg-slate-50 disabled:opacity-50" disabled>Prev</button>
            <button className="px-3 py-1 text-sm border border-slate-200 rounded-lg text-slate-600 bg-white hover:bg-slate-50">Next</button>
          </div>
        </div>
      </div>
    </div>
  );
}
