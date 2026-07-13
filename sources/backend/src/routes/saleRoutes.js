const express = require('express');
const router = express.Router();
const saleController = require('../controllers/saleController');
const { createSaleValidation } = require('../validations/saleValidation');
const validate = require('../middleware/validate');
const { authenticate, authorize } = require('../middleware/auth');

router.use(authenticate);

router.get('/', authorize('Super Admin', 'Owner', 'Manager', 'Staff'), saleController.getAllSales);
router.get('/:id', authorize('Super Admin', 'Owner', 'Manager', 'Staff'), saleController.getSaleById);
router.post('/', authorize('Super Admin', 'Owner', 'Manager', 'Staff'), createSaleValidation, validate, saleController.createSale);

module.exports = router;
