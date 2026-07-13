const { body } = require('express-validator');

const createPurchaseValidation = [
  body('branchId').notEmpty().withMessage('Branch ID is required').isInt(),
  body('supplierId').notEmpty().withMessage('Supplier ID is required').isInt(),
  body('items').isArray({ min: 1 }).withMessage('At least one item is required'),
  body('items.*.productId').notEmpty().withMessage('Product ID is required').isInt(),
  body('items.*.quantity').notEmpty().isInt({ min: 1 }).withMessage('Quantity must be at least 1'),
  body('items.*.costPrice').notEmpty().isNumeric().withMessage('Cost price is required'),
];

module.exports = {
  createPurchaseValidation,
};
