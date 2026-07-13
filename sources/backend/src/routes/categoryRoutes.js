const express = require('express');
const router = express.Router();
const categoryController = require('../controllers/categoryController');
const { createCategoryValidation, updateCategoryValidation } = require('../validations/categoryValidation');
const validate = require('../middleware/validate');
const { authenticate, authorize } = require('../middleware/auth');

router.use(authenticate);

router.get('/', categoryController.getAllCategories);
router.get('/:id', categoryController.getCategoryById);
router.post('/', authorize('Super Admin', 'Owner', 'Manager'), createCategoryValidation, validate, categoryController.createCategory);
router.put('/:id', authorize('Super Admin', 'Owner', 'Manager'), updateCategoryValidation, validate, categoryController.updateCategory);
router.delete('/:id', authorize('Super Admin', 'Owner'), categoryController.deleteCategory);

module.exports = router;
