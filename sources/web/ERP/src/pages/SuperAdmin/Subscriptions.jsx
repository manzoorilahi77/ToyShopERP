import React from 'react';
import { CreditCard, Check, Zap, Building2, Server } from 'lucide-react';
import { motion } from 'framer-motion';

const SUBSCRIPTION_TIERS = [
  {
    id: 'starter',
    name: 'Starter Plan',
    price: '₹2,999',
    period: '/month',
    icon: Building2,
    color: 'text-blue-600',
    bg: 'bg-blue-50',
    borderColor: 'border-blue-200',
    features: ['Up to 2 Branches', '5 Staff Members', 'Basic Reports', 'Email Support'],
    activeTenants: 45
  },
  {
    id: 'growth',
    name: 'Growth Plan',
    price: '₹5,999',
    period: '/month',
    icon: Zap,
    color: 'text-primary-600',
    bg: 'bg-primary-50',
    borderColor: 'border-primary-200 ring-2 ring-primary-500/20',
    features: ['Up to 5 Branches', 'Unlimited Staff', 'Advanced Analytics', 'Priority 24/7 Support', 'Custom Domain'],
    activeTenants: 82,
    popular: true
  },
  {
    id: 'enterprise',
    name: 'Enterprise',
    price: 'Custom',
    period: '',
    icon: Server,
    color: 'text-slate-700',
    bg: 'bg-slate-100',
    borderColor: 'border-slate-300',
    features: ['Unlimited Branches', 'Dedicated Account Manager', 'Custom Integrations', 'SLA Guarantee', 'On-premise Option'],
    activeTenants: 15
  }
];

export default function Subscriptions() {
  return (
    <div className="max-w-7xl mx-auto pb-24">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-slate-900 font-heading">Subscriptions & Billing</h1>
        <p className="text-slate-500 mt-2">Manage pricing tiers and view subscription metrics across all tenants.</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-12">
        {SUBSCRIPTION_TIERS.map((tier, idx) => (
          <motion.div 
            key={tier.id}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: idx * 0.1 }}
            className={`bg-white rounded-3xl p-8 border ${tier.borderColor} shadow-sm relative overflow-hidden`}
          >
            {tier.popular && (
              <div className="absolute top-0 right-0 bg-primary-600 text-white text-[10px] font-bold uppercase tracking-wider px-3 py-1 rounded-bl-xl z-10">
                Most Popular
              </div>
            )}
            <div className="flex items-center gap-4 mb-6">
              <div className={`p-3 rounded-2xl ${tier.bg} ${tier.color}`}>
                <tier.icon className="w-7 h-7" />
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

            <div className="pt-6 border-t border-slate-100 flex items-center justify-between">
              <span className="text-sm font-medium text-slate-500">Active Tenants</span>
              <span className="text-lg font-bold text-slate-900">{tier.activeTenants}</span>
            </div>
          </motion.div>
        ))}
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
