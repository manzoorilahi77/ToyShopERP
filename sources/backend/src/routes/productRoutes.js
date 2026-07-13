const express = require('express');
const router = express.Router();
const productController = require('../controllers/productController');
const { createProductValidation, updateProductValidation } = require('../validations/productValidation');
const validate = require('../middleware/validate');
const { authenticate, authorize } = require('../middleware/auth');

router.use(authenticate);

router.get('/', productController.getAllProducts);
router.get('/:id', productController.getProductById);
router.post('/', authorize('Super Admin', 'Owner', 'Manager'), createProductValidation, validate, productController.createProduct);
router.put('/:id', authorize('Super Admin', 'Owner', 'Manager'), updateProductValidation, validate, productController.updateProduct);
router.delete('/:id', authorize('Super Admin', 'Owner'), productController.deleteProduct);
router.patch('/:id/favorite', authorize('Super Admin', 'Owner', 'Manager', 'Staff'), productController.toggleFavorite);

module.exports = router;
