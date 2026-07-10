import React from 'react';
import { Outlet } from 'react-router-dom';
import Sidebar from '../components/layout/Sidebar';
import { Home, ShoppingCart, Receipt, Grid, User } from 'lucide-react';

const staffNavItems = [
  { name: 'Home', path: '/staff', icon: Home },
  { name: 'Sell', path: '/staff/sell', icon: ShoppingCart },
  { name: 'History', path: '/staff/history', icon: Receipt },
  { name: 'Catalog', path: '/staff/catalog', icon: Grid },
  { name: 'Profile', path: '/staff/profile', icon: User },
];

export default function StaffShell() {
  return (
    <div className="min-h-screen bg-[var(--background)]">
      <div className="flex h-screen overflow-hidden">
        <Sidebar items={staffNavItems} title="ToyShop POS" basePath="/staff" />

        <div className="flex-1 flex flex-col relative overflow-hidden">
          <header className="h-16 bg-white border-b border-slate-200 flex items-center justify-between px-6 z-10 shadow-sm">
            <h2 className="text-lg font-medium text-slate-800">Staff POS / Dashboard</h2>
            <div className="flex items-center space-x-4">
              <div className="w-8 h-8 rounded-full bg-accent-orange flex items-center justify-center text-white font-bold">S</div>
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
