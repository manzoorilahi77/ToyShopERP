import React, { useState, useEffect, useContext } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import axios from 'axios';
import { CartContext } from '../context/CartContext';
import { AuthContext } from '../context/AuthContext';
import { ShoppingCart, Star, Truck, ShieldCheck, ArrowLeft } from 'lucide-react';
import toast from 'react-hot-toast';

const ProductDetails = () => {
  const { id } = useParams();
  const navigate = useNavigate();
  const [product, setProduct] = useState(null);
  const [loading, setLoading] = useState(true);
  const [quantity, setQuantity] = useState(1);
  const { addToCart } = useContext(CartContext);
  const { customer } = useContext(AuthContext);

  useEffect(() => {
    fetchProduct();
  }, [id]);

  const fetchProduct = async () => {
    try {
      const res = await axios.get(`http://localhost:5000/api/v1/products/${id}`);
      setProduct(res.data.data);
      setLoading(false);
    } catch (error) {
      console.error('Failed to fetch product', error);
      toast.error('Product not found');
      navigate('/products');
    }
  };

  const handleAddToCart = async () => {
    if (!customer) {
      toast.error("Please login first");
      navigate('/login');
      return;
    }
    try {
      await addToCart(product.id, quantity);
      toast.success('Added to cart!');
    } catch (error) {
      toast.error(error.response?.data?.message || 'Failed to add to cart');
    }
  };

  if (loading) {
    return <div className="max-w-7xl mx-auto px-4 py-20 text-center"><div className="animate-spin h-10 w-10 border-4 border-blue-600 border-t-transparent rounded-full mx-auto"></div></div>;
  }

  if (!product) return null;

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
      <button onClick={() => navigate(-1)} className="flex items-center text-gray-500 hover:text-blue-600 mb-8 font-medium">
        <ArrowLeft className="h-5 w-5 mr-1" /> Back to Products
      </button>

      <div className="bg-white rounded-3xl shadow-lg border border-gray-100 overflow-hidden">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-0">
          
          <div className="bg-gray-50 p-12 flex items-center justify-center relative">
            <img 
              src={product.image ? `http://localhost:5000${product.image}` : 'https://placehold.co/600x600?text=No+Image'} 
              alt={product.name} 
              className="w-full max-w-md h-auto object-contain rounded-xl drop-shadow-xl"
            />
            {product.stockQuantity <= 0 && (
              <div className="absolute top-6 left-6 bg-red-100 text-red-600 font-bold px-4 py-2 rounded-lg border border-red-200 shadow-sm">
                Out of Stock
              </div>
            )}
          </div>

          <div className="p-10 lg:p-14 flex flex-col">
            <div className="uppercase tracking-widest text-sm text-blue-600 font-bold mb-3">
              {product.category?.name || 'Toys'}
            </div>
            
            <h1 className="text-3xl lg:text-4xl font-extrabold text-gray-900 mb-4">{product.name}</h1>
            
            <div className="flex items-center mb-6 space-x-1">
              {[1,2,3,4,5].map(star => <Star key={star} className={`h-5 w-5 ${star <= 4 ? 'text-yellow-400 fill-current' : 'text-gray-300'}`} />)}
              <span className="text-gray-500 ml-2 text-sm">(24 reviews)</span>
            </div>

            <div className="text-4xl font-extrabold text-gray-900 mb-8">
              ₹{product.price}
              <span className="text-sm font-normal text-gray-500 ml-2">Inclusive of all taxes</span>
            </div>

            <p className="text-gray-600 leading-relaxed mb-10 text-lg">
              {product.description || 'No description available for this product.'}
            </p>

            <div className="mt-auto space-y-6">
              {product.stockQuantity > 0 ? (
                <div className="flex flex-col sm:flex-row gap-4">
                  <div className="flex items-center border-2 border-gray-200 rounded-xl bg-white overflow-hidden h-14">
                    <button 
                      onClick={() => setQuantity(Math.max(1, quantity - 1))}
                      className="px-4 py-2 text-gray-600 hover:bg-gray-100 h-full"
                    >
                      -
                    </button>
                    <span className="px-6 font-bold text-lg text-gray-900">{quantity}</span>
                    <button 
                      onClick={() => setQuantity(Math.min(product.stockQuantity, quantity + 1))}
                      className="px-4 py-2 text-gray-600 hover:bg-gray-100 h-full"
                    >
                      +
                    </button>
                  </div>
                  
                  <button 
                    onClick={handleAddToCart}
                    className="flex-1 bg-blue-600 hover:bg-blue-700 text-white font-bold text-lg rounded-xl h-14 flex items-center justify-center shadow-lg transition-transform active:scale-95"
                  >
                    <ShoppingCart className="h-5 w-5 mr-2" /> Add to Cart
                  </button>
                </div>
              ) : (
                <button disabled className="w-full bg-gray-200 text-gray-500 font-bold text-lg rounded-xl h-14 flex items-center justify-center cursor-not-allowed">
                  Currently Unavailable
                </button>
              )}
              
              <div className="grid grid-cols-2 gap-4 pt-6 border-t border-gray-100">
                <div className="flex items-center text-sm text-gray-600 font-medium">
                  <Truck className="h-5 w-5 mr-2 text-blue-600" /> Free Delivery
                </div>
                <div className="flex items-center text-sm text-gray-600 font-medium">
                  <ShieldCheck className="h-5 w-5 mr-2 text-blue-600" /> 1 Year Warranty
                </div>
              </div>
            </div>

          </div>
        </div>
      </div>
    </div>
  );
};

export default ProductDetails;
