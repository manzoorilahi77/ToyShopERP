const express = require('express');
const router = express.Router();
const customerController = require('../controllers/customerController');
const { authenticateCustomer } = require('../middleware/auth');

router.post('/register', customerController.register);
router.post('/login', customerController.login);

router.use(authenticateCustomer);

router.get('/profile', customerController.getProfile);
router.put('/profile', customerController.updateProfile);
router.get('/addresses', customerController.getAddresses);
router.post('/addresses', customerController.addAddress);
router.delete('/addresses/:id', customerController.deleteAddress);

module.exports = router;
