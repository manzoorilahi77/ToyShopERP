import api from './api';

export const createSale = async (saleData) => {
  const response = await api.post('/sales', saleData);
  return response.data;
};

export const getSalesHistory = async () => {
  const response = await api.get('/sales');
  return response.data;
};

export const getMySales = async () => {
  const response = await api.get('/sales/my-sales');
  return response.data;
};

export const getSaleById = async (id) => {
  const response = await api.get(`/sales/${id}`);
  return response.data;
};

