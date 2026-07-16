import React from 'react';
import { Outlet, Navigate } from 'react-router-dom';
import useAuthStore from '../../store/authStore';

export default function ProtectedRoute({ allowedRoles }) {
  const { isAuthenticated, role } = useAuthStore();

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  if (allowedRoles && !allowedRoles.includes(role)) {
    // Redirect to their respective home if they don't have access to this route
    if (role === 'owner') return <Navigate to="/owner" replace />;
    if (role === 'staff') return <Navigate to="/staff" replace />;
    if (role === 'super_admin') return <Navigate to="/super-admin" replace />;
    
    return <Navigate to="/login" replace />;
  }

  return <Outlet />;
}
