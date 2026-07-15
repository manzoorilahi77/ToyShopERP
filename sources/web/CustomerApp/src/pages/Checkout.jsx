import React, { useState, useContext, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import axios from 'axios';
import { CartContext } from '../context/CartContext';
import { AuthContext } from '../context/AuthContext';
import toast from 'react-hot-toast';
import { CheckCircle2, CreditCard, Truck, AlertCircle } from 'lucide-react';

const Checkout = () => {
  const { cart, fetchCart } = useContext(CartContext);
  const { customer } = useContext(AuthContext);
  const navigate = useNavigate();
  const [paymentMethod, setPaymentMethod] = useState('cash');
  const [isProcessing, setIsProcessing] = useState(false);
  
  useEffect(() => {
    if (!customer) navigate('/login');
    if (!cart?.items || cart.items.length === 0) navigate('/cart');
  }, [customer, cart, navigate]);

  const items = cart?.items || [];
  const subtotal = items.reduce((acc, item) => acc + (item.product.price * item.quantity), 0);
  const gst = subtotal * 0.18;
  const total = subtotal + gst;

  const handlePlaceOrder = async () => {
    setIsProcessing(true);
    try {
      const token = localStorage.getItem('customerToken');
      
      // Simulate payment delay for non-cash methods
      if (paymentMethod !== 'cash') {
        toast.loading('Processing payment...', { id: 'payment' });
        await new Promise(resolve => setTimeout(resolve, 2000));
        toast.success('Payment successful!', { id: 'payment' });
      }

      await axios.post('http://localhost:5000/api/v1/online-orders', {
        paymentMethod,
        paymentStatus: paymentMethod === 'cash' ? 'pending' : 'success'
      }, {
        headers: { Authorization: `Bearer ${token}` }
      });
      
      toast.success('Order placed successfully!');
      await fetchCart();
      navigate('/orders');
    } catch (error) {
      toast.error(error.response?.data?.message || 'Failed to place order');
    } finally {
      setIsProcessing(false);
    }
  };

  if (!customer || items.length === 0) return null;

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
      <h1 className="text-3xl font-bold text-gray-900 mb-8">Checkout</h1>
      
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-12">
        <div>
          {/* Mock Address Selection */}
          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6 mb-8">
            <h2 className="text-xl font-bold text-gray-900 mb-4 flex items-center">
              <Truck className="h-5 w-5 mr-2 text-blue-600" /> Delivery Details
            </h2>
            <div className="bg-blue-50 border border-blue-100 rounded-xl p-4 flex items-start">
              <CheckCircle2 className="h-5 w-5 text-blue-600 mt-0.5 mr-3" />
              <div>
                <p className="font-medium text-gray-900">{customer.name}</p>
                <p className="text-gray-600 text-sm mt-1">{customer.phone}</p>
                <p className="text-gray-600 text-sm mt-2">123 Toy Street, Playville District<br/>City, State - 123456</p>
              </div>
            </div>
          </div>

          {/* Payment Method */}
          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6">
            <h2 className="text-xl font-bold text-gray-900 mb-4 flex items-center">
              <CreditCard className="h-5 w-5 mr-2 text-blue-600" /> Payment Method
            </h2>
            <div className="space-y-4">
              {[
                { id: 'upi', label: 'UPI (GPay, PhonePe)' },
                { id: 'card', label: 'Credit / Debit Card' },
                { id: 'cash', label: 'Cash on Delivery' }
              ].map(method => (
                <label key={method.id} className={`flex items-center p-4 border rounded-xl cursor-pointer transition-colors ${paymentMethod === method.id ? 'border-blue-500 bg-blue-50' : 'border-gray-200 hover:bg-gray-50'}`}>
                  <input 
                    type="radio" 
                    name="payment" 
                    value={method.id}
                    checked={paymentMethod === method.id}
                    onChange={() => setPaymentMethod(method.id)}
                    className="h-4 w-4 text-blue-600 border-gray-300 focus:ring-blue-500" 
                  />
                  <span className="ml-3 font-medium text-gray-900">{method.label}</span>
                </label>
              ))}
            </div>
            {paymentMethod !== 'cash' && (
              <div className="mt-4 flex items-center text-sm text-amber-600 bg-amber-50 p-3 rounded-lg">
                <AlertCircle className="h-5 w-5 mr-2 flex-shrink-0" />
                This is a demo. A mock payment will be processed.
              </div>
            )}
          </div>
        </div>

        <div>
          <div className="bg-gray-50 rounded-2xl p-6 border border-gray-100">
            <h2 className="text-xl font-bold text-gray-900 mb-6">Review Order</h2>
            
            <div className="space-y-4 mb-6 max-h-60 overflow-y-auto pr-2">
              {items.map(item => (
                <div key={item.id} className="flex justify-between items-center text-sm">
                  <div className="flex items-center flex-1">
                    <span className="font-medium text-gray-900">{item.quantity} x</span>
                    <span className="ml-2 text-gray-600 truncate max-w-[200px]">{item.product.name}</span>
                  </div>
                  <span className="font-medium text-gray-900">₹{item.product.price * item.quantity}</span>
                </div>
              ))}
            </div>
            
            <div className="border-t border-gray-200 pt-4 space-y-3 mb-6">
              <div className="flex justify-between text-gray-600 text-sm">
                <span>Subtotal</span>
                <span className="font-medium text-gray-900">₹{subtotal.toFixed(2)}</span>
              </div>
              <div className="flex justify-between text-gray-600 text-sm">
                <span>Estimated GST</span>
                <span className="font-medium text-gray-900">₹{gst.toFixed(2)}</span>
              </div>
            </div>
            
            <div className="border-t border-gray-200 pt-4 mb-8 flex justify-between items-center">
              <div>
                <span className="text-lg font-bold text-gray-900">Amount to Pay</span>
                <p className="text-xs text-gray-500 mt-1">Includes all taxes</p>
              </div>
              <span className="text-3xl font-extrabold text-blue-600">₹{total.toFixed(2)}</span>
            </div>
            
            <button 
              onClick={handlePlaceOrder}
              disabled={isProcessing}
              className="w-full bg-green-600 text-white py-4 rounded-xl font-bold text-lg hover:bg-green-700 flex items-center justify-center transition-colors shadow-lg disabled:opacity-70 disabled:cursor-not-allowed"
            >
              {isProcessing ? 'Processing...' : 'Place Order'}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Checkout;
