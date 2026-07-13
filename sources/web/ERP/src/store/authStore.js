import { create } from 'zustand';

const useAuthStore = create((set) => ({
  user: JSON.parse(localStorage.getItem('user')) || null,
  role: (localStorage.getItem('role') || '').toLowerCase().replace(' ', '_') || null,
  isAuthenticated: !!localStorage.getItem('accessToken'),
  
  login: (userData, tokens) => {
    const normalizedRole = userData.role?.name?.toLowerCase().replace(' ', '_') || 'staff';
    localStorage.setItem('accessToken', tokens.accessToken);
    localStorage.setItem('refreshToken', tokens.refreshToken);
    localStorage.setItem('user', JSON.stringify(userData));
    localStorage.setItem('role', normalizedRole);
    
    set({ user: userData, role: normalizedRole, isAuthenticated: true });
  },
  
  logout: () => {
    localStorage.removeItem('accessToken');
    localStorage.removeItem('refreshToken');
    localStorage.removeItem('user');
    localStorage.removeItem('role');
    
    set({ user: null, role: null, isAuthenticated: false });
  },
}));

export default useAuthStore;
