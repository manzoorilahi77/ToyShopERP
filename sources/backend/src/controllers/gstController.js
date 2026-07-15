const { GstRegistration, Branch, Sale, Purchase } = require('../models');
const { Op } = require('sequelize');
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

exports.getDashboardData = async (req, res) => {
  try {
    const startOfMonth = new Date();
    startOfMonth.setDate(1);
    startOfMonth.setHours(0, 0, 0, 0);

    const sales = await Sale.findAll({
      where: {
        createdAt: { [Op.gte]: startOfMonth },
        status: 'completed'
      }
    });

    const purchases = await Purchase.findAll({
      where: {
        createdAt: { [Op.gte]: startOfMonth },
        status: 'completed'
      }
    });

    const totalSales = sales.reduce((sum, sale) => sum + Number(sale.totalAmount || 0), 0);
    const outputGst = sales.reduce((sum, sale) => sum + Number(sale.cgst || 0) + Number(sale.sgst || 0) + Number(sale.igst || 0), 0);
    
    const inputGst = purchases.reduce((sum, purchase) => sum + Number(purchase.cgst || 0) + Number(purchase.sgst || 0) + Number(purchase.igst || 0), 0);
    const netGstPayable = outputGst - inputGst;

    const dashboardData = {
      totalSales,
      outputGst,
      inputGst,
      netGstPayable: netGstPayable > 0 ? netGstPayable : 0,
      pendingItc: netGstPayable < 0 ? Math.abs(netGstPayable) : 0,
    };

    return successResponse(res, 200, 'GST dashboard data retrieved successfully', dashboardData);
  } catch (error) {
    return errorResponse(res, 500, 'Error retrieving GST dashboard data', [error.message]);
  }
};

exports.getReportsData = async (req, res) => {
  try {
    // For now, a simple report structure
    const sales = await Sale.findAll({
      where: { status: 'completed' },
      order: [['createdAt', 'DESC']]
    });

    const reportsData = {
      sales
    };

    return successResponse(res, 200, 'GST reports data retrieved successfully', reportsData);
  } catch (error) {
    return errorResponse(res, 500, 'Error retrieving GST reports data', [error.message]);
  }
};
