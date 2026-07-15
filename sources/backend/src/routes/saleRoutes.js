const express = require('express');
const router = express.Router();
const saleController = require('../controllers/saleController');
const { createSaleValidation } = require('../validations/saleValidation');
const validate = require('../middleware/validate');
const { authenticate, authorize } = require('../middleware/auth');

router.use(authenticate);

router.get('/my-sales', authorize('Staff', 'Online Sales', 'Manager', 'Owner'), saleController.getMySales);
router.get('/online-orders', authorize('Super Admin', 'Owner', 'Manager', 'Online Sales'), saleController.getOnlineOrders);
router.put('/online-orders/:id/status', authorize('Super Admin', 'Owner', 'Manager', 'Online Sales'), saleController.updateOnlineOrderStatus);
router.get('/', authorize('Super Admin', 'Owner', 'Manager', 'Staff', 'Online Sales'), saleController.getAllSales);
router.get('/:id', authorize('Super Admin', 'Owner', 'Manager', 'Staff', 'Online Sales'), saleController.getSaleById);
router.post('/', authorize('Super Admin', 'Owner', 'Manager', 'Staff', 'Online Sales'), createSaleValidation, validate, saleController.createSale);


module.exports = router;
