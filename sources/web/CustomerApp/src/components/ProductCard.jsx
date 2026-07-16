import React from 'react';
import { Link } from 'react-router-dom';
import { ShoppingCart, Star } from 'lucide-react';
import { motion } from 'framer-motion';

const ProductCard = ({ product, onAddToCart }) => {
  const imageUrl = product.image 
    ? (product.image.startsWith('http') ? product.image : `http://localhost:5000${product.image.startsWith('/') ? '' : '/'}${product.image}`) 
    : 'https://placehold.co/400x400?text=No+Image';

  return (
    <motion.div 
      whileHover={{ y: -8, scale: 1.02 }}
      transition={{ duration: 0.3 }}
      className="bg-white rounded-[2rem] shadow-sm hover:shadow-xl hover:shadow-indigo-500/10 transition-all duration-300 overflow-hidden border border-slate-100 flex flex-col h-full group"
    >
      <Link to={`/products/${product.id}`} className="block relative pt-[100%] overflow-hidden bg-slate-50">
        <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_center,_var(--tw-gradient-stops))] from-indigo-50 via-slate-50 to-slate-100 z-0" />
        <div className="absolute inset-0 bg-gradient-to-t from-slate-200/50 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300 z-10" />
        <img 
          src={imageUrl} 
          alt={product.name} 
          className="absolute inset-0 w-full h-full object-contain p-10 group-hover:scale-110 group-hover:-rotate-3 transition-transform duration-700 ease-out z-10 drop-shadow-[0_20px_20px_rgba(0,0,0,0.15)]"
        />
        <div className="absolute top-4 left-4 z-20 flex flex-col gap-2">
          {product.stock < 5 && product.stock > 0 && (
            <div className="bg-orange-100/90 backdrop-blur-sm text-orange-600 text-xs font-bold px-3 py-1.5 rounded-full shadow-sm border border-orange-200">
              Only {product.stock} left
            </div>
          )}
          {product.stock <= 0 && (
            <div className="bg-red-100/90 backdrop-blur-sm text-red-600 text-xs font-bold px-3 py-1.5 rounded-full shadow-sm border border-red-200 text-center">
              Currently unavailable, soon it will get updated
            </div>
          )}
          {product.rating && (
             <div className="bg-white/90 backdrop-blur-sm text-slate-700 text-xs font-bold px-3 py-1.5 rounded-full shadow-sm border border-slate-200 flex items-center gap-1">
               <Star className="h-3 w-3 text-yellow-400 fill-current" />
               {product.rating}
             </div>
          )}
        </div>
      </Link>
      <div className="p-6 flex flex-col flex-grow relative bg-white z-20">
        <div className="flex-grow">
          <p className="text-[10px] text-indigo-600 uppercase tracking-widest mb-2 font-bold">{product.category?.name || 'Category'}</p>
          <Link to={`/products/${product.id}`}>
            <h3 className="text-xl font-bold text-slate-800 mb-2 line-clamp-2 group-hover:text-indigo-600 transition-colors leading-tight">{product.name}</h3>
          </Link>
          <p className="text-sm text-slate-500 line-clamp-2 mb-6 font-medium leading-relaxed">{product.description}</p>
        </div>
        <div className="flex items-center justify-between mt-auto">
          <div>
            <span className="text-2xl font-black text-slate-900 tracking-tight">₹{product.price}</span>
          </div>
          <motion.button 
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
            onClick={() => onAddToCart(product.id)}
            disabled={product.stock <= 0}
            className={`p-4 rounded-full flex items-center justify-center transition-all shadow-md ${
              product.stock > 0 
                ? 'bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700 text-white hover:shadow-lg hover:shadow-indigo-500/30' 
                : 'bg-slate-100 text-slate-400 cursor-not-allowed shadow-none'
            }`}
          >
            <ShoppingCart className="h-5 w-5" />
          </motion.button>
        </div>
      </div>
    </motion.div>
  );
};

export default ProductCard;
