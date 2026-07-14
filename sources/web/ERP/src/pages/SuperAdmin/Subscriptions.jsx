import React, { useState, useEffect } from 'react';
import { CreditCard, Check, Zap, Building2, Server, Loader2 } from 'lucide-react';
import { motion } from 'framer-motion';
import api from '../../services/api';

const ICON_MAP = {
  Building2,
  Zap,
  Server
};

export default function Subscriptions() {
  const [subscriptions, setSubscriptions] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchSubscriptions();
  }, []);

  const fetchSubscriptions = async () => {
    try {
      setLoading(true);
      const response = await api.get('/superadmin/subscriptions');
      if (response.data.success) {
        setSubscriptions(response.data.data);
      }
    } catch (error) {
      console.error('Failed to fetch subscriptions:', error);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return <div className="p-8 text-center text-slate-500">Loading subscriptions...</div>;
  }

  return (
    <div className="max-w-7xl mx-auto pb-24">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-slate-900 font-heading">Subscriptions & Billing</h1>
        <p className="text-slate-500 mt-2">Manage pricing tiers and view subscription metrics across all tenants.</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-12">
        {subscriptions.map((tier, idx) => {
          const IconComponent = ICON_MAP[tier.iconName] || Server;
          return (
            <motion.div 
              key={tier.id}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: idx * 0.1 }}
              className={`bg-white rounded-3xl p-8 border ${tier.borderColor} shadow-sm relative overflow-hidden flex flex-col`}
            >
              {tier.popular && (
                <div className="absolute top-0 right-0 bg-primary-600 text-white text-[10px] font-bold uppercase tracking-wider px-3 py-1 rounded-bl-xl z-10">
                  Most Popular
                </div>
              )}
              <div className="flex items-center gap-4 mb-6">
                <div className={`p-3 rounded-2xl ${tier.bg} ${tier.color}`}>
                  <IconComponent className="w-7 h-7" />
                </div>
                <div>
                  <h3 className="text-lg font-bold text-slate-900 font-heading">{tier.name}</h3>
                  <div className="flex items-baseline gap-1 mt-1">
                    <span className="text-2xl font-bold text-slate-900">{tier.price}</span>
                    <span className="text-sm font-medium text-slate-500">{tier.period}</span>
                  </div>
                </div>
              </div>
              
              <div className="space-y-3 mb-8 flex-1">
                {tier.features.map((feature, i) => (
                  <div key={i} className="flex items-start gap-3 text-sm text-slate-600">
                    <div className="mt-0.5 w-4 h-4 rounded-full bg-emerald-50 flex items-center justify-center flex-shrink-0">
                      <Check className="w-3 h-3 text-emerald-500" />
                    </div>
                    {feature}
                  </div>
                ))}
              </div>

              <div className="pt-6 border-t border-slate-100 flex items-center justify-between mt-auto">
                <span className="text-sm font-medium text-slate-500">Active Tenants</span>
                <span className="text-lg font-bold text-slate-900">{tier.activeTenants}</span>
              </div>
            </motion.div>
          );
        })}
      </div>

      <div className="bg-white rounded-2xl border border-slate-200 shadow-sm p-6">
        <h2 className="text-lg font-bold text-slate-900 font-heading mb-6 flex items-center gap-2">
          <CreditCard className="w-5 h-5 text-primary-600" /> Recent Billing Activity
        </h2>
        <div className="text-center py-12 text-slate-500">
          <CreditCard className="w-12 h-12 text-slate-200 mx-auto mb-3" />
          <p className="font-medium">No recent billing issues.</p>
          <p className="text-sm mt-1">All tenants are up to date on their payments.</p>
        </div>
      </div>
    </div>
  );
}
