import React, { useState } from 'react';
import { Store, Plus, MapPin, Trash2, X } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import toast from 'react-hot-toast';

export default function BranchesManagement() {
  const [branches, setBranches] = useState([
    { id: 'b1', name: 'Main Branch', location: 'City Center' },
    { id: 'b2', name: 'Downtown Branch', location: 'Downtown' },
    { id: 'b3', name: 'Mall Kiosk', location: 'Westend Mall' },
  ]);

  const [showModal, setShowModal] = useState(false);
  const [newName, setNewName] = useState('');
  const [newLocation, setNewLocation] = useState('');

  const handleAdd = () => {
    if (!newName.trim() || !newLocation.trim()) {
      toast.error('Please enter name and location');
      return;
    }
    
    setBranches(prev => [
      ...prev, 
      { id: `b${Date.now()}`, name: newName, location: newLocation }
    ]);
    
    toast.success('Branch added successfully!');
    setNewName('');
    setNewLocation('');
    setShowModal(false);
  };

  const handleDelete = (id) => {
    setBranches(prev => prev.filter(b => b.id !== id));
    toast.success('Branch removed');
  };

  return (
    <div className="max-w-4xl mx-auto pb-24">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-8">
        <div>
          <h1 className="text-3xl font-bold text-slate-800 font-heading">Branches Management</h1>
          <p className="text-slate-500 mt-2">Manage all your store locations.</p>
        </div>
        <button 
          onClick={() => setShowModal(true)}
          className="btn-primary inline-flex items-center self-start"
        >
          <Plus className="w-5 h-5 mr-2" />
          Add Branch
        </button>
      </div>

      <div className="space-y-4">
        <AnimatePresence>
          {branches.map(branch => (
            <motion.div 
              key={branch.id}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.95 }}
              className="card p-4 flex items-center justify-between group transition-shadow hover:shadow-md"
            >
              <div className="flex items-center gap-4">
                <div className="w-12 h-12 bg-blue-50 text-blue-600 rounded-xl flex items-center justify-center">
                  <Store className="w-6 h-6" />
                </div>
                <div>
                  <h3 className="font-bold text-slate-800 text-lg">{branch.name}</h3>
                  <p className="text-slate-500 text-sm flex items-center mt-1">
                    <MapPin className="w-4 h-4 mr-1 text-slate-400" />
                    {branch.location}
                  </p>
                </div>
              </div>
              <button 
                onClick={() => handleDelete(branch.id)}
                className="p-2 text-slate-300 hover:text-red-500 hover:bg-red-50 rounded-lg transition-colors opacity-0 group-hover:opacity-100 focus:opacity-100"
                title="Remove Branch"
              >
                <Trash2 className="w-5 h-5" />
              </button>
            </motion.div>
          ))}
        </AnimatePresence>
        
        {branches.length === 0 && (
          <div className="py-12 text-center text-slate-400 border-2 border-dashed border-slate-200 rounded-2xl">
            <Store className="w-12 h-12 mx-auto mb-3 opacity-20" />
            <p>No branches found. Add your first branch!</p>
          </div>
        )}
      </div>

      {/* Add Branch Modal */}
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
                <h2 className="text-2xl font-bold text-slate-800 font-heading">Add Branch</h2>
                <button onClick={() => setShowModal(false)} className="p-2 text-slate-400 hover:bg-slate-100 rounded-full transition-colors">
                  <X className="w-5 h-5" />
                </button>
              </div>
              
              <div className="p-6 space-y-4">
                <div>
                  <label className="block text-sm font-semibold text-slate-700 mb-1">Branch Name</label>
                  <input 
                    type="text" 
                    placeholder="e.g. Southside Branch"
                    className="input-field w-full"
                    value={newName}
                    onChange={(e) => setNewName(e.target.value)}
                  />
                </div>
                <div>
                  <label className="block text-sm font-semibold text-slate-700 mb-1">Location</label>
                  <input 
                    type="text" 
                    placeholder="e.g. Suburbs"
                    className="input-field w-full"
                    value={newLocation}
                    onChange={(e) => setNewLocation(e.target.value)}
                  />
                </div>
              </div>

              <div className="p-4 bg-slate-50 border-t border-slate-100 flex gap-2 justify-end">
                <button onClick={() => setShowModal(false)} className="px-6 py-2.5 rounded-xl font-bold text-slate-600 hover:bg-slate-200 transition-colors">
                  Cancel
                </button>
                <button onClick={handleAdd} className="btn-primary px-6 py-2.5">
                  Save Branch
                </button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
