import React, { useState, useEffect, useContext } from 'react';
import axios from 'axios';
import { AuthContext } from '../context/AuthContext';
import { useNavigate } from 'react-router-dom';
import { Package, Clock, CheckCircle2, Truck, XCircle } from 'lucide-react';
import toast from 'react-hot-toast';

const Orders = () => {
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);
  const { customer } = useContext(AuthContext);
  const navigate = useNavigate();

  useEffect(() => {
    if (!customer) {
      navigate('/login');
      return;
    }
    fetchOrders();
  }, [customer, navigate]);

  const fetchOrders = async () => {
    try {
      const token = localStorage.getItem('customerToken');
      const res = await axios.get('http://localhost:5000/api/v1/online-orders', {
        headers: { Authorization: `Bearer ${token}` }
      });
      setOrders(res.data.data);
      setLoading(false);
    } catch (error) {
      console.error("Failed to fetch orders", error);
      toast.error("Failed to load your orders");
      setLoading(false);
    }
  };

  const getStatusIcon = (status) => {
    switch (status) {
      case 'pending': return <Clock className="h-6 w-6 text-amber-500" />;
      case 'accepted': return <CheckCircle2 className="h-6 w-6 text-blue-500" />;
      case 'processing': return <Package className="h-6 w-6 text-indigo-500" />;
      case 'packed': return <Package className="h-6 w-6 text-purple-500" />;
      case 'out_for_delivery': return <Truck className="h-6 w-6 text-orange-500" />;
      case 'delivered': return <CheckCircle2 className="h-6 w-6 text-green-500" />;
      case 'cancelled': return <XCircle className="h-6 w-6 text-red-500" />;
      default: return <Clock className="h-6 w-6 text-gray-500" />;
    }
  };

  const getStatusText = (status) => {
    return status.split('_').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');
  };

  if (loading) {
    return <div className="max-w-7xl mx-auto px-4 py-20 text-center"><div className="animate-spin h-10 w-10 border-4 border-blue-600 border-t-transparent rounded-full mx-auto"></div></div>;
  }

  if (orders.length === 0) {
    return (
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-20 text-center">
        <Package className="mx-auto h-24 w-24 text-gray-300 mb-6" />
        <h2 className="text-3xl font-bold text-gray-900 mb-4">No Orders Yet</h2>
        <p className="text-gray-600 mb-8">You haven't placed any orders. Start exploring our toys!</p>
        <button onClick={() => navigate('/products')} className="bg-blue-600 text-white px-8 py-3 rounded-full font-medium hover:bg-blue-700">
          Shop Now
        </button>
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
      <h1 className="text-3xl font-bold text-gray-900 mb-8">My Orders</h1>
      
      <div className="space-y-6">
        {orders.map(order => (
          <div key={order.id} className="bg-white border border-gray-100 rounded-2xl shadow-sm overflow-hidden">
            <div className="bg-gray-50 px-6 py-4 border-b border-gray-100 flex flex-wrap items-center justify-between gap-4">
              <div>
                <p className="text-sm text-gray-500 mb-1">Order Placed</p>
                <p className="font-medium text-gray-900">{new Date(order.createdAt).toLocaleDateString('en-IN', { day: 'numeric', month: 'long', year: 'numeric' })}</p>
              </div>
              <div>
                <p className="text-sm text-gray-500 mb-1">Total</p>
                <p className="font-medium text-gray-900">₹{parseFloat(order.totalAmount).toFixed(2)}</p>
              </div>
              <div>
                <p className="text-sm text-gray-500 mb-1">Order #</p>
                <p className="font-medium text-gray-900">{order.invoiceNumber}</p>
              </div>
              <div className="flex items-center space-x-2 bg-white px-4 py-2 rounded-full border border-gray-200">
                {getStatusIcon(order.deliveryStatus)}
                <span className="font-bold text-gray-900">{getStatusText(order.deliveryStatus)}</span>
              </div>
            </div>
            
            <div className="p-6">
              <div className="flow-root">
                <ul className="-my-6 divide-y divide-gray-100">
                  {order.items.map(item => (
                    <li key={item.id} className="py-6 flex">
                      <div className="flex-shrink-0 w-24 h-24 border border-gray-100 rounded-lg overflow-hidden bg-gray-50 p-2">
                        <img 
                          src={item.product?.image ? `http://localhost:5000${item.product.image}` : 'https://placehold.co/200x200?text=Toy'} 
                          alt={item.product?.name} 
                          className="w-full h-full object-contain"
                        />
                      </div>
                      <div className="ml-6 flex-1 flex flex-col justify-center">
                        <div className="flex justify-between">
                          <div>
                            <h4 className="text-lg font-medium text-gray-900">{item.product?.name || 'Unknown Product'}</h4>
                            <p className="mt-1 text-sm text-gray-500">Qty: {item.quantity}</p>
                          </div>
                          <p className="text-lg font-bold text-gray-900">₹{item.totalPrice}</p>
                        </div>
                      </div>
                    </li>
                  ))}
                </ul>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

export default Orders;
