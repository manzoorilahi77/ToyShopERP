import React from 'react';
import { Outlet } from 'react-router-dom';
import Sidebar from '../components/layout/Sidebar';
import Navbar from '../components/layout/Navbar';
import { LayoutDashboard, PackagePlus, LineChart, Box, Store, Users, FileText, Bell, Settings, ReceiptText } from 'lucide-react';

const ownerNavItems = [
  { name: 'Home', path: '/owner', icon: LayoutDashboard },
  { name: 'Stock Addition', path: '/owner/stock-addition', icon: PackagePlus },
  { name: 'Reports', path: '/owner/reports', icon: LineChart },
  { name: 'Sales', path: '/owner/sales', icon: ReceiptText },
  { name: 'Product Catalog', path: '/owner/catalog', icon: Box },
  { name: 'Branches', path: '/owner/branches', icon: Store },
  { name: 'Staff Management', path: '/owner/staff', icon: Users },
  { name: 'GST', path: '/owner/gst', icon: FileText },
  { name: 'Notifications', path: '/owner/notifications', icon: Bell },
  { name: 'Settings', path: '/owner/settings', icon: Settings },
];

export default function OwnerShell() {
  return (
    <div className="min-h-screen bg-[var(--background)]">
      <div className="flex h-screen overflow-hidden">
        <Sidebar items={ownerNavItems} title="Owner Dashboard" basePath="/owner" />

        <div className="flex-1 flex flex-col relative overflow-hidden">
          <Navbar title="Owner Dashboard" />
          
          <main className="flex-1 overflow-y-auto p-6 lg:p-8 bg-slate-50/50">
            <Outlet />
          </main>
        </div>
      </div>
    </div>
  );
}
