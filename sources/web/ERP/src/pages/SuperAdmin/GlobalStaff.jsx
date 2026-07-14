import React, { useState, useEffect } from 'react';
import { Users, Search, Filter, Mail, Shield, Loader2 } from 'lucide-react';
import { motion } from 'framer-motion';
import api from '../../services/api';

export default function GlobalStaff() {
  const [searchTerm, setSearchTerm] = useState('');
  const [staffData, setStaffData] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchStaffData();
  }, []);

  const fetchStaffData = async () => {
    try {
      setLoading(true);
      const response = await api.get('/superadmin/staff');
      if (response.data.success) {
        setStaffData(response.data.data);
      }
    } catch (error) {
      console.error('Failed to fetch staff data:', error);
    } finally {
      setLoading(false);
    }
  };

  const filteredStaff = staffData.filter(staff => 
    staff.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    staff.role.toLowerCase().includes(searchTerm.toLowerCase()) ||
    staff.tenant.toLowerCase().includes(searchTerm.toLowerCase()) ||
    staff.id.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="max-w-7xl mx-auto pb-24">
      <div className="flex flex-col md:flex-row md:items-center justify-between mb-8 gap-4">
        <div>
          <h1 className="text-3xl font-bold text-slate-900 font-heading">Global Staff Directory</h1>
          <p className="text-slate-500 mt-2">Manage and view all personnel across all tenants.</p>
        </div>
        <div className="flex items-center gap-3">
          <button className="flex items-center gap-2 bg-white border border-slate-200 text-slate-700 px-4 py-2 rounded-xl text-sm font-medium hover:bg-slate-50 transition-colors shadow-sm">
            <Filter className="w-4 h-4" /> Filter
          </button>
        </div>
      </div>

      <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
        <div className="p-4 border-b border-slate-100 flex items-center justify-between bg-slate-50/50">
          <div className="relative w-full max-w-md">
            <Search className="w-5 h-5 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
            <input 
              type="text" 
              placeholder="Search staff by name, role, or tenant..." 
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
                  <th className="px-6 py-4 text-xs font-bold text-slate-500 uppercase tracking-wider">Staff Member</th>
                  <th className="px-6 py-4 text-xs font-bold text-slate-500 uppercase tracking-wider">Contact</th>
                  <th className="px-6 py-4 text-xs font-bold text-slate-500 uppercase tracking-wider">Tenant / Branch</th>
                  <th className="px-6 py-4 text-xs font-bold text-slate-500 uppercase tracking-wider">Role & Status</th>
                  <th className="px-6 py-4 text-xs font-bold text-slate-500 uppercase tracking-wider text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {filteredStaff.map((staff, idx) => (
                  <motion.tr 
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: idx * 0.05 }}
                    key={staff.id} 
                    className="hover:bg-slate-50/80 transition-colors group"
                  >
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-full bg-gradient-to-tr from-primary-600 to-primary-400 flex items-center justify-center flex-shrink-0 text-white font-bold shadow-inner">
                          {staff.name.charAt(0)}
                        </div>
                        <div>
                          <p className="font-semibold text-slate-900 text-sm">{staff.name}</p>
                          <p className="text-xs text-slate-500">{staff.id}</p>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <div className="flex items-center text-slate-600 text-sm">
                        <Mail className="w-4 h-4 mr-2 text-slate-400" />
                        {staff.email}
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <p className="font-medium text-slate-800 text-sm">{staff.tenant}</p>
                      <p className="text-xs text-slate-500">{staff.branch}</p>
                    </td>
                    <td className="px-6 py-4">
                      <div className="flex flex-col items-start gap-1">
                        <div className="flex items-center gap-1.5 text-sm font-medium text-slate-700">
                          <Shield className="w-3.5 h-3.5 text-primary-500" />
                          {staff.role}
                        </div>
                        <span className={`text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full ${
                          staff.status === 'Active' ? 'bg-emerald-100 text-emerald-700' : 'bg-slate-100 text-slate-600'
                        }`}>
                          {staff.status}
                        </span>
                      </div>
                    </td>
                    <td className="px-6 py-4 text-right">
                      <button className="text-sm font-medium text-primary-600 hover:text-primary-700 transition-colors">
                        View Profile
                      </button>
                    </td>
                  </motion.tr>
                ))}
                {!loading && filteredStaff.length === 0 && (
                  <tr>
                    <td colSpan="5" className="p-8 text-center text-slate-500">
                      No staff found.
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
