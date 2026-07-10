import { create } from 'zustand';

// Mimics the Flutter AppSession
const useAuthStore = create((set) => ({
  user: null,
  role: null, // 'super_admin', 'owner', 'staff'
  isAuthenticated: false,
  login: (userData, userRole) => set({ user: userData, role: userRole, isAuthenticated: true }),
  logout: () => set({ user: null, role: null, isAuthenticated: false }),
}));

export default useAuthStore;
