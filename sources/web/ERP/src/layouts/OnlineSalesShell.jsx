import React from 'react';
import { Outlet } from 'react-router-dom';
import Sidebar from '../components/layout/Sidebar';
import { Home, Globe, Grid, User, Bell } from 'lucide-react';
import useAuthStore from '../store/authStore';

const onlineSalesNavItems = [
  { name: 'Dashboard', path: '/online-sales', icon: Home },
  { name: 'Online Orders', path: '/online-sales/orders', icon: Globe },
  { name: 'Catalog', path: '/online-sales/catalog', icon: Grid },
  { name: 'Profile', path: '/online-sales/profile', icon: User },
];

export default function OnlineSalesShell() {
  const { user } = useAuthStore();
  const initials = user?.name ? user.name.substring(0, 2).toUpperCase() : 'OS';

  return (
    <div className="min-h-screen bg-[var(--background)]">
      <div className="flex h-screen overflow-hidden">
        <Sidebar items={onlineSalesNavItems} title="ToyShop Online" basePath="/online-sales" />

        <div className="flex-1 flex flex-col relative overflow-hidden">
          <header className="h-16 bg-white border-b border-slate-200 flex items-center justify-between px-6 z-10 shadow-sm">
            <h2 className="text-lg font-medium text-slate-800">Online Sales Workspace</h2>
            <div className="flex items-center space-x-4">
              <div className="w-8 h-8 rounded-full bg-blue-500 flex items-center justify-center text-white font-bold">{initials}</div>
            </div>
          </header>
          
          <main className="flex-1 overflow-y-auto p-6 bg-slate-50/50">
            <Outlet />
          </main>
        </div>
      </div>
    </div>
  );
}
