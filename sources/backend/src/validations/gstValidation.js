const { body } = require('express-validator');

const createGstValidation = [
  body('branchId').notEmpty().withMessage('Branch ID is required').isInt(),
  body('gstNumber').notEmpty().withMessage('GST Number is required'),
  body('businessName').notEmpty().withMessage('Business Name is required'),
  body('state').optional().isString(),
];

const updateGstValidation = [
  body('gstNumber').optional().notEmpty().withMessage('GST Number cannot be empty'),
  body('businessName').optional().notEmpty().withMessage('Business Name cannot be empty'),
  body('state').optional().isString(),
];

module.exports = {
  createGstValidation,
  updateGstValidation,
};
