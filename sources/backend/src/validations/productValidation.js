const { body } = require('express-validator');

const createProductValidation = [
  body('name').notEmpty().withMessage('Product name is required'),
  body('categoryId').notEmpty().withMessage('Category ID is required').isInt(),
  body('price').isNumeric().withMessage('Price must be a valid number').custom(value => value >= 0).withMessage('Price must be positive'),
  body('stock').optional().isInt({ min: 0 }).withMessage('Stock must be a non-negative integer'),
  body('isFavorite').optional().isBoolean(),
];

const updateProductValidation = [
  body('name').optional().notEmpty().withMessage('Product name cannot be empty'),
  body('categoryId').optional().isInt(),
  body('price').optional().isNumeric().custom(value => value >= 0),
  body('stock').optional().isInt({ min: 0 }),
  body('isFavorite').optional().isBoolean(),
  body('isActive').optional().isBoolean(),
];

module.exports = {
  createProductValidation,
  updateProductValidation,
};
