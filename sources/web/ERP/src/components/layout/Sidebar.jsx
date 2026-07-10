import React from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { LogOut, ToyBrick } from 'lucide-react';
import useAuthStore from '../../store/authStore';

export default function Sidebar({ items, title = "ToyShop ERP", basePath = "" }) {
  const logout = useAuthStore(state => state.logout);
  const navigate = useNavigate();

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  return (
    <aside className="w-64 bg-white border-r border-slate-200 hidden md:flex flex-col h-full shadow-sm z-20 relative">
      <div className="h-16 flex items-center px-6 border-b border-slate-200">
        <div className="flex items-center gap-2 text-primary-600">
          <ToyBrick className="w-8 h-8" />
          <h1 className="text-xl font-heading font-bold tracking-tight truncate">{title}</h1>
        </div>
      </div>
      
      <div className="flex-1 overflow-y-auto py-6 px-4 flex flex-col gap-1">
        {items.map((item) => (
          <NavLink
            key={item.name}
            to={item.path}
            end={item.path === basePath}
            className={({ isActive }) =>
              `flex items-center gap-3 px-3 py-2.5 rounded-lg transition-all duration-200 group relative ${
                isActive 
                  ? 'text-primary-700 bg-primary-50 font-medium' 
                  : 'text-slate-600 hover:bg-slate-50 hover:text-slate-900'
              }`
            }
          >
            {({ isActive }) => (
              <>
                <item.icon className={`w-5 h-5 ${isActive ? 'text-primary-600' : 'text-slate-400 group-hover:text-slate-600'}`} />
                <span>{item.name}</span>
                {isActive && (
                  <motion.div
                    layoutId={`sidebar-active-${basePath}`}
                    className="absolute left-0 w-1 h-full bg-primary-600 rounded-r-md"
                    initial={false}
                    transition={{ type: "spring", stiffness: 300, damping: 30 }}
                  />
                )}
              </>
            )}
          </NavLink>
        ))}
      </div>

      <div className="p-4 border-t border-slate-200">
        <button 
          onClick={handleLogout}
          className="flex w-full items-center gap-3 px-3 py-2.5 text-slate-600 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors"
        >
          <LogOut className="w-5 h-5" />
          <span>Logout</span>
        </button>
      </div>
    </aside>
  );
}
