import React, { useState } from 'react';
import { Terminal, Filter, RefreshCw, Download, ServerCrash, Zap, Database } from 'lucide-react';
import { motion } from 'framer-motion';

const MOCK_LOGS = [
  { id: 1, time: '2026-07-10 15:28:42', level: 'ERROR', service: 'auth-service', message: 'Failed to connect to redis cache cluster.' },
  { id: 2, time: '2026-07-10 15:28:40', level: 'INFO', service: 'api-gateway', message: 'Incoming request from 192.168.1.45 (Tenant: T004)' },
  { id: 3, time: '2026-07-10 15:27:15', level: 'WARN', service: 'db-writer', message: 'Query execution time exceeded 500ms on table `sales`' },
  { id: 4, time: '2026-07-10 15:25:00', level: 'INFO', service: 'sync-worker', message: 'Successfully synced 45 records for Tenant: T001' },
  { id: 5, time: '2026-07-10 15:24:12', level: 'INFO', service: 'api-gateway', message: 'User logged in: Admin (System)' },
  { id: 6, time: '2026-07-10 15:20:00', level: 'INFO', service: 'system', message: 'Automated health check passed.' },
];

export default function SystemLogs() {
  const [filter, setFilter] = useState('ALL');

  const getLevelColor = (level) => {
    switch(level) {
      case 'ERROR': return 'text-red-400 bg-red-400/10';
      case 'WARN': return 'text-amber-400 bg-amber-400/10';
      default: return 'text-emerald-400 bg-emerald-400/10';
    }
  };

  return (
    <div className="max-w-7xl mx-auto pb-24 h-full flex flex-col">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-6">
        <div>
          <h1 className="text-3xl font-bold text-white font-heading">System Logs</h1>
          <p className="text-slate-400 mt-2">Real-time application and server events.</p>
        </div>
        <div className="flex gap-2">
          <button className="p-2.5 text-slate-400 hover:text-white bg-slate-800 hover:bg-slate-700 rounded-xl transition-colors border border-slate-700">
            <RefreshCw className="w-5 h-5" />
          </button>
          <button className="p-2.5 text-slate-400 hover:text-white bg-slate-800 hover:bg-slate-700 rounded-xl transition-colors border border-slate-700">
            <Download className="w-5 h-5" />
          </button>
        </div>
      </div>

      <div className="flex-1 bg-slate-950 rounded-2xl border border-slate-800 shadow-2xl overflow-hidden flex flex-col">
        {/* Log Toolbar */}
        <div className="bg-slate-900 border-b border-slate-800 p-4 flex items-center justify-between">
          <div className="flex items-center gap-2 text-slate-400 text-sm font-mono">
            <Terminal className="w-4 h-4 text-primary-400" />
            <span>root@erp-production:~</span>
          </div>
          <div className="flex items-center gap-2">
            <Filter className="w-4 h-4 text-slate-500" />
            <select 
              value={filter}
              onChange={(e) => setFilter(e.target.value)}
              className="bg-slate-800 border border-slate-700 rounded text-xs text-slate-300 px-2 py-1 focus:outline-none"
            >
              <option value="ALL">ALL LEVELS</option>
              <option value="ERROR">ERROR</option>
              <option value="WARN">WARN</option>
              <option value="INFO">INFO</option>
            </select>
          </div>
        </div>

        {/* Log Window */}
        <div className="flex-1 overflow-y-auto p-4 font-mono text-sm space-y-2">
          {MOCK_LOGS.filter(l => filter === 'ALL' || l.level === filter).map((log, idx) => (
            <motion.div 
              key={log.id}
              initial={{ opacity: 0, x: -10 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ delay: idx * 0.05 }}
              className="flex gap-3 hover:bg-slate-900/50 p-1.5 rounded transition-colors"
            >
              <span className="text-slate-500 shrink-0">[{log.time}]</span>
              <span className={`shrink-0 font-bold px-1.5 rounded text-xs flex items-center ${getLevelColor(log.level)}`}>
                {log.level}
              </span>
              <span className="text-purple-400 shrink-0">[{log.service}]</span>
              <span className="text-slate-300 break-all">{log.message}</span>
            </motion.div>
          ))}
          <div className="animate-pulse flex gap-2 text-slate-600 p-1.5">
            <span>_</span>
          </div>
        </div>
      </div>
    </div>
  );
}
