import React from 'react';
import { Bell, Search, Menu } from 'lucide-react';
import useAuthStore from '../../store/authStore';

export default function Navbar({ title }) {
  const user = useAuthStore(state => state.user);
  
  return (
    <header className="h-16 glass-panel border-b-0 flex items-center justify-between px-6 z-10 sticky top-0">
      <div className="flex items-center gap-4">
        <button className="md:hidden p-2 text-slate-500 hover:bg-slate-100 rounded-md">
          <Menu className="w-5 h-5" />
        </button>
        <h2 className="text-lg font-heading font-semibold text-slate-800 hidden sm:block">{title}</h2>
      </div>

      <div className="flex items-center gap-6">
        {/* Global Search */}
        <div className="hidden md:flex relative group">
          <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 group-focus-within:text-primary-500 transition-colors" />
          <input 
            type="text" 
            placeholder="Search anything (Cmd+K)" 
            className="pl-9 pr-4 py-2 bg-slate-100/50 hover:bg-slate-100 border border-transparent rounded-full text-sm w-64 focus:bg-white focus:border-primary-300 focus:ring-4 focus:ring-primary-100 transition-all outline-none shadow-inner"
          />
        </div>

        {/* Actions */}
        <div className="flex items-center gap-3 border-l border-slate-200 pl-6">
          <button className="relative p-2 text-slate-500 hover:bg-slate-100 rounded-full transition-colors">
            <Bell className="w-5 h-5" />
            <span className="absolute top-1.5 right-1.5 w-2 h-2 bg-accent-orange rounded-full border border-white"></span>
          </button>
          
          <div className="flex items-center gap-3 cursor-pointer p-1 pr-2 hover:bg-slate-50 rounded-full transition-colors">
            <div className="w-8 h-8 rounded-full bg-primary-100 flex items-center justify-center text-primary-700 font-bold border border-primary-200">
              {user?.name ? user.name.charAt(0) : 'U'}
            </div>
            <div className="hidden sm:block text-sm">
              <p className="font-medium text-slate-700 leading-none">{user?.name || 'User'}</p>
              <p className="text-xs text-slate-500 mt-1 capitalize">{useAuthStore.getState().role?.replace('_', ' ') || 'Role'}</p>
            </div>
          </div>
        </div>
      </div>
    </header>
  );
}
