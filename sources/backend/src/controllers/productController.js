const { Product, Category } = require('../models');
const { successResponse, errorResponse } = require('../utils/response');

exports.getAllProducts = async (req, res) => {
  try {
    const products = await Product.findAll({
      include: [{ model: Category, as: 'category' }]
    });
    return successResponse(res, 200, 'Products retrieved successfully', products);
  } catch (error) {
    return errorResponse(res, 500, 'Error retrieving products', [error.message]);
  }
};

exports.getProductById = async (req, res) => {
  try {
    const product = await Product.findByPk(req.params.id, {
      include: [{ model: Category, as: 'category' }]
    });
    if (!product) return errorResponse(res, 404, 'Product not found');
    return successResponse(res, 200, 'Product retrieved successfully', product);
  } catch (error) {
    return errorResponse(res, 500, 'Error retrieving product', [error.message]);
  }
};

exports.createProduct = async (req, res) => {
  try {
    const productData = { ...req.body };
    if (req.file) {
      productData.image = `${req.protocol}://${req.get('host')}/uploads/products/${req.file.filename}`;
    } else if (productData.image && typeof productData.image !== 'string') {
      require('fs').appendFileSync(require('path').join(__dirname, '../../error.log'), 'Deleted invalid image field: ' + JSON.stringify(productData.image) + '\\n');
      delete productData.image;
    }
    const product = await Product.create(productData);
    
    if (product.stock > 0 && product.costPrice > 0) {
      const { Purchase, PurchaseItem } = require('../models');
      const purchaseAmount = product.stock * product.costPrice;
      const purchase = await Purchase.create({
        totalAmount: purchaseAmount,
        status: 'completed',
        // Optional: you can add branchId here if req.user has it
      });
      await PurchaseItem.create({
        purchaseId: purchase.id,
        productId: product.id,
        quantity: product.stock,
        costPrice: product.costPrice
      });
    }

    return successResponse(res, 201, 'Product created successfully', product);
  } catch (error) {
    require('fs').appendFileSync(require('path').join(__dirname, '../../error.log'), new Date().toISOString() + '\\n' + error.stack + '\\n');
    return errorResponse(res, 500, 'Error creating product', [error.message]);
  }
};

exports.updateProduct = async (req, res) => {
  try {
    const product = await Product.findByPk(req.params.id);
    if (!product) return errorResponse(res, 404, 'Product not found');
    
    const productData = { ...req.body };
    if (req.file) {
      productData.image = `${req.protocol}://${req.get('host')}/uploads/products/${req.file.filename}`;
    } else if (productData.image && typeof productData.image !== 'string') {
      delete productData.image;
    }
    
    const oldStock = product.stock;
    await product.update(productData);
    
    // Log purchase if stock increased
    if (product.stock > oldStock && product.costPrice > 0) {
      const { Purchase, PurchaseItem } = require('../models');
      const addedStock = product.stock - oldStock;
      const purchaseAmount = addedStock * product.costPrice;
      
      const purchase = await Purchase.create({
        totalAmount: purchaseAmount,
        status: 'completed'
      });
      await PurchaseItem.create({
        purchaseId: purchase.id,
        productId: product.id,
        quantity: addedStock,
        costPrice: product.costPrice
      });
    }

    return successResponse(res, 200, 'Product updated successfully', product);
  } catch (error) {
    return errorResponse(res, 500, 'Error updating product', [error.message]);
  }
};

exports.deleteProduct = async (req, res) => {
  try {
    const product = await Product.findByPk(req.params.id);
    if (!product) return errorResponse(res, 404, 'Product not found');
    await product.destroy({ force: true });
    return successResponse(res, 200, 'Product deleted successfully');
  } catch (error) {
    return errorResponse(res, 500, 'Error deleting product', [error.message]);
  }
};

exports.toggleFavorite = async (req, res) => {
  try {
    const product = await Product.findByPk(req.params.id);
    if (!product) return errorResponse(res, 404, 'Product not found');
    product.isFavorite = !product.isFavorite;
    await product.save();
    return successResponse(res, 200, 'Product favorite status updated', product);
  } catch (error) {
    return errorResponse(res, 500, 'Error updating favorite status', [error.message]);
  }
};
