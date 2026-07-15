const express = require('express');
const router = express.Router();
const cartController = require('../controllers/cartController');
const { authenticateCustomer } = require('../middleware/auth');

router.use(authenticateCustomer);

router.get('/', cartController.getCart);
router.post('/', cartController.addToCart);
router.put('/:itemId', cartController.updateCartItem);
router.delete('/:itemId', cartController.removeFromCart);
router.delete('/', cartController.clearCart);

module.exports = router;
