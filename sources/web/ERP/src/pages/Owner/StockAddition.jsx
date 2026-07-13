import React, { useState, useEffect } from 'react';
import { Check, CheckCircle2, PackagePlus } from 'lucide-react';
import toast from 'react-hot-toast';
import { createProduct, getCategories } from '../../services/productService';

const STOCK_COLOR_TAGS = [
  '#DC2626', // red
  '#2563EB', // blue
  '#16A34A', // green
  '#D97706', // orange
  '#7C3AED', // purple
  '#0891B2', // teal
  '#DB2777', // pink
  '#78350F', // brown
];

export default function StockAddition() {
  const [name, setName] = useState('');
  const [price, setPrice] = useState('');
  const [company, setCompany] = useState('');
  const [quantity, setQuantity] = useState('100');
  const [colorTag, setColorTag] = useState(STOCK_COLOR_TAGS[0]);
  const [categoryId, setCategoryId] = useState('');
  const [categories, setCategories] = useState([]);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    const fetchCategories = async () => {
      try {
        const res = await getCategories();
        setCategories(res.data || []);
      } catch (error) {
        toast.error('Failed to load categories');
      }
    };
    fetchCategories();
  }, []);

  const isValid = 
    name.trim().length > 0 &&
    company.trim().length > 0 &&
    categoryId !== '' &&
    !isNaN(parseFloat(price)) && parseFloat(price) >= 0 &&
    !isNaN(parseInt(quantity)) && parseInt(quantity) > 0;

  const handleSave = async () => {
    if (!isValid || saving) return;
    setSaving(true);

    try {
      await createProduct({
        name,
        categoryId: parseInt(categoryId),
        price: parseFloat(price),
        stock: parseInt(quantity),
        image: 'https://images.unsplash.com/photo-1596461404969-9ae70f2830c1?auto=format&fit=crop&w=300&q=80'
      });

      toast.success(`${name} added to stock!`);
      
      // Reset form
      setName('');
      setPrice('');
      setCompany('');
      setQuantity('100');
      setCategoryId('');
      setColorTag(STOCK_COLOR_TAGS[0]);
    } catch (error) {
      toast.error(error.response?.data?.message || 'Failed to add stock');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="max-w-3xl mx-auto pb-24">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-slate-800 font-heading">Stock Addition</h1>
        <p className="text-slate-500 mt-2">Add new stock to warehouse</p>
      </div>

      <div className="space-y-8">
        {/* Product Details Section */}
        <section>
          <h3 className="text-lg font-bold text-slate-800 mb-4 flex items-center font-heading">
            <PackagePlus className="w-5 h-5 mr-2 text-primary" /> Product Details
          </h3>
          <div className="card p-6 space-y-4">
            <div>
              <label className="block text-sm font-semibold text-slate-700 mb-1">Product Name *</label>
              <input 
                type="text" 
                placeholder="e.g. Red Toy Car"
                className="input-field w-full"
                value={name}
                onChange={(e) => setName(e.target.value)}
              />
            </div>
            <div>
              <label className="block text-sm font-semibold text-slate-700 mb-1">Category *</label>
              <select 
                className="input-field w-full"
                value={categoryId}
                onChange={(e) => setCategoryId(e.target.value)}
              >
                <option value="">Select Category</option>
                {categories.map(cat => (
                  <option key={cat.id} value={cat.id}>{cat.name}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="block text-sm font-semibold text-slate-700 mb-1">Price *</label>
              <div className="relative">
                <span className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500 font-bold">₹</span>
                <input 
                  type="number" 
                  step="0.01"
                  className="input-field w-full pl-8"
                  value={price}
                  onChange={(e) => setPrice(e.target.value)}
                />
              </div>
            </div>
          </div>
        </section>

        {/* Stock Source Section */}
        <section>
          <h3 className="text-lg font-bold text-slate-800 mb-4 font-heading">Stock Source</h3>
          <div className="card p-6 space-y-4">
            <div>
              <label className="block text-sm font-semibold text-slate-700 mb-1">Source Company *</label>
              <input 
                type="text" 
                placeholder="e.g. Sunrise Toys"
                className="input-field w-full"
                value={company}
                onChange={(e) => setCompany(e.target.value)}
              />
            </div>
            <div>
              <label className="block text-sm font-semibold text-slate-700 mb-1">Quantity *</label>
              <input 
                type="number" 
                className="input-field w-full"
                value={quantity}
                onChange={(e) => setQuantity(e.target.value)}
              />
            </div>
          </div>
        </section>

        {/* Product Color Section */}
        <section>
          <h3 className="text-lg font-bold text-slate-800 mb-4 font-heading">Product Color Tag</h3>
          <div className="card p-6">
            <div className="flex flex-wrap gap-4">
              {STOCK_COLOR_TAGS.map(color => (
                <button
                  key={color}
                  type="button"
                  onClick={() => setColorTag(color)}
                  className={`w-12 h-12 rounded-full flex items-center justify-center transition-all ${
                    colorTag === color ? 'ring-4 ring-offset-2 ring-slate-800 scale-110' : 'hover:scale-105'
                  }`}
                  style={{ backgroundColor: color }}
                >
                  {colorTag === color && <Check className="w-6 h-6 text-white drop-shadow-md" />}
                </button>
              ))}
            </div>
          </div>
        </section>
      </div>

      {/* Bottom Bar matching mobile */}
      <div className="fixed bottom-0 left-0 lg:left-64 right-0 p-4 bg-white border-t border-slate-200 z-10 shadow-[0_-4px_6px_-1px_rgba(0,0,0,0.05)]">
        <div className="max-w-3xl mx-auto">
          <button 
            onClick={handleSave}
            disabled={!isValid || saving}
            className="w-full btn-primary py-4 text-lg font-bold flex items-center justify-center shadow-lg shadow-primary/30 disabled:opacity-50 disabled:shadow-none"
          >
            {saving ? (
              <span className="flex items-center">
                <svg className="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
                Adding Stock...
              </span>
            ) : (
              <>
                <CheckCircle2 className="w-6 h-6 mr-2" />
                Add Stock
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  );
}
