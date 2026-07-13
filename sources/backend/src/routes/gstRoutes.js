const express = require('express');
const router = express.Router();
const gstController = require('../controllers/gstController');
const { createGstValidation, updateGstValidation } = require('../validations/gstValidation');
const validate = require('../middleware/validate');
const { authenticate, authorize } = require('../middleware/auth');

router.use(authenticate);

router.get('/', authorize('Super Admin', 'Owner', 'Manager'), gstController.getAllGstRegistrations);
router.get('/:id', authorize('Super Admin', 'Owner', 'Manager'), gstController.getGstById);
router.post('/', authorize('Super Admin', 'Owner'), createGstValidation, validate, gstController.createGst);
router.put('/:id', authorize('Super Admin', 'Owner'), updateGstValidation, validate, gstController.updateGst);
router.delete('/:id', authorize('Super Admin', 'Owner'), gstController.deleteGst);

module.exports = router;
