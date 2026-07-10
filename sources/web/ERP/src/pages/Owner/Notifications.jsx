import React, { useState } from 'react';
import { Bell, AlertTriangle, CheckCircle2, Info, Trash2, Check } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import toast from 'react-hot-toast';

export default function Notifications() {
  const [notifications, setNotifications] = useState([
    { id: 'n1', type: 'alert', title: 'Low Stock Alert', message: 'Hot Wheels 5-Pack is running low in Main Branch (2 left).', time: '10 mins ago', read: false },
    { id: 'n2', type: 'success', title: 'Daily Sync Complete', message: 'All branch data synced successfully to the cloud.', time: '2 hours ago', read: false },
    { id: 'n3', type: 'info', title: 'New Feature Available', message: 'Check out the new GST reports dashboard in the reports section.', time: '1 day ago', read: true },
    { id: 'n4', type: 'alert', title: 'High Value Sale', message: 'A sale of ₹15,400 was recorded at Downtown Branch.', time: '2 days ago', read: true },
  ]);

  const getIcon = (type) => {
    switch(type) {
      case 'alert': return <AlertTriangle className="w-5 h-5 text-amber-500" />;
      case 'success': return <CheckCircle2 className="w-5 h-5 text-emerald-500" />;
      default: return <Info className="w-5 h-5 text-blue-500" />;
    }
  };

  const getBg = (type) => {
    switch(type) {
      case 'alert': return 'bg-amber-50';
      case 'success': return 'bg-emerald-50';
      default: return 'bg-blue-50';
    }
  };

  const markAllRead = () => {
    setNotifications(prev => prev.map(n => ({ ...n, read: true })));
    toast.success('All marked as read');
  };

  const clearAll = () => {
    setNotifications([]);
    toast.success('Notifications cleared');
  };

  return (
    <div className="max-w-3xl mx-auto pb-24">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-8">
        <div>
          <h1 className="text-3xl font-bold text-slate-800 font-heading flex items-center gap-3">
            Notifications
            {notifications.filter(n => !n.read).length > 0 && (
              <span className="bg-primary text-white text-sm font-bold px-3 py-1 rounded-full">
                {notifications.filter(n => !n.read).length} New
              </span>
            )}
          </h1>
          <p className="text-slate-500 mt-2">Stay updated with your business activities.</p>
        </div>

        <div className="flex items-center gap-2">
          <button 
            onClick={markAllRead}
            disabled={notifications.length === 0}
            className="px-4 py-2 text-sm font-bold text-slate-600 bg-white border border-slate-200 rounded-lg hover:bg-slate-50 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center"
          >
            <Check className="w-4 h-4 mr-2" />
            Mark All Read
          </button>
          <button 
            onClick={clearAll}
            disabled={notifications.length === 0}
            className="px-4 py-2 text-sm font-bold text-red-600 bg-white border border-slate-200 rounded-lg hover:bg-red-50 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center"
          >
            <Trash2 className="w-4 h-4 mr-2" />
            Clear All
          </button>
        </div>
      </div>

      <div className="space-y-4">
        <AnimatePresence>
          {notifications.map(notif => (
            <motion.div 
              key={notif.id}
              initial={{ opacity: 0, x: -10 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, scale: 0.95 }}
              className={`p-4 rounded-2xl border transition-all ${
                notif.read 
                  ? 'bg-white border-slate-200' 
                  : 'bg-white border-primary/20 shadow-[0_0_15px_-3px_rgba(var(--primary-rgb),0.1)]'
              }`}
            >
              <div className="flex gap-4">
                <div className={`mt-1 p-2 rounded-full h-fit ${getBg(notif.type)}`}>
                  {getIcon(notif.type)}
                </div>
                <div className="flex-1">
                  <div className="flex justify-between items-start">
                    <h4 className={`font-bold ${notif.read ? 'text-slate-700' : 'text-slate-900'}`}>
                      {notif.title}
                    </h4>
                    <span className="text-xs font-semibold text-slate-400 whitespace-nowrap ml-4">
                      {notif.time}
                    </span>
                  </div>
                  <p className={`mt-1 text-sm ${notif.read ? 'text-slate-500' : 'text-slate-700 font-medium'}`}>
                    {notif.message}
                  </p>
                </div>
                {!notif.read && (
                  <div className="w-2.5 h-2.5 rounded-full bg-primary mt-2 flex-shrink-0"></div>
                )}
              </div>
            </motion.div>
          ))}
        </AnimatePresence>

        {notifications.length === 0 && (
          <div className="py-16 text-center text-slate-400">
            <Bell className="w-12 h-12 mx-auto mb-4 opacity-20" />
            <p className="font-semibold text-lg">You're all caught up!</p>
            <p className="text-sm mt-1">No new notifications right now.</p>
          </div>
        )}
      </div>
    </div>
  );
}
