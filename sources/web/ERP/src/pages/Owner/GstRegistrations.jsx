import React, { useState, useEffect } from 'react';
import { FileText, Building2, CheckCircle2, Clock, AlertCircle, Plus, X, Trash2, Loader2 } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import toast from 'react-hot-toast';
import api from '../../services/api';

export default function GstRegistrations() {
  const [registrations, setRegistrations] = useState([]);
  const [branches, setBranches] = useState([]);
  const [loading, setLoading] = useState(true);
  
  const [showModal, setShowModal] = useState(false);
  const [gstNumber, setGstNumber] = useState('');
  const [businessName, setBusinessName] = useState('');
  const [state, setState] = useState('');
  const [branchId, setBranchId] = useState('');
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    try {
      setLoading(true);
      const [gstRes, branchesRes] = await Promise.all([
        api.get('/gst-registrations'),
        api.get('/branches')
      ]);
      setRegistrations(gstRes.data?.data || []);
      
      const fetchedBranches = branchesRes.data?.data || [];
      setBranches(fetchedBranches);
      if (fetchedBranches.length > 0) {
        setBranchId(fetchedBranches[0].id.toString());
      }
    } catch (error) {
      toast.error('Failed to fetch data');
    } finally {
      setLoading(false);
    }
  };

  const handleAdd = async () => {
    if (!gstNumber.trim() || !businessName.trim() || !branchId) {
      toast.error('GSTIN, Business Name, and Branch are required');
      return;
    }
    
    try {
      setSaving(true);
      await api.post('/gst-registrations', {
        gstNumber,
        businessName,
        state,
        branchId: parseInt(branchId, 10)
      });
      
      toast.success('GST Registration added successfully!');
      setGstNumber('');
      setBusinessName('');
      setState('');
      setShowModal(false);
      fetchData();
    } catch (error) {
      toast.error(error.response?.data?.message || 'Failed to add registration');
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (id) => {
    if (!window.confirm('Are you sure you want to delete this GST registration?')) return;
    try {
      await api.delete(`/gst-registrations/${id}`);
      setRegistrations(prev => prev.filter(r => r.id !== id));
      toast.success('GST Registration deleted');
    } catch (error) {
      toast.error('Failed to delete registration');
    }
  };

  const getStatusConfig = (status) => {
    // In our backend, we don't have a status field yet. We will mock status based on creation or just say Filed.
    status = status || 'Filed';
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
        <button 
          onClick={() => setShowModal(true)}
          className="btn-primary inline-flex items-center self-start"
        >
          <Plus className="w-5 h-5 mr-2" />
          Add Registration
        </button>
      </div>

      {loading ? (
        <div className="py-12 flex justify-center text-slate-400">
          <Loader2 className="w-8 h-8 animate-spin text-primary-500" />
        </div>
      ) : (
        <div className="space-y-6">
          <AnimatePresence>
            {registrations.map(reg => {
              const statusConfig = getStatusConfig(reg.status);
              const StatusIcon = statusConfig.icon;
              const branchName = reg.branch?.name || 'Unknown Branch';
              const lastFiled = new Date(reg.createdAt).toLocaleDateString();

              return (
                <motion.div 
                  key={reg.id}
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, scale: 0.95 }}
                  className={`card p-6 border-l-4 ${statusConfig.border} transition-shadow hover:shadow-md relative group`}
                >
                  <div className="flex flex-col md:flex-row md:items-start justify-between gap-4">
                    <div className="flex items-start gap-4">
                      <div className={`p-3 rounded-xl ${statusConfig.bg} ${statusConfig.color}`}>
                        <Building2 className="w-6 h-6" />
                      </div>
                      <div>
                        <h3 className="font-bold text-slate-800 text-lg flex items-center gap-2">
                          {branchName}
                          <span className={`text-[10px] font-bold uppercase tracking-wider px-2.5 py-1 rounded-full ${statusConfig.bg} ${statusConfig.color} flex items-center`}>
                            <StatusIcon className="w-3 h-3 mr-1" />
                            {reg.status || 'Filed'}
                          </span>
                        </h3>
                        <p className="text-slate-500 text-sm mt-1">{reg.businessName}</p>
                        
                        <div className="mt-4 inline-flex items-center gap-2 px-3 py-1.5 bg-slate-100 rounded-lg border border-slate-200">
                          <span className="text-xs font-semibold text-slate-500 uppercase tracking-wide">GSTIN</span>
                          <span className="font-mono font-bold text-slate-800">{reg.gstNumber}</span>
                        </div>
                      </div>
                    </div>

                    <div className="text-right">
                      <p className="text-sm font-semibold text-slate-500 mb-1">Created At</p>
                      <p className="font-bold text-slate-800">{lastFiled}</p>
                    </div>
                  </div>
                  <button 
                    onClick={() => handleDelete(reg.id)}
                    className="absolute top-4 right-4 p-2 text-slate-300 hover:text-red-500 hover:bg-red-50 rounded-lg transition-colors opacity-0 group-hover:opacity-100 focus:opacity-100"
                    title="Remove Registration"
                  >
                    <Trash2 className="w-5 h-5" />
                  </button>
                </motion.div>
              );
            })}
          </AnimatePresence>
          {registrations.length === 0 && (
            <div className="py-12 text-center text-slate-400 border-2 border-dashed border-slate-200 rounded-2xl">
              <FileText className="w-12 h-12 mx-auto mb-3 opacity-20" />
              <p>No GST registrations found.</p>
            </div>
          )}
        </div>
      )}

      {/* Add GST Modal */}
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
                <h2 className="text-2xl font-bold text-slate-800 font-heading">Add GST Registration</h2>
                <button onClick={() => setShowModal(false)} className="p-2 text-slate-400 hover:bg-slate-100 rounded-full transition-colors">
                  <X className="w-5 h-5" />
                </button>
              </div>
              
              <div className="p-6 space-y-4 overflow-y-auto">
                <div>
                  <label className="block text-sm font-semibold text-slate-700 mb-1">Business Name</label>
                  <input 
                    type="text" 
                    placeholder="e.g. Toy Shop Pvt Ltd"
                    className="input-field w-full"
                    value={businessName}
                    onChange={(e) => setBusinessName(e.target.value)}
                  />
                </div>
                <div>
                  <label className="block text-sm font-semibold text-slate-700 mb-1">GSTIN Number</label>
                  <input 
                    type="text" 
                    placeholder="e.g. 29ABCDE1234F2Z5"
                    className="input-field w-full font-mono"
                    value={gstNumber}
                    onChange={(e) => setGstNumber(e.target.value)}
                  />
                </div>
                <div>
                  <label className="block text-sm font-semibold text-slate-700 mb-1">State (Optional)</label>
                  <input 
                    type="text" 
                    placeholder="e.g. Karnataka"
                    className="input-field w-full"
                    value={state}
                    onChange={(e) => setState(e.target.value)}
                  />
                </div>
                <div>
                  <label className="block text-sm font-semibold text-slate-700 mb-1">Branch</label>
                  <select 
                    value={branchId}
                    onChange={(e) => setBranchId(e.target.value)}
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
                  Save Registration
                </button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
