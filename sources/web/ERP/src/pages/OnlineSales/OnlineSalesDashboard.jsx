import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { Package, Truck, CheckCircle, IndianRupee, Clock, ArrowRight } from 'lucide-react';
import { Link } from 'react-router-dom';
import useAuthStore from '../../store/authStore';
import KpiCard from '../../components/ui/KpiCard';
import api from '../../services/api';
import toast from 'react-hot-toast';

export default function OnlineSalesDashboard() {
  const { user } = useAuthStore();
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchOrders = async () => {
      try {
        setLoading(true);
        const res = await api.get('/sales/online-orders');
        setOrders(res.data.data || []);
      } catch (error) {
        toast.error('Failed to load dashboard data');
      } finally {
        setLoading(false);
      }
    };
    fetchOrders();
  }, []);

  const pendingOrders = orders.filter(o => ['pending', 'accepted', 'processing', 'packed'].includes(o.deliveryStatus));
  const activeDeliveries = orders.filter(o => o.deliveryStatus === 'out_for_delivery');
  const completedOrders = orders.filter(o => o.deliveryStatus === 'delivered');
  const totalRevenue = completedOrders.reduce((sum, o) => sum + (parseFloat(o.totalAmount) || 0), 0);

  if (loading) {
    return (
      <div className="p-6 md:p-8 max-w-7xl mx-auto flex justify-center py-24">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
      </div>
    );
  }

  return (
    <div className="p-6 md:p-8 max-w-7xl mx-auto pb-24">
      <div className="mb-8 flex flex-col md:flex-row md:items-end justify-between">
        <div>
          <h1 className="text-3xl font-bold text-slate-800 font-heading">
            Good Morning, {user?.name || 'Online Sales'}! 📦
          </h1>
          <p className="text-slate-500 mt-2">Here's your online orders snapshot for today.</p>
        </div>
        <div className="mt-4 md:mt-0">
          <Link to="/online-sales/orders" className="btn-primary inline-flex items-center">
            <Package className="w-5 h-5 mr-2" />
            Manage Orders
          </Link>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <KpiCard
          title="Pending Processing"
          value={pendingOrders.length}
          icon={Clock}
          colorClass="bg-orange-100 text-orange-600"
        />
        <KpiCard
          title="Out for Delivery"
          value={activeDeliveries.length}
          icon={Truck}
          colorClass="bg-blue-100 text-blue-600"
        />
        <KpiCard
          title="Completed Deliveries"
          value={completedOrders.length}
          icon={CheckCircle}
          colorClass="bg-green-100 text-green-600"
        />
        <KpiCard
          title="Completed Revenue"
          value={`₹${totalRevenue.toLocaleString()}`}
          icon={IndianRupee}
          colorClass="bg-purple-100 text-purple-600"
        />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8 mb-8">
        <div className="lg:col-span-2 card p-6">
          <div className="flex items-center justify-between mb-6">
            <h3 className="text-xl font-bold text-slate-800 font-heading">Recent Pending Orders</h3>
            <Link to="/online-sales/orders" className="text-primary text-sm font-semibold flex items-center hover:underline">
              View All <ArrowRight className="w-4 h-4 ml-1" />
            </Link>
          </div>
          
          <div className="space-y-4">
            {pendingOrders.slice(0, 5).map(order => (
              <div key={order.id} className="flex items-center justify-between p-4 bg-slate-50 rounded-xl hover:bg-slate-100 transition-colors">
                <div className="flex items-center">
                  <div className="w-10 h-10 rounded-full bg-orange-100 text-orange-600 flex items-center justify-center mr-4">
                    <Package className="w-5 h-5" />
                  </div>
                  <div>
                    <h4 className="font-bold text-slate-800">{order.invoiceNumber}</h4>
                    <p className="text-sm text-slate-500">
                      {order.items?.length || 0} items • ₹{parseFloat(order.totalAmount).toFixed(2)}
                    </p>
                  </div>
                </div>
                <div className="text-right">
                  <span className="inline-block px-3 py-1 bg-orange-100 text-orange-700 text-xs font-bold rounded-full capitalize">
                    {order.deliveryStatus.replace('_', ' ')}
                  </span>
                  <p className="text-xs text-slate-400 mt-1">{new Date(order.createdAt).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'})}</p>
                </div>
              </div>
            ))}
            {pendingOrders.length === 0 && (
              <div className="text-center py-8 text-slate-500">
                <Package className="w-12 h-12 mx-auto mb-3 opacity-20" />
                <p>No pending orders at the moment.</p>
              </div>
            )}
          </div>
        </div>

        <div className="lg:col-span-1 card p-6 bg-gradient-to-br from-primary-600 to-primary-800 text-white">
          <h3 className="text-xl font-bold font-heading mb-6">Quick Actions</h3>
          <div className="space-y-4">
            <Link to="/online-sales/orders" className="block p-4 bg-white/10 hover:bg-white/20 rounded-xl backdrop-blur-sm transition-colors border border-white/10">
              <div className="flex items-center justify-between">
                <div className="flex items-center">
                  <Package className="w-6 h-6 mr-3 text-white" />
                  <span className="font-semibold text-white">Update Status</span>
                </div>
                <ArrowRight className="w-5 h-5 opacity-70" />
              </div>
            </Link>
            <Link to="/online-sales/catalog" className="block p-4 bg-white/10 hover:bg-white/20 rounded-xl backdrop-blur-sm transition-colors border border-white/10">
              <div className="flex items-center justify-between">
                <div className="flex items-center">
                  <CheckCircle className="w-6 h-6 mr-3 text-white" />
                  <span className="font-semibold text-white">View Catalog</span>
                </div>
                <ArrowRight className="w-5 h-5 opacity-70" />
              </div>
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
}
