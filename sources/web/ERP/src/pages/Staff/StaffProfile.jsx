import React from 'react';
import { motion } from 'framer-motion';
import { ShoppingBag, Coins, Trophy, Globe, Fingerprint, Palette, LogOut, CheckCircle2, Award, ChevronRight } from 'lucide-react';
import useAuthStore from '../../store/authStore';
import { STAFF_STATS, BADGES } from '../../data/mockData';
import KpiCard from '../../components/ui/KpiCard';
import { useNavigate } from 'react-router-dom';

export default function StaffProfile() {
  const { user, logout } = useAuthStore();
  const navigate = useNavigate();

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  return (
    <div className="p-6 md:p-8 max-w-4xl mx-auto pb-24">
      {/* Header Profile Card */}
      <div className="card p-6 md:p-8 mb-8 flex flex-col md:flex-row items-center md:items-start gap-6">
        <div className={`w-24 h-24 rounded-full flex items-center justify-center text-4xl font-bold text-white shadow-lg ${user?.colorClass || 'bg-slate-800'}`}>
          {user?.initials || 'S'}
        </div>
        <div className="flex-1 text-center md:text-left">
          <h1 className="text-3xl font-bold text-slate-800 font-heading mb-2">{user?.name || 'Staff Member'}</h1>
          <div className="flex flex-wrap justify-center md:justify-start gap-3 items-center">
            <span className="px-3 py-1 bg-slate-100 text-slate-600 rounded-full text-sm font-semibold inline-flex items-center">
              <CheckCircle2 className="w-4 h-4 mr-1.5" />
              {user?.role === 'owner' ? 'Owner / Admin' : 'Staff'}
            </span>
            <span className="text-sm text-slate-500">Joined Jan 2026</span>
          </div>
        </div>
      </div>

      {/* Lifetime Stats */}
      <h2 className="text-xl font-bold text-slate-800 font-heading mb-4">Lifetime Statistics</h2>
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-8">
        <KpiCard
          title="Lifetime Units Sold"
          value={STAFF_STATS.lifetimeUnits.toLocaleString()}
          icon={ShoppingBag}
          trend="up"
          trendValue="Overall"
          colorClass="bg-blue-100 text-blue-600"
        />
        <KpiCard
          title="Lifetime Revenue"
          value={`₹${STAFF_STATS.lifetimeSales.toLocaleString()}`}
          icon={Coins}
          trend="up"
          trendValue="Overall"
          colorClass="bg-green-100 text-green-600"
        />
      </div>

      {/* Badges */}
      <div className="flex items-center justify-between mb-4 mt-8">
        <div>
          <h2 className="text-xl font-bold text-slate-800 font-heading">Badges Earned</h2>
          <p className="text-sm text-slate-500">
            {BADGES.filter(b => b.earned).length} of {BADGES.length} unlocked
          </p>
        </div>
      </div>
      
      <div className="flex flex-wrap gap-4 mb-10">
        {BADGES.map(badge => (
          <div 
            key={badge.id}
            className={`w-[100px] p-3 rounded-2xl border flex flex-col items-center justify-center gap-2 text-center transition-all ${
              badge.earned 
                ? 'bg-amber-50 border-amber-200 shadow-sm' 
                : 'bg-slate-50 border-slate-100 opacity-60 grayscale'
            }`}
          >
            <div className={`p-2 rounded-full ${badge.earned ? 'bg-amber-100 text-amber-600' : 'bg-slate-200 text-slate-500'}`}>
              <Award className="w-6 h-6" />
            </div>
            <span className={`text-xs font-bold leading-tight ${badge.earned ? 'text-amber-900' : 'text-slate-500'}`}>
              {badge.title}
            </span>
          </div>
        ))}
      </div>

      {/* Settings List */}
      <h2 className="text-xl font-bold text-slate-800 font-heading mb-4">Settings</h2>
      <div className="card overflow-hidden mb-8">
        <div className="divide-y divide-slate-100">
          
          <button className="w-full flex items-center p-4 hover:bg-slate-50 transition-colors text-left group">
            <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center text-primary mr-4 group-hover:scale-110 transition-transform">
              <Globe className="w-5 h-5" />
            </div>
            <div className="flex-1">
              <p className="font-bold text-slate-800">Voice search language</p>
              <p className="text-sm text-slate-500">English (India)</p>
            </div>
            <ChevronRight className="w-5 h-5 text-slate-400" />
          </button>

          <button className="w-full flex items-center p-4 hover:bg-slate-50 transition-colors text-left group">
            <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center text-primary mr-4 group-hover:scale-110 transition-transform">
              <Fingerprint className="w-5 h-5" />
            </div>
            <div className="flex-1">
              <p className="font-bold text-slate-800">Biometric unlock</p>
              <p className="text-sm text-slate-500">Off</p>
            </div>
            <ChevronRight className="w-5 h-5 text-slate-400" />
          </button>

          <button className="w-full flex items-center p-4 hover:bg-slate-50 transition-colors text-left group">
            <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center text-primary mr-4 group-hover:scale-110 transition-transform">
              <Palette className="w-5 h-5" />
            </div>
            <div className="flex-1">
              <p className="font-bold text-slate-800">Appearance</p>
              <p className="text-sm text-slate-500">Light mode (Prototype)</p>
            </div>
            <ChevronRight className="w-5 h-5 text-slate-400" />
          </button>
        </div>
      </div>

      {/* Sign Out */}
      <button 
        onClick={handleLogout}
        className="w-full card p-4 flex items-center justify-center text-red-500 font-bold hover:bg-red-50 transition-colors border border-transparent hover:border-red-100"
      >
        <LogOut className="w-5 h-5 mr-2" />
        Sign Out
      </button>

      <p className="text-center text-slate-400 text-xs mt-6">
        ToyShop ERP · v1.0.0 · web-prototype
      </p>
    </div>
  );
}
