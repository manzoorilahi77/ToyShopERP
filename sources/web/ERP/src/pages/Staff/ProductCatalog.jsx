import React, { useState, useEffect } from 'react';
import { Search, ScanLine, Mic, X, Star, Filter } from 'lucide-react';
import { motion } from 'framer-motion';
import { getCatalog, getCategories, toggleFavorite as toggleFavoriteAPI } from '../../services/productService';
import toast from 'react-hot-toast';

export default function ProductCatalog() {
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState(null);
  const [showFavoritesOnly, setShowFavoritesOnly] = useState(false);

  const [catalog, setCatalog] = useState([]);
  const [categories, setCategories] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const loadData = async () => {
      try {
        const [catalogRes, catRes] = await Promise.all([
          getCatalog(),
          getCategories()
        ]);
        setCatalog(catalogRes.data || []);
        setCategories(catRes.data || []);
      } catch (error) {
        toast.error('Failed to load catalog');
      } finally {
        setLoading(false);
      }
    };
    loadData();
  }, []);

  const filteredProducts = catalog.filter(p => {
    const matchesSearch = p.name.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesCategory = selectedCategory ? p.categoryId === selectedCategory : true;
    const matchesFavorites = showFavoritesOnly ? p.isFavorite : true;
    return matchesSearch && matchesCategory && matchesFavorites;
  });

  const toggleFavorite = async (productId) => {
    try {
      await toggleFavoriteAPI(productId);
      setCatalog(prev => prev.map(p => 
        p.id === productId ? { ...p, isFavorite: !p.isFavorite } : p
      ));
    } catch (error) {
      toast.error('Failed to update favorite status');
    }
  };

  return (
    <div className="p-6 md:p-8 max-w-7xl mx-auto pb-24">
      {/* Header & Search */}
      <div className="mb-8 flex flex-col md:flex-row md:items-end justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold text-slate-800 font-heading">Product Catalog</h1>
          <p className="text-slate-500 mt-2">Browse {catalog.length} toys in the inventory.</p>
        </div>
        
        <div className="flex-1 max-w-md flex gap-2">
          <div className="flex-1 relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-slate-400" />
            <input 
              type="text" 
              placeholder="Search toys by name..."
              className="w-full pl-10 pr-4 py-3 bg-white border border-slate-200 rounded-xl focus:ring-2 focus:ring-primary/50 text-slate-800 shadow-sm"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
            />
            {searchQuery && (
              <button 
                className="absolute right-3 top-1/2 -translate-y-1/2 p-1 text-slate-400 hover:text-slate-600"
                onClick={() => setSearchQuery('')}
              >
                <X className="w-4 h-4" />
              </button>
            )}
          </div>
          <button className="p-3 bg-white border border-slate-200 rounded-xl text-slate-600 hover:bg-slate-50 shadow-sm transition-colors" title="Voice Search (Mock)">
            <Mic className="w-5 h-5" />
          </button>
          <button className="p-3 bg-white border border-slate-200 rounded-xl text-slate-600 hover:bg-slate-50 shadow-sm transition-colors" title="Scan QR (Mock)">
            <ScanLine className="w-5 h-5" />
          </button>
        </div>
      </div>

      {/* Filter Bar */}
      <div className="flex flex-col sm:flex-row gap-4 mb-6">
        <div className="flex gap-2">
          <button
            onClick={() => setShowFavoritesOnly(!showFavoritesOnly)}
            className={`px-4 py-2 rounded-lg text-sm font-semibold transition-colors flex items-center border ${
              showFavoritesOnly 
                ? 'bg-amber-50 border-amber-200 text-amber-700' 
                : 'bg-white border-slate-200 text-slate-600 hover:bg-slate-50'
            }`}
          >
            <Star className={`w-4 h-4 mr-2 ${showFavoritesOnly ? 'fill-amber-400 text-amber-400' : ''}`} />
            Favorites
          </button>
          <button className="px-4 py-2 bg-white border border-slate-200 rounded-lg text-sm font-semibold text-slate-600 hover:bg-slate-50 transition-colors flex items-center">
            <Filter className="w-4 h-4 mr-2" />
            Filters
          </button>
        </div>

        <div className="overflow-x-auto whitespace-nowrap hide-scrollbar flex gap-2 sm:ml-auto">
          <button
            onClick={() => setSelectedCategory(null)}
            className={`px-4 py-2 rounded-lg text-sm font-semibold transition-colors ${
              selectedCategory === null 
                ? 'bg-slate-800 text-white' 
                : 'bg-white border border-slate-200 text-slate-600 hover:bg-slate-50'
            }`}
          >
            All Categories
          </button>
          {categories.map(cat => (
            <button
              key={cat.id}
              onClick={() => setSelectedCategory(cat.id)}
              className={`px-4 py-2 rounded-lg text-sm font-semibold transition-colors ${
                selectedCategory === cat.id 
                  ? 'bg-primary text-white border-primary' 
                  : 'bg-white border border-slate-200 text-slate-600 hover:bg-slate-50'
              }`}
            >
              {cat.name}
            </button>
          ))}
        </div>
      </div>

      {/* Product Grid */}
      {loading ? (
        <div className="py-20 flex justify-center text-primary-600">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
        </div>
      ) : filteredProducts.length === 0 ? (
        <div className="py-20 flex flex-col items-center justify-center text-slate-400 bg-white rounded-2xl border border-slate-100 border-dashed">
          <Search className="w-16 h-16 mb-4 opacity-20" />
          <p className="text-lg font-medium text-slate-600">No toys found.</p>
          <p className="text-sm mt-1">Try clearing your filters or search query.</p>
        </div>
      ) : (
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-4 md:gap-6">
          {filteredProducts.map(product => {
            const isOutOfStock = product.stock === 0;

            return (
              <motion.div 
                layout
                initial={{ opacity: 0, scale: 0.9 }}
                animate={{ opacity: 1, scale: 1 }}
                exit={{ opacity: 0, scale: 0.9 }}
                key={product.id}
                className={`bg-white rounded-2xl overflow-hidden border shadow-sm transition-all duration-300 hover:shadow-md ${
                  isOutOfStock ? 'opacity-60 border-slate-200' : 'border-slate-100 hover:border-primary/30'
                }`}
              >
                <div className="h-40 w-full overflow-hidden bg-slate-100 relative group">
                  <img src={product.image || 'https://placehold.co/300x200?text=No+Image'} alt={product.name} className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500" onError={(e) => { e.target.onerror = null; e.target.src = 'https://placehold.co/300x200?text=No+Image'; }} />
                  
                  {isOutOfStock && (
                    <div className="absolute inset-0 bg-slate-900/40 flex items-center justify-center">
                      <span className="bg-red-500 text-white text-xs font-bold px-3 py-1.5 rounded-md shadow-lg">OUT OF STOCK</span>
                    </div>
                  )}

                  <button 
                    onClick={(e) => {
                      e.stopPropagation();
                      toggleFavorite(product.id);
                    }}
                    className="absolute top-2 right-2 p-2 bg-white/80 backdrop-blur-sm rounded-full shadow-sm hover:bg-white transition-colors"
                  >
                    <Star className={`w-4 h-4 ${product.isFavorite ? 'fill-amber-400 text-amber-400' : 'text-slate-400'}`} />
                  </button>
                </div>
                
                <div className="p-4">
                  <span className="text-xs font-medium text-primary mb-1 block">
                    {categories.find(c => c.id === product.categoryId)?.name}
                  </span>
                  <p className="font-semibold text-slate-800 text-sm md:text-base line-clamp-2 leading-tight mb-3">
                    {product.name}
                  </p>
                  
                  <div className="flex items-end justify-between mt-auto">
                    <div>
                      <p className="font-bold text-slate-800 text-lg">₹{product.price}</p>
                    </div>
                    <div className="text-right">
                      <p className="text-xs font-medium text-slate-500">Stock</p>
                      <p className={`text-sm font-bold ${isOutOfStock ? 'text-red-500' : 'text-support-green'}`}>
                        {product.stock}
                      </p>
                    </div>
                  </div>
                </div>
              </motion.div>
            );
          })}
        </div>
      )}
    </div>
  );
}
