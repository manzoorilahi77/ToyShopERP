const express = require('express');
const router = express.Router();
const supplierController = require('../controllers/supplierController');
const { createSupplierValidation, updateSupplierValidation } = require('../validations/supplierValidation');
const validate = require('../middleware/validate');
const { authenticate, authorize } = require('../middleware/auth');

router.use(authenticate);

router.get('/', authorize('Super Admin', 'Owner', 'Manager'), supplierController.getAllSuppliers);
router.get('/:id', authorize('Super Admin', 'Owner', 'Manager'), supplierController.getSupplierById);
router.post('/', authorize('Super Admin', 'Owner'), createSupplierValidation, validate, supplierController.createSupplier);
router.put('/:id', authorize('Super Admin', 'Owner'), updateSupplierValidation, validate, supplierController.updateSupplier);
router.delete('/:id', authorize('Super Admin', 'Owner'), supplierController.deleteSupplier);

module.exports = router;
