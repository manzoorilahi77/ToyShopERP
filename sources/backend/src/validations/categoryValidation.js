const { body } = require('express-validator');

const createCategoryValidation = [
  body('name').notEmpty().withMessage('Category name is required'),
  body('icon').optional().isString(),
  body('color').optional().isString(),
];

const updateCategoryValidation = [
  body('name').optional().notEmpty().withMessage('Category name cannot be empty'),
  body('icon').optional().isString(),
  body('color').optional().isString(),
];

module.exports = {
  createCategoryValidation,
  updateCategoryValidation,
};
