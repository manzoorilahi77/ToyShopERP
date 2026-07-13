const { Branch } = require('../models');
const { successResponse, errorResponse } = require('../utils/response');

exports.getAllBranches = async (req, res) => {
  try {
    const branches = await Branch.findAll();
    return successResponse(res, 200, 'Branches retrieved successfully', branches);
  } catch (error) {
    return errorResponse(res, 500, 'Error retrieving branches', [error.message]);
  }
};

exports.getBranchById = async (req, res) => {
  try {
    const branch = await Branch.findByPk(req.params.id);
    if (!branch) return errorResponse(res, 404, 'Branch not found');
    return successResponse(res, 200, 'Branch retrieved successfully', branch);
  } catch (error) {
    return errorResponse(res, 500, 'Error retrieving branch', [error.message]);
  }
};

exports.createBranch = async (req, res) => {
  try {
    const branch = await Branch.create(req.body);
    return successResponse(res, 201, 'Branch created successfully', branch);
  } catch (error) {
    return errorResponse(res, 500, 'Error creating branch', [error.message]);
  }
};

exports.updateBranch = async (req, res) => {
  try {
    const branch = await Branch.findByPk(req.params.id);
    if (!branch) return errorResponse(res, 404, 'Branch not found');
    await branch.update(req.body);
    return successResponse(res, 200, 'Branch updated successfully', branch);
  } catch (error) {
    return errorResponse(res, 500, 'Error updating branch', [error.message]);
  }
};

exports.deleteBranch = async (req, res) => {
  try {
    const branch = await Branch.findByPk(req.params.id);
    if (!branch) return errorResponse(res, 404, 'Branch not found');
    await branch.destroy();
    return successResponse(res, 200, 'Branch deleted successfully');
  } catch (error) {
    return errorResponse(res, 500, 'Error deleting branch', [error.message]);
  }
};
