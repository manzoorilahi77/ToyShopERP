import React from 'react';
import { Outlet, NavLink, useNavigate, useLocation } from 'react-router-dom';
import { LayoutDashboard, Store, TerminalSquare, Settings, LogOut, Package, Users, CreditCard } from 'lucide-react';
import useAuthStore from '../store/authStore';

const superAdminNavItems = [
  { name: 'Dashboard', path: '/super-admin', icon: LayoutDashboard },
  { name: 'Tenants', path: '/super-admin/tenants', icon: Store },
  { name: 'Global Stock', path: '/super-admin/stock', icon: Package },
  { name: 'Global Staff', path: '/super-admin/staff', icon: Users },
  { name: 'System Logs', path: '/super-admin/logs', icon: TerminalSquare },
  { name: 'Global Settings', path: '/super-admin/settings', icon: Settings },
];

export default function SuperAdminShell() {
  const { user, logout } = useAuthStore();
  const navigate = useNavigate();
  const location = useLocation();

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  return (
    <div className="min-h-screen bg-slate-50 text-slate-800 flex overflow-hidden">
      
      {/* Sidebar */}
      <aside className="w-64 bg-white border-r border-slate-200 hidden md:flex flex-col shadow-sm z-20">
        <div className="h-16 flex items-center px-6 border-b border-slate-100">
          <h1 className="text-xl font-heading font-bold text-primary-600 tracking-wide">
            ToyShop<span className="text-slate-800">ERP</span>
          </h1>
        </div>
        
        <div className="p-4 flex-1 overflow-y-auto">
          <p className="text-xs font-bold text-slate-400 uppercase tracking-wider mb-4 px-2">System Admin</p>
          <nav className="space-y-1">
            {superAdminNavItems.map((item) => (
              <NavLink
                key={item.path}
                to={item.path}
                end={item.path === '/super-admin'}
                className={({ isActive }) =>
                  `flex items-center px-3 py-2.5 rounded-xl text-sm font-medium transition-all duration-200 ${
                    isActive
                      ? 'bg-primary-50 text-primary-700 shadow-sm ring-1 ring-primary-100'
                      : 'text-slate-500 hover:bg-slate-50 hover:text-slate-900'
                  }`
                }
              >
                <item.icon className={`mr-3 h-5 w-5 flex-shrink-0 transition-colors ${
                    location.pathname === item.path || (item.path === '/super-admin' && location.pathname === '/super-admin')
                      ? 'text-primary-600'
                      : 'text-slate-400 group-hover:text-slate-600'
                  }`} />
                {item.name}
              </NavLink>
            ))}
          </nav>
        </div>

        <div className="p-4 border-t border-slate-100 bg-slate-50/50">
          <button 
            onClick={handleLogout}
            className="flex items-center w-full px-3 py-2.5 text-sm font-medium text-slate-600 rounded-xl hover:bg-red-50 hover:text-red-600 transition-colors"
          >
            <LogOut className="mr-3 h-5 w-5 text-slate-400 group-hover:text-red-500" />
            Sign Out
          </button>
        </div>
      </aside>

      {/* Main Content */}
      <div className="flex-1 flex flex-col relative overflow-hidden">
        <header className="h-16 bg-white/80 backdrop-blur-md border-b border-slate-200 flex items-center justify-between px-6 z-10 sticky top-0 shadow-sm">
          <h2 className="text-lg font-bold text-slate-800 font-heading">Command Center</h2>
          <div className="flex items-center space-x-4">
            <div className="flex items-center gap-3 bg-white rounded-full pl-4 pr-1.5 py-1.5 border border-slate-200 shadow-sm hover:shadow-md transition-shadow cursor-pointer">
              <span className="text-sm font-medium text-slate-700">{user?.name || 'Admin'}</span>
              <div className="w-8 h-8 rounded-full bg-gradient-to-tr from-primary-600 to-primary-400 flex items-center justify-center text-white font-bold text-sm shadow-inner">
                {user?.initials || 'SA'}
              </div>
            </div>
          </div>
        </header>
        
        <main className="flex-1 overflow-y-auto p-6 lg:p-8 bg-slate-50">
          <Outlet />
        </main>
      </div>

    </div>
  );
}
