const express = require('express');
const router = express.Router();
const onlineOrderController = require('../controllers/onlineOrderController');
const { authenticateCustomer } = require('../middleware/auth');

router.use(authenticateCustomer);

router.post('/', onlineOrderController.placeOrder);
router.get('/', onlineOrderController.getOrderHistory);
router.get('/:orderId', onlineOrderController.getOrderDetails);

module.exports = router;
