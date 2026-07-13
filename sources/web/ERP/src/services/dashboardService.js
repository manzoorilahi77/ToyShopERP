import api from './api';

export const getStaffDashboard = async () => {
  const response = await api.get('/dashboard/staff');
  return response.data;
};

export const getOwnerDashboard = async () => {
  const response = await api.get('/dashboard/owner');
  return response.data;
};

export const getLeaderboard = async () => {
  const response = await api.get('/users/leaderboard');
  return response.data;
};
