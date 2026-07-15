import React, { useState, useEffect } from 'react';
import { Bell, AlertTriangle, CheckCircle2, Info, Check, Loader2 } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import toast from 'react-hot-toast';
import api from '../../services/api';

export default function Notifications() {
  const [notifications, setNotifications] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchNotifications();
  }, []);

  const fetchNotifications = async () => {
    try {
      setLoading(true);
      const res = await api.get('/notifications');
      setNotifications(res.data?.data || []);
    } catch (error) {
      toast.error('Failed to load notifications');
    } finally {
      setLoading(false);
    }
  };

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

  const markAllRead = async () => {
    const unread = notifications.filter(n => !n.isRead);
    if (unread.length === 0) return;
    
    try {
      await Promise.all(unread.map(n => api.patch(`/notifications/${n.id}/read`)));
      setNotifications(prev => prev.map(n => ({ ...n, isRead: true })));
      toast.success('All marked as read');
    } catch (error) {
      toast.error('Failed to mark all as read');
    }
  };

  const markAsRead = async (id, isRead) => {
    if (isRead) return;
    try {
      await api.patch(`/notifications/${id}/read`);
      setNotifications(prev => prev.map(n => n.id === id ? { ...n, isRead: true } : n));
    } catch (error) {
      console.error('Failed to mark as read', error);
    }
  };

  const unreadCount = notifications.filter(n => !n.isRead).length;

  return (
    <div className="max-w-3xl mx-auto pb-24">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-8">
        <div>
          <h1 className="text-3xl font-bold text-slate-800 font-heading flex items-center gap-3">
            Notifications
            {unreadCount > 0 && (
              <span className="bg-primary text-white text-sm font-bold px-3 py-1 rounded-full">
                {unreadCount} New
              </span>
            )}
          </h1>
          <p className="text-slate-500 mt-2">Stay updated with your business activities.</p>
        </div>

        <div className="flex items-center gap-2">
          <button 
            onClick={markAllRead}
            disabled={notifications.length === 0 || unreadCount === 0}
            className="px-4 py-2 text-sm font-bold text-slate-600 bg-white border border-slate-200 rounded-lg hover:bg-slate-50 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center"
          >
            <Check className="w-4 h-4 mr-2" />
            Mark All Read
          </button>
        </div>
      </div>

      {loading ? (
        <div className="py-12 flex justify-center text-slate-400">
          <Loader2 className="w-8 h-8 animate-spin text-primary-500" />
        </div>
      ) : (
        <div className="space-y-4">
          <AnimatePresence>
            {notifications.map(notif => {
              const timeFormatted = new Date(notif.createdAt).toLocaleString();
              return (
                <motion.div 
                  key={notif.id}
                  initial={{ opacity: 0, x: -10 }}
                  animate={{ opacity: 1, x: 0 }}
                  exit={{ opacity: 0, scale: 0.95 }}
                  onClick={() => markAsRead(notif.id, notif.isRead)}
                  className={`card p-4 transition-all cursor-pointer ${
                    notif.isRead 
                      ? 'border-slate-100 opacity-80' 
                      : 'border-primary-200 shadow-md ring-1 ring-primary-100'
                  }`}
                >
                  <div className="flex gap-4">
                    <div className={`mt-1 p-2 rounded-full h-fit ${getBg(notif.type)}`}>
                      {getIcon(notif.type)}
                    </div>
                    <div className="flex-1">
                      <div className="flex justify-between items-start">
                        <h4 className={`font-bold ${notif.isRead ? 'text-slate-700' : 'text-slate-900'}`}>
                          {notif.title}
                        </h4>
                        <span className="text-xs font-semibold text-slate-400 whitespace-nowrap ml-4">
                          {timeFormatted}
                        </span>
                      </div>
                      <p className={`mt-1 text-sm ${notif.isRead ? 'text-slate-500' : 'text-slate-700 font-medium'}`}>
                        {notif.message}
                      </p>
                    </div>
                    {!notif.isRead && (
                      <div className="w-2.5 h-2.5 rounded-full bg-primary mt-2 flex-shrink-0"></div>
                    )}
                  </div>
                </motion.div>
              );
            })}
          </AnimatePresence>

          {notifications.length === 0 && (
            <div className="py-16 text-center text-slate-400">
              <Bell className="w-12 h-12 mx-auto mb-4 opacity-20" />
              <p className="font-semibold text-lg">You're all caught up!</p>
              <p className="text-sm mt-1">No new notifications right now.</p>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
