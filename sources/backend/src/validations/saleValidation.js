const { body } = require('express-validator');

const createSaleValidation = [
  body('branchId').notEmpty().withMessage('Branch ID is required').isInt(),
  body('items').isArray({ min: 1 }).withMessage('At least one item is required in the sale'),
  body('items.*.productId').notEmpty().withMessage('Product ID is required for each item').isInt(),
  body('items.*.quantity').notEmpty().isInt({ min: 1 }).withMessage('Quantity must be at least 1'),
  body('paymentMethod').optional().isIn(['cash', 'card', 'upi']).withMessage('Invalid payment method'),
];

module.exports = {
  createSaleValidation,
};
