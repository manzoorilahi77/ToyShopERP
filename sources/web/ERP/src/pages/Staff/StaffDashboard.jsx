import React from 'react';
import { motion } from 'framer-motion';
import { IndianRupee, ShoppingCart, Award, Target, ChevronRight } from 'lucide-react';
import { Link } from 'react-router-dom';
import useAuthStore from '../../store/authStore';
import KpiCard from '../../components/ui/KpiCard';
import { STAFF_STATS, LEADERBOARD, CATALOG } from '../../data/mockData';

export default function StaffDashboard() {
  const { user } = useAuthStore();
  
  // Get just a few items for quick picks
  const quickPicks = CATALOG.filter(c => c.isFavorite).slice(0, 4);

  return (
    <div className="p-6 md:p-8 max-w-7xl mx-auto pb-24">
      {/* Header */}
      <div className="mb-8 flex flex-col md:flex-row md:items-end justify-between">
        <div>
          <h1 className="text-3xl font-bold text-slate-800 font-heading">
            Good Morning, {user?.name || 'Staff'}! 👋
          </h1>
          <p className="text-slate-500 mt-2">Here's your performance snapshot for today.</p>
        </div>
        <div className="mt-4 md:mt-0">
          <Link to="/staff/sell" className="btn-primary inline-flex items-center">
            <ShoppingCart className="w-5 h-5 mr-2" />
            New Sale
          </Link>
        </div>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <KpiCard
          title="Sales Today"
          value={STAFF_STATS.salesToday}
          icon={ShoppingCart}
          trend="up"
          trendValue="12%"
          colorClass="bg-blue-100 text-blue-600"
        />
        <KpiCard
          title="Revenue Today"
          value={`₹${STAFF_STATS.revenueToday.toLocaleString()}`}
          icon={IndianRupee}
          trend="up"
          trendValue={`${STAFF_STATS.trendPct}%`}
          colorClass="bg-green-100 text-green-600"
        />
        <KpiCard
          title="Points This Month"
          value={STAFF_STATS.monthPoints}
          icon={Award}
          trend="up"
          trendValue="5%"
          colorClass="bg-purple-100 text-purple-600"
        />
        <KpiCard
          title="Leaderboard Rank"
          value={STAFF_STATS.rankLabel}
          icon={Target}
          trend="up"
          trendValue="Maintained"
          colorClass="bg-orange-100 text-orange-600"
        />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8 mb-8">
        {/* Leaderboard */}
        <div className="lg:col-span-1 card p-6">
          <div className="flex items-center justify-between mb-6">
            <h3 className="text-xl font-bold text-slate-800 font-heading">Leaderboard</h3>
            <Award className="text-yellow-500 w-6 h-6" />
          </div>
          
          <div className="space-y-4">
            {LEADERBOARD.map((person) => (
              <div 
                key={person.id} 
                className={`flex items-center p-3 rounded-xl transition-colors ${
                  person.isMe ? 'bg-primary/10 border border-primary/20' : 'hover:bg-slate-50'
                }`}
              >
                <div className="w-8 text-center font-bold text-slate-400">
                  #{person.rank}
                </div>
                <div className={`w-10 h-10 rounded-full flex items-center justify-center text-white font-bold ml-2 ${person.color}`}>
                  {person.initials}
                </div>
                <div className="ml-4 flex-1">
                  <p className="font-semibold text-slate-800">
                    {person.name} {person.isMe && <span className="text-xs text-primary ml-1">(You)</span>}
                  </p>
                  <p className="text-sm text-slate-500">{person.points} pts</p>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Quick Picks */}
        <div className="lg:col-span-2 card p-6">
          <div className="flex items-center justify-between mb-6">
            <h3 className="text-xl font-bold text-slate-800 font-heading">Quick Picks (Favorites)</h3>
            <Link to="/staff/catalog" className="text-primary text-sm font-semibold flex items-center hover:underline">
              View All <ChevronRight className="w-4 h-4 ml-1" />
            </Link>
          </div>
          
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {quickPicks.map((toy) => (
              <Link 
                key={toy.id}
                to={`/staff/catalog`}
                className="group relative rounded-2xl overflow-hidden border border-slate-100 shadow-sm hover:shadow-md transition-all duration-300 flex flex-col h-full bg-white"
              >
                <div className="h-32 w-full overflow-hidden bg-slate-100">
                  <img 
                    src={toy.image} 
                    alt={toy.name} 
                    className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
                  />
                </div>
                <div className="p-3 flex-1 flex flex-col">
                  <p className="font-semibold text-slate-800 text-sm line-clamp-2 leading-tight flex-1 mb-2">
                    {toy.name}
                  </p>
                  <div className="flex items-center justify-between mt-auto">
                    <span className="font-bold text-slate-800">₹{toy.price}</span>
                    <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center text-primary group-hover:bg-primary group-hover:text-white transition-colors">
                      <ShoppingCart className="w-4 h-4" />
                    </div>
                  </div>
                </div>
              </Link>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
