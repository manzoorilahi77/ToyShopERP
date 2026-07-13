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
    const product = await Product.create(req.body);
    return successResponse(res, 201, 'Product created successfully', product);
  } catch (error) {
    return errorResponse(res, 500, 'Error creating product', [error.message]);
  }
};

exports.updateProduct = async (req, res) => {
  try {
    const product = await Product.findByPk(req.params.id);
    if (!product) return errorResponse(res, 404, 'Product not found');
    await product.update(req.body);
    return successResponse(res, 200, 'Product updated successfully', product);
  } catch (error) {
    return errorResponse(res, 500, 'Error updating product', [error.message]);
  }
};

exports.deleteProduct = async (req, res) => {
  try {
    const product = await Product.findByPk(req.params.id);
    if (!product) return errorResponse(res, 404, 'Product not found');
    await product.destroy();
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
