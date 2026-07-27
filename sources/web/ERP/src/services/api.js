import axios from 'axios';
import useAuthStore from '../store/authStore';

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:5000/api/v1';

const api = axios.create({
  baseURL: API_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor for API calls
api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('accessToken');
    if (token) {
      config.headers['Authorization'] = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Function to replace localhost URLs with the current API origin
const fixUrls = (obj) => {
  if (typeof obj === 'string') {
    const isProd = window.location.hostname !== 'localhost' && window.location.hostname !== '127.0.0.1';
    const baseUrl = isProd ? window.location.origin : 'http://localhost:6008';
    return obj.replace(/http:\/\/(localhost|127\.0\.0\.1|10\.0\.2\.2)(:\d+)?/g, baseUrl);
  } else if (Array.isArray(obj)) {
    return obj.map(fixUrls);
  } else if (obj !== null && typeof obj === 'object') {
    const newObj = {};
    for (const key in obj) {
      newObj[key] = fixUrls(obj[key]);
    }
    return newObj;
  }
  return obj;
};

// Response interceptor for API calls
api.interceptors.response.use(
  (response) => {
    if (response.data) {
      response.data = fixUrls(response.data);
    }
    return response;
  },
  async (error) => {
    const originalRequest = error.config;
    // Prevent infinite loops
    if (error.response?.status === 401 && originalRequest.url === '/auth/refresh-token') {
      useAuthStore.getState().logout();
      return Promise.reject(error);
    }

    if (error.response?.status === 401 && !originalRequest._retry) {
      originalRequest._retry = true;
      const refreshToken = localStorage.getItem('refreshToken');
      
      if (refreshToken) {
        try {
          const res = await axios.post(`${API_URL}/auth/refresh-token`, { token: refreshToken });
          if (res.data?.data?.accessToken) {
            localStorage.setItem('accessToken', res.data.data.accessToken);
            localStorage.setItem('refreshToken', res.data.data.refreshToken);
            
            // Re-run the original request with new token
            originalRequest.headers['Authorization'] = `Bearer ${res.data.data.accessToken}`;
            return api(originalRequest);
          }
        } catch (err) {
          useAuthStore.getState().logout();
          return Promise.reject(err);
        }
      } else {
        useAuthStore.getState().logout();
      }
    }
    return Promise.reject(error);
  }
);

export default api;
