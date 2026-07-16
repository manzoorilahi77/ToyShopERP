import React, { useContext, useState, useEffect, useRef } from 'react';
import { Link, useNavigate, useLocation } from 'react-router-dom';
import { AuthContext } from '../context/AuthContext';
import { CartContext } from '../context/CartContext';
import { ShoppingCart, User, LogOut, Menu, Search, Package } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import axios from 'axios';

const Navbar = () => {
  const { customer, logout } = useContext(AuthContext);
  const { cart } = useContext(CartContext);
  const navigate = useNavigate();
  const location = useLocation();
  const [scrolled, setScrolled] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const [allProducts, setAllProducts] = useState([]);
  const [isFocused, setIsFocused] = useState(false);
  
  // To handle clicking outside the dropdown
  const dropdownRef = useRef(null);

  useEffect(() => {
    const handleScroll = () => {
      setScrolled(window.scrollY > 20);
    };
    window.addEventListener('scroll', handleScroll);
    
    const handleClickOutside = (event) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target)) {
        setIsFocused(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    
    // Fetch products for search dropdown
    axios.get('http://localhost:5000/api/v1/products')
      .then(res => setAllProducts(res.data.data.products || res.data.data))
      .catch(err => console.error('Failed to fetch products for search', err));
      
    return () => {
      window.removeEventListener('scroll', handleScroll);
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);

  // Sync search term with URL on products page
  useEffect(() => {
    if (location.pathname === '/products') {
      const params = new URLSearchParams(location.search);
      setSearchTerm(params.get('search') || '');
    } else {
      setSearchTerm(''); // Clear when navigating away
    }
  }, [location.pathname, location.search]);

  const handleLogout = () => {
    logout();
    navigate('/');
  };

  const handleSearchChange = (e) => {
    const val = e.target.value;
    setSearchTerm(val);
    if (location.pathname === '/products') {
      navigate(`/products?search=${encodeURIComponent(val)}`, { replace: true });
    }
  };

  const handleSearch = (e) => {
    if (e.key === 'Enter' && searchTerm.trim()) {
      if (location.pathname !== '/products') {
        navigate(`/products?search=${encodeURIComponent(searchTerm.trim())}`);
      }
      setIsFocused(false);
    }
  };

  const totalItems = cart?.items?.reduce((acc, item) => acc + item.quantity, 0) || 0;

  const searchResults = searchTerm ? allProducts.filter(p => 
    p.name?.toLowerCase().includes(searchTerm.toLowerCase()) || 
    p.category?.name?.toLowerCase().includes(searchTerm.toLowerCase())
  ).slice(0, 5) : [];

  const showDropdown = isFocused && searchTerm && location.pathname !== '/products';

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
            <div className="relative w-full group" ref={dropdownRef}>
              <input 
                type="text" 
                value={searchTerm}
                onChange={handleSearchChange}
                onKeyDown={handleSearch}
                onFocus={() => setIsFocused(true)}
                placeholder="Search toys, brands, categories..." 
                className="w-full bg-slate-100/80 backdrop-blur-sm rounded-full py-2.5 px-5 pl-12 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:bg-white transition-all duration-300 shadow-inner"
              />
              <Search className="absolute left-4 top-3 h-5 w-5 text-slate-400 group-focus-within:text-indigo-500 transition-colors" />
              
              <AnimatePresence>
                {showDropdown && (
                  <motion.div 
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, y: 10 }}
                    className="absolute top-full left-0 right-0 mt-2 bg-white rounded-xl shadow-xl border border-slate-100 overflow-hidden z-50"
                  >
                    {searchResults.length > 0 ? (
                      <ul>
                        {searchResults.map(product => (
                          <li key={product.id}>
                            <Link 
                              to={`/product/${product.id}`}
                              onClick={() => { setIsFocused(false); setSearchTerm(''); }}
                              className="flex items-center p-3 hover:bg-slate-50 transition-colors border-b border-slate-50 last:border-0"
                            >
                              <img src={product.image} alt={product.name} className="w-12 h-12 object-cover rounded-md" />
                              <div className="ml-3">
                                <p className="text-sm font-semibold text-slate-800">{product.name}</p>
                                <p className="text-xs text-slate-500">${Number(product.price).toFixed(2)}</p>
                              </div>
                            </Link>
                          </li>
                        ))}
                      </ul>
                    ) : (
                      <div className="p-4 text-center text-sm text-slate-500">
                        No products found for "{searchTerm}"
                      </div>
                    )}
                  </motion.div>
                )}
              </AnimatePresence>
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
