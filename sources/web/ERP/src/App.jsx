import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { Toaster } from 'react-hot-toast';

import Login from './pages/Auth/Login';
import OwnerShell from './layouts/OwnerShell';
import OwnerDashboard from './pages/Owner/Dashboard';
import StockAddition from './pages/Owner/StockAddition';
import Reports from './pages/Owner/Reports';
import OwnerSales from './pages/Owner/OwnerSales';
import ProductsList from './pages/Owner/ProductsList'; // Using this for Catalog for now
import BranchesManagement from './pages/Owner/BranchesManagement';
import StaffManagement from './pages/Owner/StaffManagement';
import GstRegistrations from './pages/Owner/GstRegistrations';
import GstDashboard from './pages/Owner/GstDashboard';
import GstReports from './pages/Owner/GstReports';
import Notifications from './pages/Owner/Notifications';
import Settings from './pages/Owner/Settings';

import SuperAdminDashboard from './pages/SuperAdmin/SuperAdminDashboard';
import TenantsManagement from './pages/SuperAdmin/TenantsManagement';
import SystemLogs from './pages/SuperAdmin/SystemLogs';
import SuperAdminSettings from './pages/SuperAdmin/SuperAdminSettings';
import GlobalStock from './pages/SuperAdmin/GlobalStock';
import GlobalStaff from './pages/SuperAdmin/GlobalStaff';
import Subscriptions from './pages/SuperAdmin/Subscriptions';

import StaffShell from './layouts/StaffShell';
import StaffDashboard from './pages/Staff/StaffDashboard';
import NewSale from './pages/Staff/NewSale';
import SalesHistory from './pages/Staff/SalesHistory';
import ProductCatalog from './pages/Staff/ProductCatalog';
import StaffProfile from './pages/Staff/StaffProfile';
import OnlineOrders from './pages/Staff/OnlineOrders';

import SuperAdminShell from './layouts/SuperAdminShell';
import ProtectedRoute from './components/layout/ProtectedRoute';

const App = () => {
  return (
    <>
      <Toaster position="top-right" />
      <Router>
        <Routes>
          <Route path="/login" element={<Login />} />

          <Route element={<ProtectedRoute allowedRoles={['owner', 'super_admin']} />}>
            <Route path="/owner" element={<OwnerShell />}>
              <Route index element={<OwnerDashboard />} />
              <Route path="stock-addition" element={<StockAddition />} />
              <Route path="reports" element={<Reports />} />
              <Route path="sales" element={<OwnerSales />} />
              <Route path="catalog" element={<ProductsList />} />
              <Route path="branches" element={<BranchesManagement />} />
              <Route path="staff" element={<StaffManagement />} />
              <Route path="gst" element={<GstRegistrations />} />
              <Route path="gst-dashboard" element={<GstDashboard />} />
              <Route path="gst-reports" element={<GstReports />} />
              <Route path="notifications" element={<Notifications />} />
              <Route path="settings" element={<Settings />} />
            </Route>
          </Route>

          <Route element={<ProtectedRoute allowedRoles={['staff']} />}>
            <Route path="/staff" element={<StaffShell />}>
              <Route index element={<StaffDashboard />} />
              <Route path="sell" element={<NewSale />} />
              <Route path="history" element={<SalesHistory />} />
              <Route path="catalog" element={<ProductCatalog />} />
              <Route path="profile" element={<StaffProfile />} />
              <Route path="online-orders" element={<OnlineOrders />} />
            </Route>
          </Route>

          <Route element={<ProtectedRoute allowedRoles={['super_admin']} />}>
            <Route path="/super-admin" element={<SuperAdminShell />}>
              <Route index element={<SuperAdminDashboard />} />
              <Route path="tenants" element={<TenantsManagement />} />
              <Route path="stock" element={<GlobalStock />} />
              <Route path="staff" element={<GlobalStaff />} />
              <Route path="subscriptions" element={<Subscriptions />} />
              <Route path="logs" element={<SystemLogs />} />
              <Route path="settings" element={<SuperAdminSettings />} />
            </Route>
          </Route>

          {/* Fallback route */}
          <Route path="*" element={<Navigate to="/login" replace />} />
        </Routes>
      </Router>
    </>
  );
};

export default App;