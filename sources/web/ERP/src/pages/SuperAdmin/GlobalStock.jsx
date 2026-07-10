import React, { useState } from 'react';
import { Package, Search, Filter, ArrowDownToLine, MoreVertical } from 'lucide-react';
import { motion } from 'framer-motion';

const MOCK_GLOBAL_STOCK = [
  { id: 'STK-001', name: 'LEGO Star Wars Millennium Falcon', category: 'Building Blocks', tenant: 'Kids Paradise', branch: 'Downtown', stock: 45, price: 15999, status: 'In Stock' },
  { id: 'STK-002', name: 'Hot Wheels 50-Car Pack', category: 'Vehicles', tenant: 'Toy Universe', branch: 'Westside Mall', stock: 12, price: 2499, status: 'Low Stock' },
  { id: 'STK-003', name: 'Barbie Dreamhouse', category: 'Dolls', tenant: 'Kids Paradise', branch: 'North Park', stock: 0, price: 8999, status: 'Out of Stock' },
  { id: 'STK-004', name: 'Nerf N-Strike Elite', category: 'Action', tenant: 'Fun & Learn', branch: 'City Center', stock: 120, price: 1499, status: 'In Stock' },
  { id: 'STK-005', name: 'UNO Card Game', category: 'Card Games', tenant: 'Toy Universe', branch: 'Downtown', stock: 500, price: 199, status: 'In Stock' },
];

export default function GlobalStock() {
  const [searchTerm, setSearchTerm] = useState('');

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
        
        <div className="overflow-x-auto">
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
              {MOCK_GLOBAL_STOCK.map((item, idx) => (
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
            </tbody>
          </table>
        </div>
        <div className="p-4 border-t border-slate-100 flex items-center justify-between bg-slate-50/50">
          <p className="text-sm text-slate-500">Showing <span className="font-medium text-slate-900">5</span> of 4,291 products</p>
          <div className="flex gap-2">
            <button className="px-3 py-1 text-sm border border-slate-200 rounded-lg text-slate-600 bg-white hover:bg-slate-50 disabled:opacity-50" disabled>Prev</button>
            <button className="px-3 py-1 text-sm border border-slate-200 rounded-lg text-slate-600 bg-white hover:bg-slate-50">Next</button>
          </div>
        </div>
      </div>
    </div>
  );
}
