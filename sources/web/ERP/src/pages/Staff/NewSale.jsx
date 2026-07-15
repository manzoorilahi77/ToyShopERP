import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Search, ScanLine, Mic, X, Plus, Minus, Trash2, ShoppingBag, Printer, Share2, CheckCircle } from 'lucide-react';
import { useSearchParams } from 'react-router-dom';
import { getCatalog, getCategories } from '../../services/productService';
import { createSale } from '../../services/saleService';
import api from '../../services/api';
import useAuthStore from '../../store/authStore';
import toast from 'react-hot-toast';

export default function NewSale() {
  const [searchParams] = useSearchParams();
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState(null);
  
  // Cart state: array of { product, quantity, unitPrice }
  const [cart, setCart] = useState([]);
  const [branch, setBranch] = useState('');
  const [branches, setBranches] = useState([]);
  const [paymentMode, setPaymentMode] = useState('Cash');
  const [showBill, setShowBill] = useState(false);
  const [lastOrder, setLastOrder] = useState(null);
  const [customerMobile, setCustomerMobile] = useState('');

  const { user } = useAuthStore();
  const [catalog, setCatalog] = useState([]);
  const [categories, setCategories] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const loadData = async () => {
      try {
        const [catalogRes, catRes, branchRes] = await Promise.all([
          getCatalog(),
          getCategories(),
          api.get('/branches').catch(() => ({ data: { data: [] } }))
        ]);
        const catData = catalogRes.data || [];
        setCatalog(catData);
        setCategories(catRes.data || []);
        
        const fetchedBranches = branchRes.data?.data || [];
        setBranches(fetchedBranches);
        if (fetchedBranches.length > 0) {
          setBranch(fetchedBranches[0].id);
        }
        
        // Auto-add item from URL
        const addId = searchParams.get('add');
        if (addId) {
          const product = catData.find(p => p.id === Number(addId));
          if (product) addToCart(product);
        }
      } catch (error) {
        toast.error('Failed to load catalog');
      } finally {
        setLoading(false);
      }
    };
    loadData();
  }, [searchParams]);

  const filteredProducts = catalog.filter(p => {
    const matchesSearch = p.name.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesCategory = selectedCategory ? p.categoryId === selectedCategory : true;
    return matchesSearch && matchesCategory;
  });

  const addToCart = (product) => {
    setCart(prev => {
      const existing = prev.find(item => item.product.id === product.id);
      if (existing) {
        if (existing.quantity >= product.stock) return prev; // check stock
        return prev.map(item => 
          item.product.id === product.id ? { ...item, quantity: item.quantity + 1 } : item
        );
      }
      return [...prev, { product, quantity: 1, unitPrice: product.price }];
    });
  };

  const updateQuantity = (productId, delta) => {
    setCart(prev => prev.map(item => {
      if (item.product.id === productId) {
        const newQ = item.quantity + delta;
        if (newQ > 0 && newQ <= item.product.stock) {
          return { ...item, quantity: newQ };
        }
      }
      return item;
    }));
  };

  const updateUnitPrice = (productId, newPrice) => {
    setCart(prev => prev.map(item => {
      if (item.product.id === productId) {
        return { ...item, unitPrice: Number(newPrice) || 0 };
      }
      return item;
    }));
  };

  const removeFromCart = (productId) => {
    setCart(prev => prev.filter(item => item.product.id !== productId));
  };

  const subtotal = cart.reduce((sum, item) => sum + (item.unitPrice * item.quantity), 0);
  const tax = cart.reduce((sum, item) => {
    const rate = Number(item.product.gstRate || 18); // fallback to 18 if not set
    return sum + (item.unitPrice * item.quantity * (rate / 100));
  }, 0);
  const total = subtotal + tax;

  const handleCheckout = async () => {
    if (cart.length === 0) return;
    
    // Default branchId if needed, in a real scenario this might come from authStore or a selector
    const branchId = branch || user?.branchId || 1;
    const selectedBranchObj = branches.find(b => b.id === Number(branchId));
    const branchName = selectedBranchObj ? selectedBranchObj.name : 'Main Branch';

    const payload = {
      branchId,
      paymentMethod: paymentMode.toLowerCase(),
      customerMobile: customerMobile,
      items: cart.map(item => ({
        productId: item.product.id,
        quantity: item.quantity,
        unitPrice: item.unitPrice
      }))
    };

    try {
      const res = await createSale(payload);
      
      setLastOrder({
        id: res.data.sale.invoiceNumber,
        items: [...cart],
        subtotal,
        tax,
        total: res.data.sale.totalAmount, // from backend
        branch: branchName,
        paymentMode,
        customerMobile,
        date: new Date(res.data.sale.createdAt).toLocaleString()
      });
      setShowBill(true);
      toast.success('Sale completed successfully!');
    } catch (error) {
      toast.error(error.response?.data?.message || 'Failed to complete sale');
    }
  };

  const completeAndClear = () => {
    setShowBill(false);
    setCart([]);
    setLastOrder(null);
    setCustomerMobile('');
  };

  const handlePrint = () => {
    window.print();
  };

  const handleShare = () => {
    if (!lastOrder) return;
    const text = `*Toy Shop Receipt*\nOrder ID: ${lastOrder.id}\nDate: ${lastOrder.date}\nBranch: ${lastOrder.branch}\n\nTotal: ₹${lastOrder.total.toFixed(2)}\nThank you for shopping with us!`;
    const mobileParam = lastOrder.customerMobile ? `${lastOrder.customerMobile}` : '';
    window.open(`https://wa.me/${mobileParam}?text=${encodeURIComponent(text)}`, '_blank');
  };

  return (
    <div className="flex flex-col lg:flex-row h-[calc(100vh-64px)] overflow-hidden bg-slate-50">
      
      {/* LEFT PANE: Catalog & Search */}
      <div className="flex-1 flex flex-col h-full overflow-hidden">
        {/* Search Bar */}
        <div className="p-4 bg-white border-b border-slate-200 shadow-sm z-10 flex items-center gap-2">
          <div className="flex-1 relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-slate-400" />
            <input 
              type="text" 
              placeholder="Search toys by name or SKU..."
              className="w-full pl-10 pr-4 py-3 bg-slate-100 border-none rounded-xl focus:ring-2 focus:ring-primary/50 text-slate-800"
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
          <button className="p-3 bg-slate-100 rounded-xl text-slate-600 hover:bg-slate-200 transition-colors" title="Voice Search (Mock)">
            <Mic className="w-5 h-5" />
          </button>
          <button className="p-3 bg-slate-100 rounded-xl text-slate-600 hover:bg-slate-200 transition-colors" title="Scan QR (Mock)">
            <ScanLine className="w-5 h-5" />
          </button>
        </div>

        {/* Categories */}
        <div className="px-4 py-3 bg-white border-b border-slate-100 overflow-x-auto whitespace-nowrap hide-scrollbar flex gap-2">
          <button
            onClick={() => setSelectedCategory(null)}
            className={`px-4 py-2 rounded-lg text-sm font-semibold transition-colors ${
              selectedCategory === null 
                ? 'bg-slate-800 text-white' 
                : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
            }`}
          >
            All Toys
          </button>
          {categories.map(cat => (
            <button
              key={cat.id}
              onClick={() => setSelectedCategory(cat.id)}
              className={`px-4 py-2 rounded-lg text-sm font-semibold transition-colors ${
                selectedCategory === cat.id 
                  ? 'bg-primary text-white' 
                  : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
              }`}
            >
              {cat.name}
            </button>
          ))}
        </div>

        {/* Product Grid */}
        <div className="flex-1 overflow-y-auto p-4 md:p-6 pb-32 lg:pb-6">
          {loading ? (
            <div className="h-full flex justify-center items-center">
              <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
            </div>
          ) : filteredProducts.length === 0 ? (
            <div className="h-full flex flex-col items-center justify-center text-slate-400">
              <ShoppingBag className="w-16 h-16 mb-4 opacity-20" />
              <p className="text-lg">No products found.</p>
            </div>
          ) : (
            <div className="grid grid-cols-2 sm:grid-cols-3 xl:grid-cols-4 gap-4 md:gap-6">
              {filteredProducts.map(product => {
                const cartItem = cart.find(i => i.product.id === product.id);
                const inCartQty = cartItem ? cartItem.quantity : 0;
                const isOutOfStock = product.stock === 0;

                return (
                  <motion.div 
                    layoutId={product.id}
                    key={product.id}
                    onClick={() => !isOutOfStock && addToCart(product)}
                    className={`bg-white rounded-2xl overflow-hidden border shadow-sm transition-all duration-200 ${
                      isOutOfStock ? 'opacity-50 cursor-not-allowed border-slate-200' : 'cursor-pointer hover:shadow-md border-slate-100 hover:border-primary/30'
                    }`}
                  >
                    <div className="h-32 sm:h-40 w-full overflow-hidden bg-slate-100 relative">
                      <img src={product.image || 'https://placehold.co/300x200?text=No+Image'} alt={product.name} className="w-full h-full object-cover" onError={(e) => { e.target.onerror = null; e.target.src = 'https://placehold.co/300x200?text=No+Image'; }} />
                      {isOutOfStock && (
                        <div className="absolute inset-0 bg-slate-900/40 flex items-center justify-center">
                          <span className="bg-red-500 text-white text-xs font-bold px-2 py-1 rounded">OUT OF STOCK</span>
                        </div>
                      )}
                      {inCartQty > 0 && (
                        <div className="absolute top-2 right-2 bg-primary text-white w-8 h-8 rounded-full flex items-center justify-center font-bold shadow-md">
                          {inCartQty}
                        </div>
                      )}
                    </div>
                    <div className="p-3 md:p-4">
                      <p className="font-semibold text-slate-800 text-sm md:text-base line-clamp-2 leading-tight mb-2">
                        {product.name}
                      </p>
                      <div className="flex items-end justify-between mt-2">
                        <div>
                          <p className="text-xs text-slate-500 mb-0.5">Stock: {product.stock}</p>
                          <p className="font-bold text-slate-800 text-lg">₹{product.price}</p>
                        </div>
                        {!isOutOfStock && (
                          <div className="w-8 h-8 rounded-full bg-slate-100 flex items-center justify-center text-primary group-hover:bg-primary group-hover:text-white transition-colors">
                            <Plus className="w-4 h-4" />
                          </div>
                        )}
                      </div>
                    </div>
                  </motion.div>
                );
              })}
            </div>
          )}
        </div>
      </div>

      {/* RIGHT PANE: Cart Sidebar */}
      <div className={`
        fixed inset-x-0 bottom-0 lg:relative lg:w-96 bg-white border-t lg:border-t-0 lg:border-l border-slate-200 shadow-[0_-10px_40px_rgba(0,0,0,0.05)] lg:shadow-none flex flex-col z-20 transition-all duration-300
        ${cart.length > 0 ? 'h-2/3 lg:h-full' : 'h-20 lg:h-full'}
      `}>
        {/* Cart Header (Mobile Toggle area) */}
        <div className="p-4 border-b border-slate-100 flex items-center justify-between bg-white shrink-0">
          <div className="flex items-center gap-2">
            <ShoppingBag className="w-5 h-5 text-slate-800" />
            <h2 className="text-lg font-bold text-slate-800 font-heading">Current Sale</h2>
          </div>
          <span className="bg-slate-100 text-slate-600 text-xs font-bold px-2 py-1 rounded-md">
            {cart.reduce((s, i) => s + i.quantity, 0)} Items
          </span>
        </div>

        {/* Cart Items list */}
        <div className="flex-1 overflow-y-auto p-4 bg-slate-50/50">
          {cart.length === 0 ? (
            <div className="h-full flex flex-col items-center justify-center text-slate-400">
              <ShoppingBag className="w-12 h-12 mb-3 opacity-20" />
              <p className="text-sm">Cart is empty</p>
              <p className="text-xs mt-1">Tap a product to add</p>
            </div>
          ) : (
            <div className="space-y-3">
              <AnimatePresence>
                {cart.map(item => (
                  <motion.div 
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, x: -20 }}
                    key={item.product.id}
                    className="bg-white p-3 rounded-xl border border-slate-100 shadow-sm flex gap-3"
                  >
                    <div className="w-16 h-16 rounded-lg overflow-hidden bg-slate-100 shrink-0">
                      <img src={item.product.image || 'https://placehold.co/300x200?text=No+Image'} alt={item.product.name} className="w-full h-full object-cover" onError={(e) => { e.target.onerror = null; e.target.src = 'https://placehold.co/300x200?text=No+Image'; }} />
                    </div>
                    <div className="flex-1 min-w-0 flex flex-col justify-between">
                      <div className="flex justify-between items-start">
                        <p className="font-semibold text-slate-800 text-sm leading-tight truncate pr-2">
                          {item.product.name}
                        </p>
                        <button 
                          onClick={() => removeFromCart(item.product.id)}
                          className="text-slate-300 hover:text-red-500 transition-colors p-1 -mr-1 -mt-1"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>
                      <div className="flex items-center justify-between mt-2">
                        <div className="flex items-center">
                          <span className="font-bold text-slate-800 text-sm mr-1">₹</span>
                          <input 
                            type="number" 
                            value={item.unitPrice} 
                            onChange={(e) => updateUnitPrice(item.product.id, e.target.value)}
                            className="w-16 px-1 py-0.5 text-sm font-bold text-slate-800 bg-slate-50 border border-slate-200 rounded focus:ring-1 focus:ring-primary outline-none"
                          />
                        </div>
                        <div className="flex items-center bg-slate-100 rounded-lg p-0.5">
                          <button 
                            onClick={() => updateQuantity(item.product.id, -1)}
                            className="w-7 h-7 flex items-center justify-center bg-white rounded-md shadow-sm text-slate-600 hover:text-primary transition-colors disabled:opacity-50 disabled:shadow-none"
                          >
                            <Minus className="w-3 h-3" />
                          </button>
                          <span className="w-8 text-center text-sm font-semibold text-slate-800">
                            {item.quantity}
                          </span>
                          <button 
                            onClick={() => updateQuantity(item.product.id, 1)}
                            disabled={item.quantity >= item.product.stock}
                            className="w-7 h-7 flex items-center justify-center bg-white rounded-md shadow-sm text-slate-600 hover:text-primary transition-colors disabled:opacity-50 disabled:shadow-none"
                          >
                            <Plus className="w-3 h-3" />
                          </button>
                        </div>
                      </div>
                    </div>
                  </motion.div>
                ))}
              </AnimatePresence>
            </div>
          )}
        </div>

        {/* Checkout Footer */}
        <div className="p-4 bg-white border-t border-slate-100 shrink-0">
          <div className="space-y-2 mb-4">
            <div className="flex gap-2 mb-3">
              <div className="flex-1">
                <label className="text-xs font-semibold text-slate-500 mb-1 block">Branch</label>
                <select 
                  value={branch}
                  onChange={(e) => setBranch(e.target.value)}
                  className="w-full text-sm p-2 border border-slate-200 rounded-lg bg-slate-50 focus:ring-1 focus:ring-primary outline-none"
                >
                  {branches.length === 0 && <option value="">Loading...</option>}
                  {branches.map(b => (
                    <option key={b.id} value={b.id}>{b.name}</option>
                  ))}
                </select>
              </div>
              <div className="flex-1">
                <label className="text-xs font-semibold text-slate-500 mb-1 block">Payment</label>
                <select 
                  value={paymentMode}
                  onChange={(e) => setPaymentMode(e.target.value)}
                  className="w-full text-sm p-2 border border-slate-200 rounded-lg bg-slate-50 focus:ring-1 focus:ring-primary outline-none"
                >
                  <option>Cash</option>
                  <option>Card</option>
                  <option>UPI</option>
                </select>
              </div>
            </div>
            <div className="mb-3">
              <label className="text-xs font-semibold text-slate-500 mb-1 block">Customer Mobile</label>
              <input 
                type="text" 
                value={customerMobile}
                onChange={(e) => setCustomerMobile(e.target.value)}
                placeholder="e.g. 9876543210 (Optional)"
                className="w-full text-sm p-2 border border-slate-200 rounded-lg bg-slate-50 focus:ring-1 focus:ring-primary outline-none"
              />
            </div>
            <div className="flex justify-between text-sm text-slate-500">
              <span>Subtotal</span>
              <span>₹{subtotal.toFixed(2)}</span>
            </div>
            <div className="flex justify-between text-sm text-slate-500">
              <span>Total GST</span>
              <span>₹{tax.toFixed(2)}</span>
            </div>
            <div className="border-t border-slate-100 pt-2 flex justify-between items-end">
              <span className="text-slate-800 font-semibold">Total</span>
              <span className="text-2xl font-bold text-slate-800 font-heading">
                ₹{total.toFixed(2)}
              </span>
            </div>
          </div>
          <button 
            onClick={handleCheckout}
            disabled={cart.length === 0}
            className="w-full btn-primary py-4 text-lg font-bold shadow-lg shadow-primary/30 disabled:opacity-50 disabled:shadow-none"
          >
            Confirm Sale (₹{total.toFixed(0)})
          </button>
        </div>
      </div>

      {/* Bill Modal */}
      <AnimatePresence>
        {showBill && lastOrder && (
          <motion.div 
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/40 backdrop-blur-sm print:hidden"
          >
            <motion.div 
              initial={{ scale: 0.95, y: 20 }}
              animate={{ scale: 1, y: 0 }}
              exit={{ scale: 0.95, y: 20 }}
              className="bg-white rounded-3xl shadow-xl w-full max-w-md overflow-hidden flex flex-col max-h-[90vh]"
            >
              <div className="p-6 text-center bg-primary/10 shrink-0">
                <div className="w-16 h-16 bg-primary rounded-full flex items-center justify-center mx-auto mb-4 text-white shadow-lg">
                  <CheckCircle className="w-8 h-8" />
                </div>
                <h2 className="text-2xl font-bold text-slate-800 font-heading">Sale Successful!</h2>
                <p className="text-slate-600 mt-1">Order {lastOrder.id}</p>
              </div>
              
              <div className="p-6 overflow-y-auto flex-1 bg-slate-50">
                <div className="bg-white p-4 rounded-xl border border-slate-100 shadow-sm mb-4">
                  <div className="flex justify-between text-sm mb-2 pb-2 border-b border-slate-50 text-slate-600">
                    <span>Date</span>
                    <span className="font-semibold text-slate-800">{lastOrder.date}</span>
                  </div>
                  <div className="flex justify-between text-sm mb-2 pb-2 border-b border-slate-50 text-slate-600">
                    <span>Branch</span>
                    <span className="font-semibold text-slate-800">{lastOrder.branch}</span>
                  </div>
                  <div className="flex justify-between text-sm text-slate-600">
                    <span>Payment Mode</span>
                    <span className="font-semibold text-slate-800">{lastOrder.paymentMode}</span>
                  </div>
                </div>

                <div className="bg-white p-4 rounded-xl border border-slate-100 shadow-sm">
                  <h4 className="font-bold text-slate-800 mb-3 font-heading">Items</h4>
                  <div className="space-y-3 mb-4">
                    {lastOrder.items.map((item, idx) => (
                      <div key={idx} className="flex justify-between text-sm">
                        <div className="flex-1">
                          <p className="font-semibold text-slate-800 line-clamp-1">{item.product.name}</p>
                          <p className="text-slate-500 text-xs">{item.quantity} x ₹{item.unitPrice}</p>
                        </div>
                        <p className="font-semibold text-slate-800">₹{(item.quantity * item.unitPrice).toFixed(2)}</p>
                      </div>
                    ))}
                  </div>
                  
                  <div className="border-t border-slate-100 pt-3 space-y-2">
                    <div className="flex justify-between text-sm text-slate-500">
                      <span>Subtotal</span>
                      <span>₹{lastOrder.subtotal.toFixed(2)}</span>
                    </div>
                    <div className="flex justify-between text-sm text-slate-500">
                      <span>Total GST</span>
                      <span>₹{lastOrder.tax.toFixed(2)}</span>
                    </div>
                    <div className="flex justify-between items-end mt-2 pt-2 border-t border-slate-100">
                      <span className="font-bold text-slate-800">Total</span>
                      <span className="font-bold text-primary text-xl">₹{lastOrder.total.toFixed(2)}</span>
                    </div>
                  </div>
                </div>
              </div>

              <div className="p-4 bg-white border-t border-slate-100 flex flex-col gap-2 shrink-0">
                <div className="flex gap-2">
                  <button onClick={handlePrint} className="flex-1 py-3 px-4 rounded-xl font-bold border border-slate-200 text-slate-700 hover:bg-slate-50 flex items-center justify-center transition-colors">
                    <Printer className="w-5 h-5 mr-2" /> Print
                  </button>
                  <button onClick={handleShare} className="flex-1 py-3 px-4 rounded-xl font-bold bg-[#25D366] text-white hover:bg-[#128C7E] flex items-center justify-center shadow-lg shadow-[#25D366]/30 transition-colors">
                    <Share2 className="w-5 h-5 mr-2" /> Share
                  </button>
                </div>
                <button onClick={completeAndClear} className="w-full py-3 px-4 rounded-xl font-bold text-slate-500 hover:bg-slate-100 transition-colors mt-2">
                  Done & New Sale
                </button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Hidden Print Content */}
      {lastOrder && (
        <div className="hidden print:block p-8 font-sans bg-white min-h-screen">
          <h1 className="text-3xl font-bold text-center mb-2">Toy Shop</h1>
          <p className="text-center text-gray-500 mb-8">{lastOrder.branch}</p>
          
          <div className="mb-6 flex justify-between">
            <div>
              <p><strong>Order ID:</strong> {lastOrder.id}</p>
              <p><strong>Date:</strong> {lastOrder.date}</p>
            </div>
            <div className="text-right">
              <p><strong>Payment:</strong> {lastOrder.paymentMode}</p>
            </div>
          </div>

          <table className="w-full mb-6 border-collapse">
            <thead>
              <tr className="border-b-2 border-gray-300">
                <th className="text-left py-2">Item</th>
                <th className="text-center py-2">Qty</th>
                <th className="text-right py-2">Price</th>
                <th className="text-right py-2">Total</th>
              </tr>
            </thead>
            <tbody>
              {lastOrder.items.map((item, idx) => (
                <tr key={idx} className="border-b border-gray-100">
                  <td className="py-2">{item.product.name}</td>
                  <td className="text-center py-2">{item.quantity}</td>
                  <td className="text-right py-2">₹{item.unitPrice}</td>
                  <td className="text-right py-2">₹{(item.quantity * item.unitPrice).toFixed(2)}</td>
                </tr>
              ))}
            </tbody>
          </table>

          <div className="w-1/2 ml-auto">
            <div className="flex justify-between py-1">
              <span>Subtotal:</span>
              <span>₹{lastOrder.subtotal.toFixed(2)}</span>
            </div>
            <div className="flex justify-between py-1">
              <span>Total GST:</span>
              <span>₹{lastOrder.tax.toFixed(2)}</span>
            </div>
            <div className="flex justify-between py-2 font-bold text-xl border-t-2 border-gray-300 mt-2">
              <span>Total:</span>
              <span>₹{lastOrder.total.toFixed(2)}</span>
            </div>
          </div>
          <p className="text-center mt-12 text-gray-500">Thank you for shopping with us!</p>
        </div>
      )}
    </div>
  );
}
