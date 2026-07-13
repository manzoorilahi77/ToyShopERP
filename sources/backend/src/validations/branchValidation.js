const { body } = require('express-validator');

const createBranchValidation = [
  body('name').notEmpty().withMessage('Branch name is required'),
  body('location').optional().isString(),
  body('contact').optional().isString(),
];

const updateBranchValidation = [
  body('name').optional().notEmpty().withMessage('Branch name cannot be empty'),
  body('location').optional().isString(),
  body('contact').optional().isString(),
  body('isActive').optional().isBoolean(),
];

module.exports = {
  createBranchValidation,
  updateBranchValidation,
};
