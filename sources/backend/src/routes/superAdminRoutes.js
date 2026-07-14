const express = require('express');
const router = express.Router();
const superAdminController = require('../controllers/superAdminController');

router.get('/dashboard', superAdminController.getDashboardStats);
router.get('/tenants', superAdminController.getTenants);
router.get('/staff', superAdminController.getGlobalStaff);
router.get('/stock', superAdminController.getGlobalStock);
router.get('/subscriptions', superAdminController.getSubscriptions);
router.get('/logs', superAdminController.getSystemLogs);

module.exports = router;
