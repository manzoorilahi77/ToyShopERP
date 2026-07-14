import React, { useState, useEffect } from 'react';
import { Store, Users, Server, Activity, DollarSign, Database, ShieldAlert } from 'lucide-react';
import { motion } from 'framer-motion';
import api from '../../services/api';

const ICON_MAP = {
  Store,
  Users,
  Activity,
  DollarSign
};

export default function SuperAdminDashboard() {
  const [kpis, setKpis] = useState([]);
  const [recentActivity, setRecentActivity] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchDashboardData();
  }, []);

  const fetchDashboardData = async () => {
    try {
      setLoading(true);
      const response = await api.get('/superadmin/dashboard');
      if (response.data.success) {
        setKpis(response.data.data.kpis);
        setRecentActivity(response.data.data.recentActivity);
      }
    } catch (error) {
      console.error('Failed to fetch dashboard data:', error);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return <div className="p-8 text-center text-slate-500">Loading dashboard...</div>;
  }

  return (
    <div className="max-w-7xl mx-auto pb-24">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-slate-900 font-heading">Command Center</h1>
        <p className="text-slate-500 mt-2">Global overview of the ToyShop ERP platform.</p>
      </div>

      {/* KPIs Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        {kpis.map((kpi, idx) => {
          const IconComponent = ICON_MAP[kpi.iconName] || Activity;
          return (
            <motion.div 
              key={kpi.id}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: idx * 0.1 }}
              className="bg-white rounded-2xl p-6 border border-slate-200 shadow-sm hover:shadow-md transition-shadow"
            >
              <div className="flex justify-between items-start mb-4">
                <div className={`p-3 rounded-xl ${kpi.bg} ${kpi.color}`}>
                  <IconComponent className="w-6 h-6" />
                </div>
              </div>
              <p className="text-sm font-semibold text-slate-500 mb-1">{kpi.title}</p>
              <h3 className="text-3xl font-bold text-slate-900 font-heading">{kpi.value}</h3>
            </motion.div>
          );
        })}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* System Status */}
        <div className="lg:col-span-2 bg-white rounded-2xl p-6 border border-slate-200 shadow-sm">
          <div className="flex items-center justify-between mb-6">
            <h2 className="text-lg font-bold text-slate-900 font-heading flex items-center">
              <Server className="w-5 h-5 mr-2 text-primary-600" /> Infrastructure Status
            </h2>
            <span className="flex items-center text-xs font-bold bg-emerald-100 text-emerald-700 px-3 py-1 rounded-full">
              <span className="w-2 h-2 rounded-full bg-emerald-500 mr-2 animate-pulse"></span>
              All Systems Operational
            </span>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="bg-slate-50 p-4 rounded-xl border border-slate-100">
              <p className="text-sm font-semibold text-slate-600 mb-2 flex justify-between">Database <span className="text-emerald-600">92%</span></p>
              <div className="w-full bg-slate-200 rounded-full h-2">
                <div className="bg-emerald-500 h-2 rounded-full" style={{ width: '92%' }}></div>
              </div>
            </div>
            <div className="bg-slate-50 p-4 rounded-xl border border-slate-100">
              <p className="text-sm font-semibold text-slate-600 mb-2 flex justify-between">App Servers <span className="text-amber-500">78%</span></p>
              <div className="w-full bg-slate-200 rounded-full h-2">
                <div className="bg-amber-500 h-2 rounded-full" style={{ width: '78%' }}></div>
              </div>
            </div>
            <div className="bg-slate-50 p-4 rounded-xl border border-slate-100">
              <p className="text-sm font-semibold text-slate-600 mb-2 flex justify-between">Storage <span className="text-blue-500">45%</span></p>
              <div className="w-full bg-slate-200 rounded-full h-2">
                <div className="bg-blue-500 h-2 rounded-full" style={{ width: '45%' }}></div>
              </div>
            </div>
          </div>
        </div>

        {/* Activity Feed */}
        <div className="bg-white rounded-2xl p-6 border border-slate-200 shadow-sm">
          <div className="flex items-center justify-between mb-6">
            <h2 className="text-lg font-bold text-slate-900 font-heading flex items-center">
              <Activity className="w-5 h-5 mr-2 text-purple-600" /> Recent Activity
            </h2>
          </div>
          <div className="space-y-4">
            {recentActivity.map((activity) => (
              <div key={activity.id} className="flex gap-4">
                <div className="mt-1">
                  {activity.type === 'success' && <div className="w-2 h-2 rounded-full bg-emerald-500 ring-4 ring-emerald-100"></div>}
                  {activity.type === 'warning' && <div className="w-2 h-2 rounded-full bg-amber-500 ring-4 ring-amber-100"></div>}
                  {activity.type === 'info' && <div className="w-2 h-2 rounded-full bg-blue-500 ring-4 ring-blue-100"></div>}
                </div>
                <div>
                  <p className="text-sm font-medium text-slate-700">{activity.text}</p>
                  <p className="text-xs text-slate-500 mt-1">{activity.time}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
