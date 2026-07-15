const express = require('express');
const router = express.Router();
const productController = require('../controllers/productController');
const { createProductValidation, updateProductValidation } = require('../validations/productValidation');
const validate = require('../middleware/validate');
const { authenticate, authorize } = require('../middleware/auth');
const upload = require('../middleware/upload');

router.use(authenticate);

router.get('/', productController.getAllProducts);
router.get('/low-stock', productController.getLowStockProducts);
router.get('/:id', productController.getProductById);
router.post('/', authorize('Super Admin', 'Owner', 'Manager'), upload.single('image'), createProductValidation, validate, productController.createProduct);
router.put('/:id', authorize('Super Admin', 'Owner', 'Manager'), upload.single('image'), updateProductValidation, validate, productController.updateProduct);
router.delete('/:id', authorize('Super Admin', 'Owner'), productController.deleteProduct);
router.patch('/:id/favorite', authorize('Super Admin', 'Owner', 'Manager', 'Staff'), productController.toggleFavorite);

module.exports = router;
