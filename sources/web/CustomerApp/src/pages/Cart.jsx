import React, { useContext } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { CartContext } from '../context/CartContext';
import { AuthContext } from '../context/AuthContext';
import { Trash2, Plus, Minus, ArrowRight, ShoppingBag } from 'lucide-react';
import toast from 'react-hot-toast';

const Cart = () => {
  const { cart, updateQuantity, removeFromCart, clearCart } = useContext(CartContext);
  const { customer } = useContext(AuthContext);
  const navigate = useNavigate();

  if (!customer) {
    return (
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-20 text-center">
        <ShoppingBag className="mx-auto h-24 w-24 text-gray-300 mb-6" />
        <h2 className="text-3xl font-bold text-gray-900 mb-4">Your cart is waiting</h2>
        <p className="text-gray-600 mb-8">Please login to view your cart and start shopping.</p>
        <Link to="/login" className="bg-blue-600 text-white px-8 py-3 rounded-full font-medium hover:bg-blue-700">
          Login Now
        </Link>
      </div>
    );
  }

  const items = cart?.items || [];

  if (items.length === 0) {
    return (
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-20 text-center">
        <ShoppingBag className="mx-auto h-24 w-24 text-gray-300 mb-6" />
        <h2 className="text-3xl font-bold text-gray-900 mb-4">Your cart is empty</h2>
        <p className="text-gray-600 mb-8">Looks like you haven't added any toys yet.</p>
        <Link to="/products" className="bg-blue-600 text-white px-8 py-3 rounded-full font-medium hover:bg-blue-700">
          Start Shopping
        </Link>
      </div>
    );
  }

  const subtotal = items.reduce((acc, item) => acc + (item.product.price * item.quantity), 0);
  const gst = subtotal * 0.18; // 18% GST mock
  const total = subtotal + gst;

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
      <h1 className="text-3xl font-bold text-gray-900 mb-8">Shopping Cart</h1>
      
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-12">
        <div className="lg:col-span-2">
          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
            <ul className="divide-y divide-gray-100">
              {items.map((item) => (
                <li key={item.id} className="p-6 flex items-center space-x-6">
                  <img 
                    src={item.product.image ? (item.product.image.startsWith('http') ? item.product.image : `http://localhost:5000${item.product.image.startsWith('/') ? '' : '/'}${item.product.image}`) : 'https://placehold.co/200x200?text=No+Image'} 
                    alt={item.product.name} 
                    className="w-24 h-24 object-contain bg-gray-50 rounded-lg p-2"
                  />
                  <div className="flex-1">
                    <h3 className="text-lg font-semibold text-gray-900">{item.product.name}</h3>
                    <p className="text-blue-600 font-bold mt-1">₹{item.product.price}</p>
                    
                    <div className="flex items-center mt-4 space-x-4">
                      <div className="flex items-center border border-gray-200 rounded-lg">
                        <button 
                          onClick={() => updateQuantity(item.id, item.quantity - 1)}
                          className="p-2 hover:bg-gray-50 text-gray-600"
                        >
                          <Minus className="h-4 w-4" />
                        </button>
                        <span className="px-4 font-medium text-gray-900">{item.quantity}</span>
                        <button 
                          onClick={() => updateQuantity(item.id, item.quantity + 1)}
                          disabled={item.quantity >= item.product.stock}
                          className="p-2 hover:bg-gray-50 text-gray-600 disabled:opacity-50"
                        >
                          <Plus className="h-4 w-4" />
                        </button>
                      </div>
                      <button 
                        onClick={() => removeFromCart(item.id)}
                        className="text-red-500 hover:text-red-700 flex items-center text-sm font-medium"
                      >
                        <Trash2 className="h-4 w-4 mr-1" /> Remove
                      </button>
                    </div>
                  </div>
                  <div className="text-right font-bold text-lg text-gray-900">
                    ₹{item.product.price * item.quantity}
                  </div>
                </li>
              ))}
            </ul>
            <div className="bg-gray-50 p-4 border-t border-gray-100 flex justify-end">
              <button 
                onClick={clearCart}
                className="text-gray-500 hover:text-red-600 text-sm font-medium"
              >
                Clear Cart
              </button>
            </div>
          </div>
        </div>
        
        <div>
          <div className="bg-gray-50 rounded-2xl p-6 border border-gray-100 sticky top-24">
            <h2 className="text-xl font-bold text-gray-900 mb-6">Order Summary</h2>
            
            <div className="space-y-4 mb-6">
              <div className="flex justify-between text-gray-600">
                <span>Subtotal</span>
                <span className="font-medium text-gray-900">₹{subtotal.toFixed(2)}</span>
              </div>
              <div className="flex justify-between text-gray-600">
                <span>Estimated GST (18%)</span>
                <span className="font-medium text-gray-900">₹{gst.toFixed(2)}</span>
              </div>
              <div className="flex justify-between text-gray-600">
                <span>Delivery</span>
                <span className="font-medium text-green-600">Free</span>
              </div>
            </div>
            
            <div className="border-t border-gray-200 pt-4 mb-8 flex justify-between">
              <span className="text-lg font-bold text-gray-900">Total</span>
              <span className="text-2xl font-extrabold text-blue-600">₹{total.toFixed(2)}</span>
            </div>
            
            <button 
              onClick={() => navigate('/checkout')}
              className="w-full bg-blue-600 text-white py-4 rounded-xl font-bold text-lg hover:bg-blue-700 flex items-center justify-center transition-colors shadow-lg hover:shadow-blue-500/30"
            >
              Proceed to Checkout <ArrowRight className="ml-2 h-5 w-5" />
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Cart;
