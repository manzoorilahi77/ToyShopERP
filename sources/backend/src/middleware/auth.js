const { verifyToken } = require('../utils/jwt');
const { errorResponse } = require('../utils/response');

const authenticate = (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return errorResponse(res, 401, 'Unauthorized access. Token not provided.');
    }

    const token = authHeader.split(' ')[1];
    const decoded = verifyToken(token);
    
    req.user = decoded; // { id, role, branchId }
    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return errorResponse(res, 401, 'Token expired');
    }
    return errorResponse(res, 401, 'Invalid token');
  }
};

const authenticateCustomer = (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return errorResponse(res, 401, 'Unauthorized access. Token not provided.');
    }

    const token = authHeader.split(' ')[1];
    const decoded = verifyToken(token);
    
    if (decoded.type !== 'customer') {
      return errorResponse(res, 403, 'Forbidden. Only customers can access this resource.');
    }

    req.user = decoded; // { id, type }
    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return errorResponse(res, 401, 'Token expired');
    }
    return errorResponse(res, 401, 'Invalid token');
  }
};

const authorize = (...roles) => {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return errorResponse(res, 403, 'Forbidden. You do not have access to this resource.');
    }
    next();
  };
};

module.exports = {
  authenticate,
  authenticateCustomer,
  authorize,
};
