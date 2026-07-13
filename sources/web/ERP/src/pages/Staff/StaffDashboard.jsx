import React from 'react';
import { motion } from 'framer-motion';
import { IndianRupee, ShoppingCart, Award, Target, ChevronRight } from 'lucide-react';
import { Link } from 'react-router-dom';
import useAuthStore from '../../store/authStore';
import KpiCard from '../../components/ui/KpiCard';
import { getStaffDashboard, getLeaderboard } from '../../services/dashboardService';
import { getCatalog } from '../../services/productService';
import toast from 'react-hot-toast';

export default function StaffDashboard() {
  const { user } = useAuthStore();
  const [staffStats, setStaffStats] = React.useState({ salesToday: 0, revenueToday: 0, points: 0 });
  const [leaderboard, setLeaderboard] = React.useState([]);
  const [quickPicks, setQuickPicks] = React.useState([]);
  const [loading, setLoading] = React.useState(true);

  React.useEffect(() => {
    const loadDashboardData = async () => {
      try {
        const [statsRes, leaderboardRes, catalogRes] = await Promise.all([
          getStaffDashboard(),
          getLeaderboard(),
          getCatalog()
        ]);
        
        setStaffStats(statsRes.data || { salesToday: 0, revenueToday: 0, points: 0 });
        
        // Setup leaderboard with initials/color
        const lbData = (leaderboardRes.data || []).map((u, idx) => ({
          ...u,
          rank: idx + 1,
          isMe: u.id === user?.id,
          initials: u.name.split(' ').map(n => n[0]).join('').toUpperCase().substring(0,2),
          color: 'bg-blue-600' // Default or dynamic later
        }));
        setLeaderboard(lbData);

        // Get favorites
        const favorites = (catalogRes.data || []).filter(c => c.isFavorite).slice(0, 4);
        setQuickPicks(favorites);
      } catch (error) {
        toast.error('Failed to load dashboard data');
      } finally {
        setLoading(false);
      }
    };
    loadDashboardData();
  }, [user]);

  if (loading) {
    return (
      <div className="p-6 md:p-8 max-w-7xl mx-auto flex justify-center py-24">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
      </div>
    );
  }

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
          value={staffStats.salesToday}
          icon={ShoppingCart}
          colorClass="bg-blue-100 text-blue-600"
        />
        <KpiCard
          title="Revenue Today"
          value={`₹${staffStats.revenueToday.toLocaleString()}`}
          icon={IndianRupee}
          colorClass="bg-green-100 text-green-600"
        />
        <KpiCard
          title="Total Points"
          value={staffStats.points}
          icon={Award}
          colorClass="bg-purple-100 text-purple-600"
        />
        <KpiCard
          title="Leaderboard Rank"
          value={`#${leaderboard.find(l => l.isMe)?.rank || '-'}`}
          icon={Target}
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
            {leaderboard.map((person) => (
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
            {leaderboard.length === 0 && (
              <p className="text-sm text-slate-500 text-center py-4">No users found on leaderboard.</p>
            )}
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
