import React, { useState } from 'react';
import { FileText, Building2, CheckCircle2, Clock, AlertCircle } from 'lucide-react';
import { motion } from 'framer-motion';

export default function GstRegistrations() {
  const [registrations] = useState([
    { 
      id: 'g1', 
      branch: 'Main Branch', 
      gstin: '29ABCDE1234F2Z5', 
      status: 'Filed', 
      lastFiled: 'Jun 2026',
      legalName: 'Toy Shop ERP Pvt Ltd'
    },
    { 
      id: 'g2', 
      branch: 'Downtown Branch', 
      gstin: '29ABCDE1234F2Z6', 
      status: 'Pending', 
      lastFiled: 'May 2026',
      legalName: 'Toy Shop ERP Pvt Ltd'
    },
    { 
      id: 'g3', 
      branch: 'Mall Kiosk', 
      gstin: '29ABCDE1234F2Z7', 
      status: 'Overdue', 
      lastFiled: 'Apr 2026',
      legalName: 'Toy Shop Kiosks Ltd'
    },
  ]);

  const getStatusConfig = (status) => {
    switch(status) {
      case 'Filed':
        return { icon: CheckCircle2, color: 'text-emerald-600', bg: 'bg-emerald-50', border: 'border-emerald-200' };
      case 'Pending':
        return { icon: Clock, color: 'text-amber-600', bg: 'bg-amber-50', border: 'border-amber-200' };
      case 'Overdue':
        return { icon: AlertCircle, color: 'text-red-600', bg: 'bg-red-50', border: 'border-red-200' };
      default:
        return { icon: FileText, color: 'text-slate-600', bg: 'bg-slate-50', border: 'border-slate-200' };
    }
  };

  return (
    <div className="max-w-4xl mx-auto pb-24">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-8">
        <div>
          <h1 className="text-3xl font-bold text-slate-800 font-heading">GST Registrations</h1>
          <p className="text-slate-500 mt-2">Manage GSTIN numbers and filing status for all branches.</p>
        </div>
      </div>

      <div className="space-y-6">
        {registrations.map(reg => {
          const statusConfig = getStatusConfig(reg.status);
          const StatusIcon = statusConfig.icon;

          return (
            <motion.div 
              key={reg.id}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              className={`card p-6 border-l-4 ${statusConfig.border} transition-shadow hover:shadow-md`}
            >
              <div className="flex flex-col md:flex-row md:items-start justify-between gap-4">
                <div className="flex items-start gap-4">
                  <div className={`p-3 rounded-xl ${statusConfig.bg} ${statusConfig.color}`}>
                    <Building2 className="w-6 h-6" />
                  </div>
                  <div>
                    <h3 className="font-bold text-slate-800 text-lg flex items-center gap-2">
                      {reg.branch}
                      <span className={`text-[10px] font-bold uppercase tracking-wider px-2.5 py-1 rounded-full ${statusConfig.bg} ${statusConfig.color} flex items-center`}>
                        <StatusIcon className="w-3 h-3 mr-1" />
                        {reg.status}
                      </span>
                    </h3>
                    <p className="text-slate-500 text-sm mt-1">{reg.legalName}</p>
                    
                    <div className="mt-4 inline-flex items-center gap-2 px-3 py-1.5 bg-slate-100 rounded-lg border border-slate-200">
                      <span className="text-xs font-semibold text-slate-500 uppercase tracking-wide">GSTIN</span>
                      <span className="font-mono font-bold text-slate-800">{reg.gstin}</span>
                    </div>
                  </div>
                </div>

                <div className="text-right">
                  <p className="text-sm font-semibold text-slate-500 mb-1">Last Filed</p>
                  <p className="font-bold text-slate-800">{reg.lastFiled}</p>
                </div>
              </div>
            </motion.div>
          );
        })}
      </div>
    </div>
  );
}
