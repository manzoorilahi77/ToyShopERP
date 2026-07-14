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
  const isFormData = productData instanceof FormData;
  const config = isFormData ? { headers: { 'Content-Type': 'multipart/form-data' } } : {};
  const response = await api.post('/products', productData, config);
  return response.data;
};

export const updateProduct = async (id, productData) => {
  const isFormData = productData instanceof FormData;
  const config = isFormData ? { headers: { 'Content-Type': 'multipart/form-data' } } : {};
  const response = await api.put(`/products/${id}`, productData, config);
  return response.data;
};

export const deleteProduct = async (id) => {
  const response = await api.delete(`/products/${id}`);
  return response.data;
};
