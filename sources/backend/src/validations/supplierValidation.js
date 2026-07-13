const { body } = require('express-validator');

const createSupplierValidation = [
  body('name').notEmpty().withMessage('Supplier name is required'),
  body('contact').optional().isString(),
  body('gstNumber').optional().isString(),
];

const updateSupplierValidation = [
  body('name').optional().notEmpty().withMessage('Supplier name cannot be empty'),
  body('contact').optional().isString(),
  body('gstNumber').optional().isString(),
  body('isActive').optional().isBoolean(),
];

module.exports = {
  createSupplierValidation,
  updateSupplierValidation,
};
