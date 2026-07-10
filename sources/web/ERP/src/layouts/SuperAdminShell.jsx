import React from 'react';
import { Outlet } from 'react-router-dom';

export default function SuperAdminShell() {
  return (
    <div className="min-h-screen bg-slate-900 text-slate-100">
      <div className="flex h-screen overflow-hidden">
        <aside className="w-64 bg-slate-800 border-r border-slate-700 hidden md:flex flex-col">
          <div className="p-4 border-b border-slate-700">
            <h1 className="text-xl font-heading font-bold text-primary-400">Super Admin ERP</h1>
          </div>
          <div className="p-4 flex-1 overflow-y-auto">
            {/* Nav items */}
            <p className="text-sm text-slate-400">Admin Navigation</p>
          </div>
        </aside>

        <div className="flex-1 flex flex-col relative overflow-hidden">
          <header className="h-16 bg-slate-800 border-b border-slate-700 flex items-center justify-between px-6 z-10 shadow-sm">
            <h2 className="text-lg font-medium text-slate-200">System Control</h2>
            <div className="flex items-center space-x-4">
              <div className="w-8 h-8 rounded-full bg-support-purple flex items-center justify-center text-white font-bold">SA</div>
            </div>
          </header>
          
          <main className="flex-1 overflow-y-auto p-6 bg-slate-900/50">
            <Outlet />
          </main>
        </div>
      </div>
    </div>
  );
}
