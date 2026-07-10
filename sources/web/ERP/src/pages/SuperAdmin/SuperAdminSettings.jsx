import React, { useState } from 'react';
import { Save, Server, Shield, Database, Mail } from 'lucide-react';
import toast from 'react-hot-toast';

export default function SuperAdminSettings() {
  const [saving, setSaving] = useState(false);

  const handleSave = async () => {
    setSaving(true);
    await new Promise(r => setTimeout(r, 800));
    toast.success('Global settings updated');
    setSaving(false);
  };

  return (
    <div className="max-w-4xl mx-auto pb-24">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-white font-heading">Global Settings</h1>
        <p className="text-slate-400 mt-2">Configure system-wide parameters for the ERP.</p>
      </div>

      <div className="space-y-6">
        
        {/* Maintenance Mode */}
        <div className="bg-slate-800 rounded-2xl p-6 border border-slate-700/50 shadow-lg">
          <div className="flex items-center gap-3 mb-6">
            <div className="p-2 bg-amber-500/20 text-amber-400 rounded-lg">
              <Server className="w-5 h-5" />
            </div>
            <h2 className="text-lg font-bold text-white font-heading">System Status</h2>
          </div>
          
          <div className="flex items-center justify-between py-2">
            <div>
              <p className="font-semibold text-slate-200">Maintenance Mode</p>
              <p className="text-sm text-slate-400">Suspend access for all tenants (except Super Admin)</p>
            </div>
            <button className="relative inline-flex h-6 w-11 items-center rounded-full transition-colors focus:outline-none bg-slate-700">
              <span className="inline-block h-4 w-4 transform rounded-full bg-slate-400 transition-transform translate-x-1" />
            </button>
          </div>
        </div>

        {/* Security */}
        <div className="bg-slate-800 rounded-2xl p-6 border border-slate-700/50 shadow-lg">
          <div className="flex items-center gap-3 mb-6">
            <div className="p-2 bg-emerald-500/20 text-emerald-400 rounded-lg">
              <Shield className="w-5 h-5" />
            </div>
            <h2 className="text-lg font-bold text-white font-heading">Global Security</h2>
          </div>
          
          <div className="space-y-4">
            <div className="flex items-center justify-between py-2">
              <div>
                <p className="font-semibold text-slate-200">Force 2FA</p>
                <p className="text-sm text-slate-400">Require Two-Factor Auth for all Owner accounts</p>
              </div>
              <button className="relative inline-flex h-6 w-11 items-center rounded-full transition-colors focus:outline-none bg-primary-500">
                <span className="inline-block h-4 w-4 transform rounded-full bg-white transition-transform translate-x-6" />
              </button>
            </div>
            <div className="flex items-center justify-between py-2 border-t border-slate-700">
              <div>
                <p className="font-semibold text-slate-200">Session Timeout</p>
                <p className="text-sm text-slate-400">Auto-logout idle users</p>
              </div>
              <select className="bg-slate-900 border border-slate-700 rounded-lg px-3 py-1.5 text-slate-300 focus:outline-none focus:border-primary-500">
                <option>15 Minutes</option>
                <option>30 Minutes</option>
                <option>1 Hour</option>
                <option>4 Hours</option>
              </select>
            </div>
          </div>
        </div>
        
        {/* Backups */}
        <div className="bg-slate-800 rounded-2xl p-6 border border-slate-700/50 shadow-lg">
          <div className="flex items-center gap-3 mb-6">
            <div className="p-2 bg-blue-500/20 text-blue-400 rounded-lg">
              <Database className="w-5 h-5" />
            </div>
            <h2 className="text-lg font-bold text-white font-heading">Data & Backups</h2>
          </div>
          
          <div className="flex items-center justify-between py-2">
            <div>
              <p className="font-semibold text-slate-200">Automated Daily Backups</p>
              <p className="text-sm text-slate-400">Sync all tenant data to cold storage</p>
            </div>
            <button className="relative inline-flex h-6 w-11 items-center rounded-full transition-colors focus:outline-none bg-primary-500">
              <span className="inline-block h-4 w-4 transform rounded-full bg-white transition-transform translate-x-6" />
            </button>
          </div>
        </div>

        {/* Save Button */}
        <div className="pt-4 flex justify-end">
          <button 
            onClick={handleSave}
            disabled={saving}
            className="bg-primary-500 hover:bg-primary-400 text-white px-8 py-3 rounded-xl font-bold text-lg flex items-center shadow-lg shadow-primary-500/20 transition-colors"
          >
            {saving ? (
              <span className="flex items-center">
                <svg className="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
                Saving...
              </span>
            ) : (
              <>
                <Save className="w-5 h-5 mr-2" />
                Save Configuration
              </>
            )}
          </button>
        </div>

      </div>
    </div>
  );
}
