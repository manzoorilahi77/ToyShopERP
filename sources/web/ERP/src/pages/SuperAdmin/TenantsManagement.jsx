import React, { useState, useEffect } from 'react';
import { Store, Plus, Search, MoreVertical, ShieldAlert, CheckCircle2, Loader2 } from 'lucide-react';
import { motion } from 'framer-motion';
import api from '../../services/api';

export default function TenantsManagement() {
  const [searchTerm, setSearchTerm] = useState('');
  const [tenants, setTenants] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchTenants();
  }, []);

  const fetchTenants = async () => {
    try {
      setLoading(true);
      const response = await api.get('/superadmin/tenants');
      if (response.data.success) {
        setTenants(response.data.data);
      }
    } catch (error) {
      console.error('Failed to fetch tenants:', error);
    } finally {
      setLoading(false);
    }
  };

  const filteredTenants = tenants.filter(t => 
    t.name.toLowerCase().includes(searchTerm.toLowerCase()) || 
    t.id.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="max-w-7xl mx-auto pb-24">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-8">
        <div>
          <h1 className="text-3xl font-bold text-white font-heading">Tenants Management</h1>
          <p className="text-slate-400 mt-2">Manage all registered shops and owners.</p>
        </div>
        <button className="bg-primary-500 hover:bg-primary-400 text-white font-bold py-2.5 px-6 rounded-xl flex items-center transition-colors shadow-lg shadow-primary-500/20">
          <Plus className="w-5 h-5 mr-2" />
          Add Tenant
        </button>
      </div>

      <div className="bg-slate-800 rounded-2xl border border-slate-700/50 shadow-lg overflow-hidden">
        {/* Toolbar */}
        <div className="p-4 border-b border-slate-700 bg-slate-800/50 flex gap-4">
          <div className="relative flex-1 max-w-md">
            <Search className="w-5 h-5 absolute left-3 top-1/2 -translate-y-1/2 text-slate-500" />
            <input 
              type="text" 
              placeholder="Search tenants by name or ID..."
              className="w-full bg-slate-900 border border-slate-700 rounded-xl pl-10 pr-4 py-2 text-slate-200 focus:outline-none focus:border-primary-500 focus:ring-1 focus:ring-primary-500 transition-colors"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
          <select className="bg-slate-900 border border-slate-700 rounded-xl px-4 py-2 text-slate-200 focus:outline-none focus:border-primary-500">
            <option>All Plans</option>
            <option>Starter</option>
            <option>Pro</option>
            <option>Enterprise</option>
          </select>
        </div>

        {/* Table */}
        <div className="overflow-x-auto min-h-[200px] relative">
          {loading ? (
            <div className="absolute inset-0 flex items-center justify-center bg-slate-800/50">
              <Loader2 className="w-8 h-8 animate-spin text-primary-500" />
            </div>
          ) : (
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="bg-slate-900/50 text-slate-400 text-sm uppercase tracking-wider">
                  <th className="p-4 font-semibold">Tenant Name</th>
                  <th className="p-4 font-semibold">Owner</th>
                  <th className="p-4 font-semibold">Plan</th>
                  <th className="p-4 font-semibold">Branches</th>
                  <th className="p-4 font-semibold">Revenue</th>
                  <th className="p-4 font-semibold">Status</th>
                  <th className="p-4 font-semibold text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-700/50 text-slate-300">
                {filteredTenants.map((tenant, idx) => (
                  <motion.tr 
                    key={tenant.id}
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: idx * 0.05 }}
                    className="hover:bg-slate-700/30 transition-colors group"
                  >
                    <td className="p-4">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-lg bg-slate-900 flex items-center justify-center text-primary-400">
                          <Store className="w-5 h-5" />
                        </div>
                        <div>
                          <p className="font-bold text-white">{tenant.name}</p>
                          <p className="text-xs text-slate-500">ID: {tenant.id}</p>
                        </div>
                      </div>
                    </td>
                    <td className="p-4 font-medium">{tenant.owner}</td>
                    <td className="p-4">
                      <span className="bg-slate-900 px-3 py-1 rounded-md text-sm border border-slate-700 text-slate-300">
                        {tenant.plan}
                      </span>
                    </td>
                    <td className="p-4">{tenant.branches}</td>
                    <td className="p-4 font-mono">{tenant.revenue}</td>
                    <td className="p-4">
                      <span className={`inline-flex items-center text-xs font-bold px-2.5 py-1 rounded-full ${
                        tenant.status === 'Active' ? 'bg-emerald-500/20 text-emerald-400' : 'bg-red-500/20 text-red-400'
                      }`}>
                        {tenant.status === 'Active' ? <CheckCircle2 className="w-3 h-3 mr-1" /> : <ShieldAlert className="w-3 h-3 mr-1" />}
                        {tenant.status}
                      </span>
                    </td>
                    <td className="p-4 text-right">
                      <button className="p-2 text-slate-500 hover:text-white hover:bg-slate-700 rounded-lg transition-colors opacity-0 group-hover:opacity-100">
                        <MoreVertical className="w-5 h-5" />
                      </button>
                    </td>
                  </motion.tr>
                ))}
                {!loading && filteredTenants.length === 0 && (
                  <tr>
                    <td colSpan="7" className="p-8 text-center text-slate-500">
                      No tenants found.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          )}
        </div>
      </div>
    </div>
  );
}
