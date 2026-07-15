import React, { useState, useEffect } from 'react';
import api from '../../services/api';
import toast from 'react-hot-toast';

const OnlineOrders = () => {
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchOrders();
  }, []);

  const fetchOrders = async () => {
    try {
      setLoading(true);
      const res = await api.get('/sales/online-orders');
      setOrders(res.data.data);
      setLoading(false);
    } catch (error) {
      toast.error('Failed to load online orders');
      setLoading(false);
    }
  };

  const handleStatusChange = async (orderId, newStatus) => {
    try {
      await api.put(`/sales/online-orders/${orderId}/status`, { deliveryStatus: newStatus });
      toast.success(`Order status updated to ${newStatus}`);
      fetchOrders();
    } catch (error) {
      toast.error('Failed to update status');
    }
  };

  const statusOptions = ['pending', 'accepted', 'processing', 'packed', 'out_for_delivery', 'delivered', 'cancelled'];

  if (loading) {
    return <div className="p-8 text-center"><div className="spinner-border animate-spin inline-block w-8 h-8 border-4 rounded-full border-t-transparent border-blue-600"></div></div>;
  }

  return (
    <div className="p-6">
      <h1 className="text-2xl font-bold text-gray-800 mb-6">Online Orders Management</h1>

      <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="bg-gray-50 border-b border-gray-100 text-gray-600 text-sm font-medium">
                <th className="px-6 py-4">Order ID</th>
                <th className="px-6 py-4">Date</th>
                <th className="px-6 py-4">Items</th>
                <th className="px-6 py-4">Total Amount</th>
                <th className="px-6 py-4">Payment</th>
                <th className="px-6 py-4">Status</th>
                <th className="px-6 py-4 text-right">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {orders.length === 0 ? (
                <tr>
                  <td colSpan="7" className="px-6 py-8 text-center text-gray-500">
                    No online orders found.
                  </td>
                </tr>
              ) : (
                orders.map(order => (
                  <tr key={order.id} className="hover:bg-gray-50/50">
                    <td className="px-6 py-4 font-medium text-gray-900">{order.invoiceNumber}</td>
                    <td className="px-6 py-4 text-gray-500">
                      {new Date(order.createdAt).toLocaleString()}
                    </td>
                    <td className="px-6 py-4">
                      <div className="text-sm text-gray-900">
                        {order.items?.length || 0} items
                      </div>
                      <div className="text-xs text-gray-500 truncate max-w-[200px]">
                        {order.items?.map(i => i.product?.name).join(', ')}
                      </div>
                    </td>
                    <td className="px-6 py-4 font-bold text-gray-900">
                      ₹{parseFloat(order.totalAmount).toFixed(2)}
                    </td>
                    <td className="px-6 py-4">
                      <span className={`px-2 py-1 rounded-full text-xs font-medium ${
                        order.status === 'completed' ? 'bg-green-100 text-green-700' : 'bg-yellow-100 text-yellow-700'
                      }`}>
                        {order.paymentMethod.toUpperCase()} - {order.status}
                      </span>
                    </td>
                    <td className="px-6 py-4">
                      <span className={`px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-700`}>
                        {order.deliveryStatus}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-right">
                      <select 
                        className="text-sm border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500 p-2 border"
                        value={order.deliveryStatus}
                        onChange={(e) => handleStatusChange(order.id, e.target.value)}
                      >
                        {statusOptions.map(opt => (
                          <option key={opt} value={opt}>
                            {opt.replace(/_/g, ' ').toUpperCase()}
                          </option>
                        ))}
                      </select>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};

export default OnlineOrders;
