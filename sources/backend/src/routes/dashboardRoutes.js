const express = require('express');
const router = express.Router();
const dashboardController = require('../controllers/dashboardController');
const { authenticate, authorize } = require('../middleware/auth');

router.use(authenticate);

router.get('/owner', authorize('Super Admin', 'Owner', 'Manager'), dashboardController.getOwnerDashboard);
router.get('/staff', authorize('Staff'), dashboardController.getStaffDashboard);

module.exports = router;
