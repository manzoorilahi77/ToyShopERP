import api from './api';

export const getStaffDashboard = async () => {
  const response = await api.get('/dashboard/staff');
  return response.data;
};

export const getOwnerDashboard = async (params) => {
  const response = await api.get('/dashboard/owner', { params });
  return response.data;
};

export const getLeaderboard = async () => {
  const response = await api.get('/users/leaderboard');
  return response.data;
};
