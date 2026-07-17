const express = require('express');
const router = express.Router();
const reportController = require('../controllers/reportController');

router.get('/sales-summary', reportController.getSalesSummary);
router.get('/top-products', reportController.getTopProducts);
router.get('/top-staff', reportController.getTopStaff);
router.get('/category-mix', reportController.getCategoryMix);
router.get('/aging-stock', reportController.getAgingStock);
router.get('/low-stock', reportController.getLowStock);
router.get('/gst-snapshot', reportController.getGstSnapshot);

module.exports = router;
