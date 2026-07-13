const { body } = require('express-validator');

const createUserValidation = [
  body('name').notEmpty().withMessage('Name is required'),
  body('email').isEmail().withMessage('Valid email is required'),
  body('password').isLength({ min: 6 }).withMessage('Password must be at least 6 characters'),
  body('roleId').notEmpty().withMessage('Role ID is required'),
];

const updateUserValidation = [
  body('name').optional().notEmpty().withMessage('Name cannot be empty'),
  body('email').optional().isEmail().withMessage('Valid email is required'),
  body('roleId').optional().isInt(),
  body('branchId').optional().isInt(),
  body('isActive').optional().isBoolean(),
];

module.exports = {
  createUserValidation,
  updateUserValidation,
};
