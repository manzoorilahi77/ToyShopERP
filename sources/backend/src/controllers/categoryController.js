const { Category } = require('../models');
const { successResponse, errorResponse } = require('../utils/response');

exports.getAllCategories = async (req, res) => {
  try {
    const categories = await Category.findAll();
    return successResponse(res, 200, 'Categories retrieved successfully', categories);
  } catch (error) {
    return errorResponse(res, 500, 'Error retrieving categories', [error.message]);
  }
};

exports.getCategoryById = async (req, res) => {
  try {
    const category = await Category.findByPk(req.params.id);
    if (!category) return errorResponse(res, 404, 'Category not found');
    return successResponse(res, 200, 'Category retrieved successfully', category);
  } catch (error) {
    return errorResponse(res, 500, 'Error retrieving category', [error.message]);
  }
};

exports.createCategory = async (req, res) => {
  try {
    const category = await Category.create(req.body);
    return successResponse(res, 201, 'Category created successfully', category);
  } catch (error) {
    return errorResponse(res, 500, 'Error creating category', [error.message]);
  }
};

exports.updateCategory = async (req, res) => {
  try {
    const category = await Category.findByPk(req.params.id);
    if (!category) return errorResponse(res, 404, 'Category not found');
    await category.update(req.body);
    return successResponse(res, 200, 'Category updated successfully', category);
  } catch (error) {
    return errorResponse(res, 500, 'Error updating category', [error.message]);
  }
};

exports.deleteCategory = async (req, res) => {
  try {
    const category = await Category.findByPk(req.params.id);
    if (!category) return errorResponse(res, 404, 'Category not found');
    await category.destroy();
    return successResponse(res, 200, 'Category deleted successfully');
  } catch (error) {
    return errorResponse(res, 500, 'Error deleting category', [error.message]);
  }
};
