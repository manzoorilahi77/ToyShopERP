import React, { useState, useEffect } from 'react';
import { Users, Plus, Shield, User, X, Power, PowerOff, Loader2 } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import toast from 'react-hot-toast';
import api from '../../services/api';

const ROLE_MAP = {
  'Super Admin': 1,
  'Owner': 2,
  'Manager': 3,
  'Staff': 4
};

export default function StaffManagement() {
  const [staff, setStaff] = useState([]);
  const [branches, setBranches] = useState([]);
  const [loading, setLoading] = useState(true);

  const [showModal, setShowModal] = useState(false);
  const [newName, setNewName] = useState('');
  const [newEmail, setNewEmail] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [newRole, setNewRole] = useState('Staff');
  const [newBranch, setNewBranch] = useState('');
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    try {
      setLoading(true);
      const [usersRes, branchesRes] = await Promise.all([
        api.get('/users'),
        api.get('/branches')
      ]);
      setStaff(usersRes.data?.data || []);
      
      const fetchedBranches = branchesRes.data?.data || [];
      setBranches(fetchedBranches);
      if (fetchedBranches.length > 0) {
        setNewBranch(fetchedBranches[0].id.toString());
      }
    } catch (error) {
      toast.error('Failed to fetch data');
    } finally {
      setLoading(false);
    }
  };

  const handleAdd = async () => {
    if (!newName.trim() || !newEmail.trim() || !newPassword.trim() || !newBranch) {
      toast.error('Please fill in all required fields');
      return;
    }

    const pinRegex = /^\d{4}$/;
    if (!pinRegex.test(newPassword)) {
      toast.error('Password must be exactly a 4-digit PIN');
      return;
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(newEmail)) {
      toast.error('Please enter a valid email address');
      return;
    }
    
    try {
      setSaving(true);
      await api.post('/users', {
        name: newName,
        email: newEmail,
        password: newPassword,
        roleId: ROLE_MAP[newRole],
        branchId: parseInt(newBranch, 10)
      });
      
      toast.success('Staff added successfully!');
      setNewName('');
      setNewEmail('');
      setNewPassword('');
      setNewRole('Staff');
      setShowModal(false);
      fetchData();
    } catch (error) {
      if (error.response?.data?.errors && error.response.data.errors.length > 0) {
        toast.error(error.response.data.errors[0].message);
      } else {
        toast.error(error.response?.data?.message || 'Failed to add staff');
      }
    } finally {
      setSaving(false);
    }
  };

  const toggleActive = async (id, currentStatus) => {
    try {
      await api.put(`/users/${id}`, { isActive: !currentStatus });
      toast.success(!currentStatus ? `Staff activated` : `Staff deactivated`);
      setStaff(prev => prev.map(s => s.id === id ? { ...s, isActive: !currentStatus } : s));
    } catch (error) {
      toast.error('Failed to update status');
    }
  };

  const getStaffColor = (id) => {
    const colors = ['bg-blue-500', 'bg-green-500', 'bg-purple-500', 'bg-orange-500', 'bg-teal-500'];
    return colors[id % colors.length];
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

      {loading ? (
        <div className="py-12 flex justify-center text-slate-400">
          <Loader2 className="w-8 h-8 animate-spin text-primary-500" />
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <AnimatePresence>
            {staff.map(member => {
              const roleName = member.role?.name || 'Staff';
              return (
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
                      !member.isActive ? 'bg-slate-300' : getStaffColor(member.id)
                    }`}>
                      {member.name ? member.name.charAt(0).toUpperCase() : 'U'}
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
                      <p className="text-sm flex items-center mt-1 font-semibold" style={{ color: roleName === 'Owner' || roleName === 'Super Admin' ? '#D97706' : roleName === 'Manager' ? '#7C3AED' : '#64748B' }}>
                        {roleName === 'Owner' || roleName === 'Manager' || roleName === 'Super Admin' ? (
                          <Shield className="w-4 h-4 mr-1" />
                        ) : (
                          <User className="w-4 h-4 mr-1" />
                        )}
                        {roleName}
                      </p>
                    </div>
                  </div>
                  <button 
                    onClick={() => toggleActive(member.id, member.isActive)}
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
              );
            })}
          </AnimatePresence>
          {staff.length === 0 && (
            <div className="col-span-2 py-12 text-center text-slate-400 border-2 border-dashed border-slate-200 rounded-2xl">
              <Users className="w-12 h-12 mx-auto mb-3 opacity-20" />
              <p>No staff found.</p>
            </div>
          )}
        </div>
      )}

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
              className="card border-0 shadow-2xl w-full max-w-md overflow-hidden max-h-[90vh] flex flex-col"
            >
              <div className="p-6 border-b border-slate-100 flex items-center justify-between shrink-0">
                <h2 className="text-2xl font-bold text-slate-800 font-heading">Add Staff Member</h2>
                <button onClick={() => setShowModal(false)} className="p-2 text-slate-400 hover:bg-slate-100 rounded-full transition-colors">
                  <X className="w-5 h-5" />
                </button>
              </div>
              
              <div className="p-6 space-y-4 overflow-y-auto">
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
                  <label className="block text-sm font-semibold text-slate-700 mb-1">Email</label>
                  <input 
                    type="email" 
                    placeholder="john@example.com"
                    className="input-field w-full"
                    value={newEmail}
                    onChange={(e) => setNewEmail(e.target.value)}
                  />
                </div>
                <div>
                  <label className="block text-sm font-semibold text-slate-700 mb-1">Password</label>
                  <input 
                    type="password" 
                    placeholder="Temp Password"
                    className="input-field w-full"
                    value={newPassword}
                    onChange={(e) => setNewPassword(e.target.value)}
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
                    <option>Super Admin</option>
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-semibold text-slate-700 mb-1">Branch</label>
                  <select 
                    value={newBranch}
                    onChange={(e) => setNewBranch(e.target.value)}
                    className="input-field w-full appearance-none"
                  >
                    {branches.map(b => (
                      <option key={b.id} value={b.id}>{b.name}</option>
                    ))}
                  </select>
                </div>
              </div>

              <div className="p-4 bg-slate-50 border-t border-slate-100 flex gap-2 justify-end shrink-0">
                <button onClick={() => setShowModal(false)} className="px-6 py-2.5 rounded-xl font-bold text-slate-600 hover:bg-slate-200 transition-colors">
                  Cancel
                </button>
                <button 
                  onClick={handleAdd} 
                  disabled={saving}
                  className="btn-primary px-6 py-2.5 flex items-center"
                >
                  {saving ? <Loader2 className="w-4 h-4 mr-2 animate-spin" /> : null}
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
