const jwt = require('jsonwebtoken');
require('dotenv').config();

const generateAccessToken = (user) => {
  return jwt.sign(
    { id: user.id, role: user.role?.name, branchId: user.branchId },
    process.env.JWT_SECRET || 'supersecretkey',
    { expiresIn: process.env.JWT_EXPIRES_IN || '1h' }
  );
};

const generateRefreshToken = (user) => {
  return jwt.sign(
    { id: user.id },
    process.env.JWT_REFRESH_SECRET || 'superrefreshsecretkey',
    { expiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d' }
  );
};

const verifyToken = (token, isRefresh = false) => {
  const secret = isRefresh
    ? (process.env.JWT_REFRESH_SECRET || 'superrefreshsecretkey')
    : (process.env.JWT_SECRET || 'supersecretkey');
  return jwt.verify(token, secret);
};

module.exports = {
  generateAccessToken,
  generateRefreshToken,
  verifyToken,
};
