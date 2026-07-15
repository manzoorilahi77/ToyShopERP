import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { useNavigate } from 'react-router-dom';
import useAuthStore from '../../store/authStore';
import { ToyBrick, CheckCircle2 } from 'lucide-react';
import toast from 'react-hot-toast';
import PinModal from '../../components/auth/PinModal';
import api from '../../services/api';
import { loginAPI } from '../../services/authService';

export default function Login() {
  const login = useAuthStore(state => state.login);
  const navigate = useNavigate();
  
  const [users, setUsers] = useState([]);
  const [selectedUser, setSelectedUser] = useState(null);
  const [isPinModalOpen, setIsPinModalOpen] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchUsers = async () => {
      try {
        const res = await api.get('/auth/users');
        setUsers(res.data.data || []);
      } catch (error) {
        toast.error('Failed to load users.');
      } finally {
        setLoading(false);
      }
    };
    fetchUsers();
  }, []);

  const handleUserClick = (user) => {
    setSelectedUser(user);
    // Everyone uses a PIN/password in this version
    setIsPinModalOpen(true);
  };

  const handlePinComplete = async (pin) => {
    try {
      const response = await loginAPI(selectedUser.email, pin);
      setIsPinModalOpen(false);
      
      const { user, accessToken, refreshToken } = response.data;
      
      // Slight delay for animation
      setTimeout(() => {
        login(user, { accessToken, refreshToken });
        toast.success(`Welcome back, ${user.name}!`);
        const normalizedRole = user.role?.name?.toLowerCase().replace(' ', '-') || 'staff';
        navigate(`/${normalizedRole}`);
      }, 300);
    } catch (error) {
      toast.error(error.response?.data?.message || 'Login failed. Incorrect PIN.');
      // Keep modal open or clear it so they can try again.
    }
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
          {loading ? (
            <div className="col-span-full flex justify-center py-10">
              <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
            </div>
          ) : users.length === 0 ? (
            <div className="col-span-full text-center py-10 text-slate-500">
              No users found. Please seed the database.
            </div>
          ) : users.map((user, idx) => (
            <motion.button
              key={user.id}
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              onClick={() => handleUserClick(user)}
              className={`flex flex-col items-center justify-center p-8 bg-white rounded-3xl shadow-sm border-2 transition-all duration-200
                ${user.role === 'super_admin' ? 'border-teal-500 shadow-teal-100' : 'border-slate-100 hover:border-slate-300 hover:shadow-md'}
              `}
            >
              <div className={`w-20 h-20 rounded-full flex items-center justify-center text-2xl font-bold text-white mb-4 ${user.colorClass || 'bg-blue-600'}`}>
                {user.initials}
              </div>
              <span className="text-lg font-semibold text-slate-800">{user.name}</span>
              {user.role && user.role !== 'staff' && (
                <span className="text-sm font-medium text-teal-600 mt-1 capitalize">{user.role.replace('_', ' ')}</span>
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
