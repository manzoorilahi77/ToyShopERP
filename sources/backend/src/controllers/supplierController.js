const { Supplier } = require('../models');
const { successResponse, errorResponse } = require('../utils/response');

exports.getAllSuppliers = async (req, res) => {
  try {
    const suppliers = await Supplier.findAll();
    return successResponse(res, 200, 'Suppliers retrieved successfully', suppliers);
  } catch (error) {
    return errorResponse(res, 500, 'Error retrieving suppliers', [error.message]);
  }
};

exports.getSupplierById = async (req, res) => {
  try {
    const supplier = await Supplier.findByPk(req.params.id);
    if (!supplier) return errorResponse(res, 404, 'Supplier not found');
    return successResponse(res, 200, 'Supplier retrieved successfully', supplier);
  } catch (error) {
    return errorResponse(res, 500, 'Error retrieving supplier', [error.message]);
  }
};

exports.createSupplier = async (req, res) => {
  try {
    const supplier = await Supplier.create(req.body);
    return successResponse(res, 201, 'Supplier created successfully', supplier);
  } catch (error) {
    return errorResponse(res, 500, 'Error creating supplier', [error.message]);
  }
};

exports.updateSupplier = async (req, res) => {
  try {
    const supplier = await Supplier.findByPk(req.params.id);
    if (!supplier) return errorResponse(res, 404, 'Supplier not found');
    await supplier.update(req.body);
    return successResponse(res, 200, 'Supplier updated successfully', supplier);
  } catch (error) {
    return errorResponse(res, 500, 'Error updating supplier', [error.message]);
  }
};

exports.deleteSupplier = async (req, res) => {
  try {
    const supplier = await Supplier.findByPk(req.params.id);
    if (!supplier) return errorResponse(res, 404, 'Supplier not found');
    await supplier.destroy();
    return successResponse(res, 200, 'Supplier deleted successfully');
  } catch (error) {
    return errorResponse(res, 500, 'Error deleting supplier', [error.message]);
  }
};
