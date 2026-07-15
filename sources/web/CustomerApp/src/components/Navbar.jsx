import React, { useContext, useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { AuthContext } from '../context/AuthContext';
import { CartContext } from '../context/CartContext';
import { ShoppingCart, User, LogOut, Menu, Search, Package } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

const Navbar = () => {
  const { customer, logout } = useContext(AuthContext);
  const { cart } = useContext(CartContext);
  const navigate = useNavigate();
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const handleScroll = () => {
      setScrolled(window.scrollY > 20);
    };
    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  const handleLogout = () => {
    logout();
    navigate('/');
  };

  const totalItems = cart?.items?.reduce((acc, item) => acc + item.quantity, 0) || 0;

  return (
    <nav className={`sticky top-0 z-50 transition-all duration-300 ${scrolled ? 'glass shadow-sm py-2' : 'bg-transparent py-4'}`}>
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between items-center h-14">
          <Link to="/" className="flex items-center gap-2 group">
            <motion.div whileHover={{ rotate: 180 }} transition={{ duration: 0.3 }}>
              <Package className="h-8 w-8 text-indigo-600 drop-shadow-md" />
            </motion.div>
            <span className="text-2xl font-extrabold bg-clip-text text-transparent bg-gradient-to-r from-indigo-600 to-purple-600 tracking-tight">ToyShop</span>
          </Link>

          <div className="hidden md:flex flex-1 max-w-xl mx-8">
            <div className="relative w-full group">
              <input 
                type="text" 
                placeholder="Search toys, brands, categories..." 
                className="w-full bg-slate-100/80 backdrop-blur-sm rounded-full py-2.5 px-5 pl-12 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:bg-white transition-all duration-300 shadow-inner"
              />
              <Search className="absolute left-4 top-3 h-5 w-5 text-slate-400 group-focus-within:text-indigo-500 transition-colors" />
            </div>
          </div>

          <div className="flex items-center space-x-6">
            <Link to="/products" className="text-slate-600 hover:text-indigo-600 font-medium transition-colors relative after:content-[''] after:absolute after:w-full after:scale-x-0 after:h-0.5 after:bottom-0 after:left-0 after:bg-indigo-600 after:origin-bottom-right after:transition-transform after:duration-300 hover:after:scale-x-100 hover:after:origin-bottom-left">Shop</Link>
            
            <Link to="/cart" className="text-slate-600 hover:text-indigo-600 relative group">
              <motion.div whileHover={{ scale: 1.1 }}>
                <ShoppingCart className="h-6 w-6" />
              </motion.div>
              <AnimatePresence>
                {totalItems > 0 && (
                  <motion.span 
                    initial={{ scale: 0 }}
                    animate={{ scale: 1 }}
                    exit={{ scale: 0 }}
                    className="absolute -top-2 -right-2 bg-gradient-to-r from-pink-500 to-rose-500 text-white text-xs font-bold rounded-full h-5 w-5 flex items-center justify-center shadow-md"
                  >
                    {totalItems}
                  </motion.span>
                )}
              </AnimatePresence>
            </Link>

            {customer ? (
              <div className="relative group">
                <button className="flex items-center space-x-2 text-slate-600 hover:text-indigo-600 transition-colors">
                  <div className="bg-indigo-100 p-1.5 rounded-full">
                    <User className="h-5 w-5 text-indigo-600" />
                  </div>
                  <span className="font-semibold hidden sm:block">{customer.name.split(' ')[0]}</span>
                </button>
                <div className="absolute right-0 w-48 mt-2 opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all duration-200 transform origin-top-right group-hover:scale-100 scale-95 bg-white rounded-xl shadow-xl border border-slate-100 overflow-hidden z-50">
                  <Link to="/profile" className="block px-4 py-3 text-sm text-slate-700 hover:bg-slate-50 font-medium border-b border-slate-50 transition-colors">My Profile</Link>
                  <Link to="/orders" className="block px-4 py-3 text-sm text-slate-700 hover:bg-slate-50 font-medium border-b border-slate-50 transition-colors">My Orders</Link>
                  <button onClick={handleLogout} className="w-full text-left flex items-center px-4 py-3 text-sm text-rose-600 hover:bg-rose-50 font-medium transition-colors">
                    <LogOut className="h-4 w-4 mr-2" /> Logout
                  </button>
                </div>
              </div>
            ) : (
              <Link to="/login" className="bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700 text-white px-5 py-2 rounded-full font-medium transition-all duration-300 shadow-md hover:shadow-lg transform hover:-translate-y-0.5">
                Login
              </Link>
            )}
          </div>
        </div>
      </div>
    </nav>
  );
};

export default Navbar;
