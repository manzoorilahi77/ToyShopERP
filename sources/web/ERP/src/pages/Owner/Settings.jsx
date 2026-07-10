import React, { useState } from 'react';
import { Settings as SettingsIcon, Bell, Shield, Moon, Monitor, Smartphone, Save } from 'lucide-react';
import toast from 'react-hot-toast';

export default function Settings() {
  const [settings, setSettings] = useState({
    pushNotifs: true,
    emailNotifs: false,
    darkMode: false,
    twoFactor: true,
  });

  const [saving, setSaving] = useState(false);

  const toggle = (key) => {
    setSettings(prev => ({ ...prev, [key]: !prev[key] }));
  };

  const handleSave = async () => {
    setSaving(true);
    await new Promise(r => setTimeout(r, 800));
    toast.success('Settings saved successfully');
    setSaving(false);
  };

  return (
    <div className="max-w-3xl mx-auto pb-24">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-slate-800 font-heading">Settings</h1>
        <p className="text-slate-500 mt-2">Manage your app and shop preferences.</p>
      </div>

      <div className="space-y-6">
        
        {/* Notifications */}
        <div className="card p-6">
          <div className="flex items-center gap-3 mb-6">
            <div className="p-2 bg-blue-50 text-blue-600 rounded-lg">
              <Bell className="w-5 h-5" />
            </div>
            <h2 className="text-lg font-bold text-slate-800 font-heading">Notifications</h2>
          </div>
          
          <div className="space-y-4">
            <div className="flex items-center justify-between py-2">
              <div>
                <p className="font-semibold text-slate-800">Push Notifications</p>
                <p className="text-sm text-slate-500">Receive alerts on this device</p>
              </div>
              <button 
                onClick={() => toggle('pushNotifs')}
                className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2 ${settings.pushNotifs ? 'bg-primary' : 'bg-slate-200'}`}
              >
                <span className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${settings.pushNotifs ? 'translate-x-6' : 'translate-x-1'}`} />
              </button>
            </div>
            
            <div className="flex items-center justify-between py-2 border-t border-slate-100">
              <div>
                <p className="font-semibold text-slate-800">Email Notifications</p>
                <p className="text-sm text-slate-500">Daily reports and critical alerts</p>
              </div>
              <button 
                onClick={() => toggle('emailNotifs')}
                className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2 ${settings.emailNotifs ? 'bg-primary' : 'bg-slate-200'}`}
              >
                <span className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${settings.emailNotifs ? 'translate-x-6' : 'translate-x-1'}`} />
              </button>
            </div>
          </div>
        </div>

        {/* Appearance */}
        <div className="card p-6">
          <div className="flex items-center gap-3 mb-6">
            <div className="p-2 bg-purple-50 text-purple-600 rounded-lg">
              <Monitor className="w-5 h-5" />
            </div>
            <h2 className="text-lg font-bold text-slate-800 font-heading">Appearance</h2>
          </div>
          
          <div className="flex items-center justify-between py-2">
            <div className="flex items-center gap-3">
              <Moon className="w-5 h-5 text-slate-400" />
              <div>
                <p className="font-semibold text-slate-800">Dark Mode</p>
                <p className="text-sm text-slate-500">Easier on the eyes (coming soon)</p>
              </div>
            </div>
            <button 
              onClick={() => toggle('darkMode')}
              disabled
              className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors opacity-50 cursor-not-allowed ${settings.darkMode ? 'bg-primary' : 'bg-slate-200'}`}
            >
              <span className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${settings.darkMode ? 'translate-x-6' : 'translate-x-1'}`} />
            </button>
          </div>
        </div>

        {/* Security */}
        <div className="card p-6">
          <div className="flex items-center gap-3 mb-6">
            <div className="p-2 bg-emerald-50 text-emerald-600 rounded-lg">
              <Shield className="w-5 h-5" />
            </div>
            <h2 className="text-lg font-bold text-slate-800 font-heading">Security</h2>
          </div>
          
          <div className="flex items-center justify-between py-2">
            <div className="flex items-center gap-3">
              <Smartphone className="w-5 h-5 text-slate-400" />
              <div>
                <p className="font-semibold text-slate-800">Two-Factor Authentication</p>
                <p className="text-sm text-slate-500">Require OTP for login</p>
              </div>
            </div>
            <button 
              onClick={() => toggle('twoFactor')}
              className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2 ${settings.twoFactor ? 'bg-primary' : 'bg-slate-200'}`}
            >
              <span className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${settings.twoFactor ? 'translate-x-6' : 'translate-x-1'}`} />
            </button>
          </div>
        </div>

        {/* Save Button */}
        <div className="pt-4 flex justify-end">
          <button 
            onClick={handleSave}
            disabled={saving}
            className="btn-primary px-8 py-3 font-bold text-lg flex items-center shadow-lg shadow-primary/30"
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
                Save Changes
              </>
            )}
          </button>
        </div>

      </div>
    </div>
  );
}
