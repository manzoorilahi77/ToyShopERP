import React, { useState, useEffect, useContext } from 'react';
import axios from 'axios';
import { motion } from 'framer-motion';
import { Link } from 'react-router-dom';
import ProductCard from '../components/ProductCard';
import { CartContext } from '../context/CartContext';
import { AuthContext } from '../context/AuthContext';
import toast from 'react-hot-toast';
import { ArrowRight, Star, ShieldCheck, Truck, Sparkles } from 'lucide-react';

const Home = () => {
  const [featuredProducts, setFeaturedProducts] = useState([]);
  const [loading, setLoading] = useState(true);
  const { addToCart } = useContext(CartContext);
  const { customer } = useContext(AuthContext);

  useEffect(() => {
    fetchProducts();
  }, []);

  const fetchProducts = async () => {
    try {
      const res = await axios.get('http://localhost:5000/api/v1/products');
      const products = res.data.data.products || res.data.data;
      setFeaturedProducts(products.slice(0, 4));
      setLoading(false);
    } catch (error) {
      console.error('Failed to fetch products', error);
      setLoading(false);
    }
  };

  const handleAddToCart = async (productId) => {
    try {
      await addToCart(productId, 1);
      toast.success('Added to cart!');
    } catch (error) {
      toast.error(error.response?.data?.message || 'Failed to add to cart');
    }
  };

  return (
    <div className="bg-slate-50">
      {/* Hero Section */}
      <div className="relative overflow-hidden">
        <div className="mesh-bg absolute inset-0 opacity-90 z-0"></div>
        <div className="absolute inset-0 bg-white/20 backdrop-blur-3xl z-10"></div>
        
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-20 lg:py-32 relative z-20">
          <div className="flex flex-col lg:flex-row items-center justify-between gap-16">
            <div className="lg:w-1/2">
              <motion.div
                initial={{ opacity: 0, scale: 0.9 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ duration: 0.5 }}
                className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-white/20 border border-white/30 text-white font-medium text-sm mb-6 shadow-sm"
              >
                <Sparkles className="h-4 w-4 text-yellow-300" />
                <span>New Summer Collection</span>
              </motion.div>
              
              <motion.h1 
                initial={{ opacity: 0, y: 30 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.6, delay: 0.1 }}
                className="text-5xl md:text-6xl lg:text-7xl font-extrabold mb-6 leading-[1.1] text-white drop-shadow-lg"
              >
                {customer ? `Welcome back, ${customer.name.split(' ')[0]}!` : 'Discover the Joy of Play'}
              </motion.h1>
              <motion.p 
                initial={{ opacity: 0, y: 30 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.6, delay: 0.2 }}
                className="text-xl md:text-2xl text-indigo-50 mb-10 font-light drop-shadow-md max-w-xl"
              >
                Explore our premium collection of educational and fun toys for children of all ages. Spark imagination today!
              </motion.p>
              <motion.div
                initial={{ opacity: 0, y: 30 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.6, delay: 0.3 }}
                className="flex flex-wrap gap-4"
              >
                <Link to="/products" className="inline-flex items-center bg-white text-indigo-900 font-bold px-8 py-4 rounded-full hover:bg-indigo-50 transition-all shadow-[0_8px_30px_rgb(0,0,0,0.12)] hover:shadow-[0_8px_30px_rgba(255,255,255,0.3)] transform hover:-translate-y-1 group">
                  Shop Now <ArrowRight className="ml-2 h-5 w-5 group-hover:translate-x-1 transition-transform" />
                </Link>
              </motion.div>
            </div>
            
            <div className="lg:w-1/2 relative hidden md:block">
              <motion.div
                initial={{ opacity: 0, x: 50, rotate: 5 }}
                animate={{ opacity: 1, x: 0, rotate: -2 }}
                transition={{ duration: 0.8, delay: 0.3, type: "spring" }}
                className="relative z-20"
              >
                <img 
                  src="https://images.unsplash.com/photo-1596461404969-9ae70f2830c1?ixlib=rb-4.0.3&auto=format&fit=crop&w=1000&q=80" 
                  alt="Premium Wooden Toys" 
                  className="w-full h-[500px] object-cover rounded-[3rem] shadow-2xl border-8 border-white/20"
                />
              </motion.div>
            </div>
          </div>
        </div>

        {/* Decorative Floating Elements */}
        <motion.div 
          animate={{ y: [0, -20, 0], rotate: [0, 10, 0] }}
          transition={{ duration: 5, repeat: Infinity, ease: "easeInOut" }}
          className="absolute right-[10%] top-[20%] w-32 h-32 bg-purple-500 rounded-full mix-blend-multiply filter blur-2xl opacity-50 z-10"
        />
        <motion.div 
          animate={{ y: [0, 20, 0], rotate: [0, -10, 0] }}
          transition={{ duration: 6, repeat: Infinity, ease: "easeInOut" }}
          className="absolute right-[20%] bottom-[10%] w-40 h-40 bg-pink-500 rounded-full mix-blend-multiply filter blur-2xl opacity-50 z-10"
        />
      </div>

      {/* Features */}
      <div className="relative -mt-16 z-30 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 mb-20">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <motion.div whileHover={{ y: -5 }} className="glass-card p-8 rounded-3xl flex flex-col items-center text-center">
            <div className="bg-gradient-to-br from-indigo-100 to-purple-100 p-4 rounded-2xl mb-5 shadow-inner">
              <Truck className="h-8 w-8 text-indigo-600" />
            </div>
            <h3 className="text-xl font-bold text-slate-800 mb-2">Fast Delivery</h3>
            <p className="text-slate-500 font-medium">Free shipping on all orders over ₹999.</p>
          </motion.div>
          <motion.div whileHover={{ y: -5 }} className="glass-card p-8 rounded-3xl flex flex-col items-center text-center">
            <div className="bg-gradient-to-br from-pink-100 to-rose-100 p-4 rounded-2xl mb-5 shadow-inner">
              <ShieldCheck className="h-8 w-8 text-pink-600" />
            </div>
            <h3 className="text-xl font-bold text-slate-800 mb-2">Safe & Certified</h3>
            <p className="text-slate-500 font-medium">All toys pass strict safety certifications.</p>
          </motion.div>
          <motion.div whileHover={{ y: -5 }} className="glass-card p-8 rounded-3xl flex flex-col items-center text-center">
            <div className="bg-gradient-to-br from-amber-100 to-orange-100 p-4 rounded-2xl mb-5 shadow-inner">
              <Star className="h-8 w-8 text-amber-600" />
            </div>
            <h3 className="text-xl font-bold text-slate-800 mb-2">Premium Quality</h3>
            <p className="text-slate-500 font-medium">Durable materials built to last generations.</p>
          </motion.div>
        </div>
      </div>

      {/* Featured Products */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-10 mb-20">
        <div className="flex justify-between items-end mb-12">
          <div>
            <h2 className="text-4xl font-extrabold text-slate-900 mb-3 tracking-tight">Featured Products</h2>
            <p className="text-lg text-slate-500 font-medium">Handpicked favorites for this season.</p>
          </div>
          <Link to="/products" className="text-indigo-600 font-bold hover:text-indigo-800 hidden sm:flex items-center group bg-indigo-50 px-5 py-2.5 rounded-full transition-colors">
            View All <ArrowRight className="ml-2 h-4 w-4 group-hover:translate-x-1 transition-transform" />
          </Link>
        </div>

        {loading ? (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-8">
            {[1, 2, 3, 4].map(n => (
              <div key={n} className="bg-white rounded-3xl h-[420px] animate-pulse shadow-sm"></div>
            ))}
          </div>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-8">
            {featuredProducts.map((product, index) => (
              <motion.div
                key={product.id}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.5, delay: index * 0.1 }}
              >
                <ProductCard product={product} onAddToCart={handleAddToCart} />
              </motion.div>
            ))}
          </div>
        )}
        
        <div className="mt-12 text-center sm:hidden">
           <Link to="/products" className="inline-flex items-center justify-center w-full bg-indigo-50 text-indigo-700 font-bold py-4 rounded-2xl hover:bg-indigo-100 transition-colors">
            View All Products
          </Link>
        </div>
      </div>
    </div>
  );
};

export default Home;
