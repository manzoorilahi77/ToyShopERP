import api from './api';

export const getCatalog = async () => {
  const response = await api.get('/products');
  return response.data;
};

export const getCategories = async () => {
  const response = await api.get('/categories');
  return response.data;
};

export const toggleFavorite = async (id) => {
  const response = await api.patch(`/products/${id}/favorite`);
  return response.data;
};

export const createProduct = async (productData) => {
  const response = await api.post('/products', productData);
  return response.data;
};
