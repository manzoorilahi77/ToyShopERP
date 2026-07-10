import React, { useState } from 'react';
import { Users, Plus, Shield, User, X, Power, PowerOff } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import toast from 'react-hot-toast';

export default function StaffManagement() {
  const [staff, setStaff] = useState([
    { id: 's1', name: 'Rahul Sharma', role: 'Staff', isActive: true, initial: 'R', color: 'bg-blue-500' },
    { id: 's2', name: 'Priya Mehta', role: 'Staff', isActive: true, initial: 'P', color: 'bg-green-500' },
    { id: 's3', name: 'Amit Kumar', role: 'Manager', isActive: false, initial: 'A', color: 'bg-purple-500' },
    { id: 's4', name: 'Neha Singh', role: 'Owner', isActive: true, initial: 'N', color: 'bg-orange-500' },
  ]);

  const [showModal, setShowModal] = useState(false);
  const [newName, setNewName] = useState('');
  const [newRole, setNewRole] = useState('Staff');

  const handleAdd = () => {
    if (!newName.trim()) {
      toast.error('Please enter a name');
      return;
    }
    
    setStaff(prev => [
      ...prev, 
      { 
        id: `s${Date.now()}`, 
        name: newName, 
        role: newRole, 
        isActive: true, 
        initial: newName.charAt(0).toUpperCase(),
        color: 'bg-teal-500'
      }
    ]);
    
    toast.success('Staff added successfully!');
    setNewName('');
    setNewRole('Staff');
    setShowModal(false);
  };

  const toggleActive = (id) => {
    setStaff(prev => prev.map(s => {
      if (s.id === id) {
        const nextState = !s.isActive;
        toast.success(nextState ? `${s.name} activated` : `${s.name} deactivated`);
        return { ...s, isActive: nextState };
      }
      return s;
    }));
  };

  return (
    <div className="max-w-4xl mx-auto pb-24">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-8">
        <div>
          <h1 className="text-3xl font-bold text-slate-800 font-heading">Staff Management</h1>
          <p className="text-slate-500 mt-2">Manage your team and their roles.</p>
        </div>
        <button 
          onClick={() => setShowModal(true)}
          className="btn-primary inline-flex items-center self-start"
        >
          <Plus className="w-5 h-5 mr-2" />
          Add Staff
        </button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <AnimatePresence>
          {staff.map(member => (
            <motion.div 
              key={member.id}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.95 }}
              className={`card p-4 flex items-center justify-between group transition-all ${
                !member.isActive ? 'opacity-60 bg-slate-50' : 'hover:shadow-md'
              }`}
            >
              <div className="flex items-center gap-4">
                <div className={`w-12 h-12 rounded-full flex items-center justify-center text-white font-bold text-lg shadow-sm ${
                  !member.isActive ? 'bg-slate-300' : member.color
                }`}>
                  {member.initial}
                </div>
                <div>
                  <h3 className="font-bold text-slate-800 text-lg flex items-center">
                    {member.name}
                    {!member.isActive && (
                      <span className="ml-2 text-[10px] font-bold uppercase tracking-wider bg-slate-200 text-slate-600 px-2 py-0.5 rounded-full">
                        Inactive
                      </span>
                    )}
                  </h3>
                  <p className="text-sm flex items-center mt-1 font-semibold" style={{ color: member.role === 'Owner' ? '#D97706' : member.role === 'Manager' ? '#7C3AED' : '#64748B' }}>
                    {member.role === 'Owner' || member.role === 'Manager' ? (
                      <Shield className="w-4 h-4 mr-1" />
                    ) : (
                      <User className="w-4 h-4 mr-1" />
                    )}
                    {member.role}
                  </p>
                </div>
              </div>
              <button 
                onClick={() => toggleActive(member.id)}
                className={`p-2 rounded-lg transition-colors opacity-0 group-hover:opacity-100 focus:opacity-100 ${
                  member.isActive 
                    ? 'text-slate-400 hover:text-red-500 hover:bg-red-50' 
                    : 'text-slate-400 hover:text-green-500 hover:bg-green-50'
                }`}
                title={member.isActive ? "Deactivate Staff" : "Activate Staff"}
              >
                {member.isActive ? <PowerOff className="w-5 h-5" /> : <Power className="w-5 h-5" />}
              </button>
            </motion.div>
          ))}
        </AnimatePresence>
      </div>

      {/* Add Staff Modal */}
      <AnimatePresence>
        {showModal && (
          <motion.div 
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/40 backdrop-blur-sm"
          >
            <motion.div 
              initial={{ scale: 0.95, y: 20 }}
              animate={{ scale: 1, y: 0 }}
              exit={{ scale: 0.95, y: 20 }}
              className="bg-white rounded-3xl shadow-xl w-full max-w-md overflow-hidden"
            >
              <div className="p-6 border-b border-slate-100 flex items-center justify-between">
                <h2 className="text-2xl font-bold text-slate-800 font-heading">Add Staff Member</h2>
                <button onClick={() => setShowModal(false)} className="p-2 text-slate-400 hover:bg-slate-100 rounded-full transition-colors">
                  <X className="w-5 h-5" />
                </button>
              </div>
              
              <div className="p-6 space-y-4">
                <div>
                  <label className="block text-sm font-semibold text-slate-700 mb-1">Full Name</label>
                  <input 
                    type="text" 
                    placeholder="e.g. John Doe"
                    className="input-field w-full"
                    value={newName}
                    onChange={(e) => setNewName(e.target.value)}
                  />
                </div>
                <div>
                  <label className="block text-sm font-semibold text-slate-700 mb-1">Role</label>
                  <select 
                    value={newRole}
                    onChange={(e) => setNewRole(e.target.value)}
                    className="input-field w-full appearance-none"
                  >
                    <option>Staff</option>
                    <option>Manager</option>
                    <option>Owner</option>
                  </select>
                </div>
              </div>

              <div className="p-4 bg-slate-50 border-t border-slate-100 flex gap-2 justify-end">
                <button onClick={() => setShowModal(false)} className="px-6 py-2.5 rounded-xl font-bold text-slate-600 hover:bg-slate-200 transition-colors">
                  Cancel
                </button>
                <button onClick={handleAdd} className="btn-primary px-6 py-2.5">
                  Save Staff
                </button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
