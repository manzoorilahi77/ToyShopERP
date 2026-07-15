import React, { createContext, useState, useEffect } from 'react';
import axios from 'axios';

export const AuthContext = createContext();

export const AuthProvider = ({ children }) => {
  const [customer, setCustomer] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchProfile = async () => {
      const token = localStorage.getItem('customerToken');
      if (token) {
        try {
          const res = await axios.get('http://localhost:5000/api/v1/customers/profile', {
            headers: { Authorization: `Bearer ${token}` }
          });
          setCustomer(res.data.data);
        } catch (error) {
          console.error("Failed to fetch profile", error);
          localStorage.removeItem('customerToken');
        }
      }
      setLoading(false);
    };
    fetchProfile();
  }, []);

  const login = async (email, password) => {
    const res = await axios.post('http://localhost:5000/api/v1/customers/login', { email, password });
    const { token, customer } = res.data.data;
    localStorage.setItem('customerToken', token);
    setCustomer(customer);
    return customer;
  };

  const register = async (name, email, password, phone) => {
    const res = await axios.post('http://localhost:5000/api/v1/customers/register', { name, email, password, phone });
    const { token, customer } = res.data.data;
    localStorage.setItem('customerToken', token);
    setCustomer(customer);
    return customer;
  };

  const logout = () => {
    localStorage.removeItem('customerToken');
    setCustomer(null);
  };

  return (
    <AuthContext.Provider value={{ customer, loading, login, register, logout, setCustomer }}>
      {children}
    </AuthContext.Provider>
  );
};
