import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { useNavigate } from 'react-router-dom';
import useAuthStore from '../../store/authStore';
import { ToyBrick, CheckCircle2 } from 'lucide-react';
import toast from 'react-hot-toast';
import PinModal from '../../components/auth/PinModal';

// Static users based on the flutter app screenshot
const USERS = [
  { id: 1, name: 'Ravi', initials: 'RK', colorClass: 'bg-blue-600', role: 'staff' },
  { id: 2, name: 'Anbu', initials: 'AS', colorClass: 'bg-green-600', role: 'staff' },
  { id: 3, name: 'Meena', initials: 'MR', colorClass: 'bg-pink-600', role: 'staff' },
  { id: 4, name: 'Karan', initials: 'KD', colorClass: 'bg-amber-600', role: 'staff' },
  { id: 5, name: 'Suraj', initials: 'SP', colorClass: 'bg-purple-600', role: 'staff' },
  { id: 6, name: 'Priya', initials: 'PN', colorClass: 'bg-teal-600', role: 'owner', label: 'Owner' },
  { id: 7, name: 'Admin', initials: 'SA', colorClass: 'bg-slate-800', role: 'super_admin', label: 'System' },
];

export default function Login() {
  const login = useAuthStore(state => state.login);
  const navigate = useNavigate();
  
  const [selectedUser, setSelectedUser] = useState(null);
  const [isPinModalOpen, setIsPinModalOpen] = useState(false);

  const handleUserClick = (user) => {
    setSelectedUser(user);
    if (user.role === 'super_admin' || user.role === 'owner') {
      setIsPinModalOpen(true);
    } else {
      // For staff, we'll log them in directly for this prototype
      // or we can add pin for them too later.
      performLogin(user);
    }
  };

  const handlePinComplete = async (pin) => {
    // In a real app, we'd validate the PIN.
    // For this prototype, any PIN is accepted as per requirements.
    setIsPinModalOpen(false);
    
    // Slight delay to allow modal animation to complete
    setTimeout(() => {
      performLogin(selectedUser);
    }, 300);
  };

  const performLogin = async (user) => {
    // Determine target route based on role
    const targetRole = user.role;
    
    login({ id: user.id, name: user.name, initials: user.initials, role: targetRole }, targetRole);
    toast.success(`Welcome back, ${user.name}!`);
    
    navigate(targetRole === 'super_admin' ? '/super-admin' : `/${targetRole}`);
  };

  return (
    <div className="min-h-screen flex flex-col items-center justify-center py-12 sm:px-6 lg:px-8 relative overflow-hidden bg-slate-50">
      {/* Top Left Logo & Status */}
      <div className="absolute top-6 left-6 right-6 flex justify-between items-center z-10">
        <div className="flex items-center space-x-2">
          <div className="bg-primary-600 p-2 rounded-xl">
            <ToyBrick className="w-6 h-6 text-white" />
          </div>
          <span className="text-xl font-bold font-heading text-slate-800">ToyShop ERP</span>
        </div>
        <div className="flex items-center space-x-1 text-green-600 bg-green-50 px-3 py-1 rounded-full text-sm font-medium border border-green-100">
          <CheckCircle2 className="w-4 h-4" />
          <span>Synced</span>
        </div>
      </div>

      <div className="w-full max-w-4xl relative z-10 mt-12">
        <div className="text-center sm:text-left sm:ml-8 mb-10">
          <motion.h2 
            initial={{ y: 20, opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            transition={{ duration: 0.5 }}
            className="text-4xl font-extrabold text-slate-900 font-heading tracking-tight"
          >
            Who's billing?
          </motion.h2>
          <motion.p 
            initial={{ y: 20, opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            transition={{ duration: 0.5, delay: 0.1 }}
            className="mt-2 text-lg text-slate-500"
          >
            Tap your photo to sign in
          </motion.p>
        </div>

        <motion.div 
          initial={{ y: 20, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          transition={{ duration: 0.5, delay: 0.2 }}
          className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-6 px-4 sm:px-8"
        >
          {USERS.map((user, idx) => (
            <motion.button
              key={user.id}
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              onClick={() => handleUserClick(user)}
              className={`flex flex-col items-center justify-center p-8 bg-white rounded-3xl shadow-sm border-2 transition-all duration-200
                ${user.role === 'super_admin' ? 'border-teal-500 shadow-teal-100' : 'border-slate-100 hover:border-slate-300 hover:shadow-md'}
              `}
            >
              <div className={`w-20 h-20 rounded-full flex items-center justify-center text-2xl font-bold text-white mb-4 ${user.colorClass}`}>
                {user.initials}
              </div>
              <span className="text-lg font-semibold text-slate-800">{user.name}</span>
              {user.label && (
                <span className="text-sm font-medium text-teal-600 mt-1">{user.label}</span>
              )}
            </motion.button>
          ))}
        </motion.div>
      </div>

      <PinModal 
        isOpen={isPinModalOpen} 
        onClose={() => setIsPinModalOpen(false)}
        onPinComplete={handlePinComplete}
        user={selectedUser}
      />
    </div>
  );
}
