import React, { useState, useEffect } from 'react';
import axios from 'axios';
import useAuthStore from '../../store/authStore';
import toast from 'react-hot-toast';

const GstDashboard = () => {
  const { user } = useAuthStore();
  const [data, setData] = useState({
    totalSales: 0,
    outputGst: 0,
    inputGst: 0,
    netGstPayable: 0,
    pendingItc: 0,
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchDashboardData();
  }, []);

  const fetchDashboardData = async () => {
    try {
      setLoading(true);
      const token = localStorage.getItem('token');
      const response = await axios.get('http://localhost:5000/api/v1/gst-registrations/dashboard', {
        headers: { Authorization: `Bearer ${token}` }
      });
      setData(response.data.data);
    } catch (error) {
      toast.error('Failed to load GST Dashboard data');
      console.error(error);
    } finally {
      setLoading(false);
    }
  };

  if (loading) return <div className="p-6">Loading GST Dashboard...</div>;

  return (
    <div className="p-6 max-w-7xl mx-auto pb-24">
      <h1 className="text-3xl font-bold text-slate-800 font-heading mb-8">GST Dashboard</h1>
      
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <div className="card p-6">
          <p className="text-sm font-semibold text-slate-500 mb-1">Total Sales</p>
          <p className="text-2xl font-bold text-slate-800">₹{data.totalSales.toFixed(2)}</p>
        </div>
        <div className="card p-6">
          <p className="text-sm font-semibold text-slate-500 mb-1">Output GST</p>
          <p className="text-2xl font-bold text-red-600">₹{data.outputGst.toFixed(2)}</p>
        </div>
        <div className="card p-6">
          <p className="text-sm font-semibold text-slate-500 mb-1">Input GST</p>
          <p className="text-2xl font-bold text-emerald-600">₹{data.inputGst.toFixed(2)}</p>
        </div>
        <div className="card p-6">
          <p className="text-sm font-semibold text-slate-500 mb-1">Net GST Payable</p>
          <p className="text-2xl font-bold text-primary-600">₹{data.netGstPayable.toFixed(2)}</p>
        </div>
      </div>
    </div>
  );
};

export default GstDashboard;
