const { GstRegistration, Branch } = require('../models');
const { successResponse, errorResponse } = require('../utils/response');

exports.getAllGstRegistrations = async (req, res) => {
  try {
    const registrations = await GstRegistration.findAll({
      include: [{ model: Branch, as: 'branch' }]
    });
    return successResponse(res, 200, 'GST registrations retrieved successfully', registrations);
  } catch (error) {
    return errorResponse(res, 500, 'Error retrieving GST registrations', [error.message]);
  }
};

exports.getGstById = async (req, res) => {
  try {
    const registration = await GstRegistration.findByPk(req.params.id, {
      include: [{ model: Branch, as: 'branch' }]
    });
    if (!registration) return errorResponse(res, 404, 'GST registration not found');
    return successResponse(res, 200, 'GST registration retrieved successfully', registration);
  } catch (error) {
    return errorResponse(res, 500, 'Error retrieving GST registration', [error.message]);
  }
};

exports.createGst = async (req, res) => {
  try {
    const existing = await GstRegistration.findOne({ where: { branchId: req.body.branchId } });
    if (existing) {
      return errorResponse(res, 400, 'Branch already has a GST registration');
    }

    const registration = await GstRegistration.create(req.body);
    return successResponse(res, 201, 'GST registration created successfully', registration);
  } catch (error) {
    return errorResponse(res, 500, 'Error creating GST registration', [error.message]);
  }
};

exports.updateGst = async (req, res) => {
  try {
    const registration = await GstRegistration.findByPk(req.params.id);
    if (!registration) return errorResponse(res, 404, 'GST registration not found');
    await registration.update(req.body);
    return successResponse(res, 200, 'GST registration updated successfully', registration);
  } catch (error) {
    return errorResponse(res, 500, 'Error updating GST registration', [error.message]);
  }
};

exports.deleteGst = async (req, res) => {
  try {
    const registration = await GstRegistration.findByPk(req.params.id);
    if (!registration) return errorResponse(res, 404, 'GST registration not found');
    await registration.destroy();
    return successResponse(res, 200, 'GST registration deleted successfully');
  } catch (error) {
    return errorResponse(res, 500, 'Error deleting GST registration', [error.message]);
  }
};
