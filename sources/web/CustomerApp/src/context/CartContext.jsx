import React, { createContext, useState, useEffect, useContext } from 'react';
import axios from 'axios';
import { AuthContext } from './AuthContext';

export const CartContext = createContext();

export const CartProvider = ({ children }) => {
  const [cart, setCart] = useState({ items: [] });
  const { customer } = useContext(AuthContext);

  useEffect(() => {
    if (customer) {
      fetchCart();
    } else {
      setCart({ items: [] }); // Clear cart on logout
    }
  }, [customer]);

  const getHeaders = () => {
    const token = localStorage.getItem('customerToken');
    return { headers: { Authorization: `Bearer ${token}` } };
  };

  const fetchCart = async () => {
    try {
      const res = await axios.get('http://localhost:5000/api/v1/cart', getHeaders());
      setCart(res.data.data);
    } catch (error) {
      console.error("Failed to fetch cart", error);
    }
  };

  const addToCart = async (productId, quantity = 1) => {
    if (!customer) return alert("Please login to add to cart");
    try {
      await axios.post('http://localhost:5000/api/v1/cart', { productId, quantity }, getHeaders());
      await fetchCart();
    } catch (error) {
      console.error("Failed to add to cart", error);
      throw error;
    }
  };

  const updateQuantity = async (itemId, quantity) => {
    try {
      await axios.put(`http://localhost:5000/api/v1/cart/${itemId}`, { quantity }, getHeaders());
      await fetchCart();
    } catch (error) {
      console.error("Failed to update quantity", error);
    }
  };

  const removeFromCart = async (itemId) => {
    try {
      await axios.delete(`http://localhost:5000/api/v1/cart/${itemId}`, getHeaders());
      await fetchCart();
    } catch (error) {
      console.error("Failed to remove item", error);
    }
  };

  const clearCart = async () => {
    try {
      await axios.delete(`http://localhost:5000/api/v1/cart`, getHeaders());
      await fetchCart();
    } catch (error) {
      console.error("Failed to clear cart", error);
    }
  };

  return (
    <CartContext.Provider value={{ cart, fetchCart, addToCart, updateQuantity, removeFromCart, clearCart }}>
      {children}
    </CartContext.Provider>
  );
};
