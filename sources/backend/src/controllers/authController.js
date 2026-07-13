const bcrypt = require('bcrypt');
const { User, Role } = require('../models');
const { generateAccessToken, generateRefreshToken, verifyToken } = require('../utils/jwt');
const { successResponse, errorResponse } = require('../utils/response');

const login = async (req, res) => {
  try {
    const { email, password } = req.body;

    const user = await User.scope('withPassword').findOne({
      where: { email },
      include: [{ model: Role, as: 'role' }],
    });

    if (!user || !user.isActive) {
      return errorResponse(res, 401, 'Invalid credentials or account inactive');
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return errorResponse(res, 401, 'Invalid credentials');
    }

    const accessToken = generateAccessToken(user);
    const refreshToken = generateRefreshToken(user);

    // Remove password from response
    const userData = user.toJSON();
    delete userData.password;

    return successResponse(res, 200, 'Login successful', {
      user: userData,
      accessToken,
      refreshToken,
    });
  } catch (error) {
    console.error('Login error:', error);
    return errorResponse(res, 500, 'Internal server error');
  }
};

const refreshToken = async (req, res) => {
  try {
    const { token } = req.body;

    let decoded;
    try {
      decoded = verifyToken(token, true);
    } catch (err) {
      return errorResponse(res, 401, 'Invalid or expired refresh token');
    }

    const user = await User.findByPk(decoded.id, {
      include: [{ model: Role, as: 'role' }],
    });

    if (!user || !user.isActive) {
      return errorResponse(res, 401, 'User not found or inactive');
    }

    const newAccessToken = generateAccessToken(user);
    const newRefreshToken = generateRefreshToken(user);

    return successResponse(res, 200, 'Token refreshed', {
      accessToken: newAccessToken,
      refreshToken: newRefreshToken,
    });
  } catch (error) {
    console.error('Refresh token error:', error);
    return errorResponse(res, 500, 'Internal server error');
  }
};

const resetPassword = async (req, res) => {
  try {
    const { oldPassword, newPassword } = req.body;
    const userId = req.user.id; // set by authenticate middleware

    const user = await User.scope('withPassword').findByPk(userId);
    if (!user) {
      return errorResponse(res, 404, 'User not found');
    }

    const isMatch = await bcrypt.compare(oldPassword, user.password);
    if (!isMatch) {
      return errorResponse(res, 400, 'Incorrect old password');
    }

    const hashedPassword = await bcrypt.hash(newPassword, 10);
    user.password = hashedPassword;
    await user.save();

    return successResponse(res, 200, 'Password updated successfully');
  } catch (error) {
    console.error('Reset password error:', error);
    return errorResponse(res, 500, 'Internal server error');
  }
};

const getPublicUsers = async (req, res) => {
  try {
    const users = await User.findAll({
      attributes: ['id', 'name', 'email'],
      include: [{ model: Role, as: 'role', attributes: ['name'] }],
      where: { isActive: true }
    });

    // Map to frontend expected format
    const formattedUsers = users.map(user => {
      const names = user.name.split(' ');
      const initials = names.length > 1 ? names[0][0] + names[1][0] : names[0][0];
      return {
        id: user.id,
        name: user.name,
        email: user.email,
        initials: initials.toUpperCase(),
        colorClass: 'bg-blue-600', // We can randomize or store this in DB later
        role: user.role?.name?.toLowerCase().replace(' ', '_') || 'staff'
      };
    });

    return successResponse(res, 200, 'Users retrieved successfully', formattedUsers);
  } catch (error) {
    console.error('Error fetching public users:', error);
    return errorResponse(res, 500, 'Internal server error');
  }
};

const logout = async (req, res) => {
  return successResponse(res, 200, 'Logged out successfully');
};

module.exports = {
  login,
  refreshToken,
  resetPassword,
  logout,
  getPublicUsers,
};
