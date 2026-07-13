const express = require('express');
const router = express.Router();
const purchaseController = require('../controllers/purchaseController');
const { createPurchaseValidation } = require('../validations/purchaseValidation');
const validate = require('../middleware/validate');
const { authenticate, authorize } = require('../middleware/auth');

router.use(authenticate);

router.get('/', authorize('Super Admin', 'Owner', 'Manager'), purchaseController.getAllPurchases);
router.get('/:id', authorize('Super Admin', 'Owner', 'Manager'), purchaseController.getPurchaseById);
router.post('/', authorize('Super Admin', 'Owner', 'Manager'), createPurchaseValidation, validate, purchaseController.createPurchase);

module.exports = router;
