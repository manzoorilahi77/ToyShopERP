const { Sale, Product, User, sequelize } = require('../models');
const { successResponse, errorResponse } = require('../utils/response');
const { Op } = require('sequelize');

exports.getOwnerDashboard = async (req, res) => {
  try {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const totalRevenue = await Sale.sum('totalAmount');
    const todayRevenue = await Sale.sum('totalAmount', {
      where: { createdAt: { [Op.gte]: today } }
    });

    const activeProducts = await Product.count({ where: { isActive: true } });
    const lowStockProducts = await Product.count({ where: { stock: { [Op.lt]: 10 } } });

    return successResponse(res, 200, 'Owner dashboard stats', {
      totalRevenue: totalRevenue || 0,
      todayRevenue: todayRevenue || 0,
      activeProducts,
      lowStockProducts,
    });
  } catch (error) {
    return errorResponse(res, 500, 'Error loading owner dashboard', [error.message]);
  }
};

exports.getStaffDashboard = async (req, res) => {
  try {
    const userId = req.user.id;
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const myTodaySales = await Sale.count({
      where: { userId, createdAt: { [Op.gte]: today } }
    });

    const myTodayRevenue = await Sale.sum('totalAmount', {
      where: { userId, createdAt: { [Op.gte]: today } }
    });

    const user = await User.findByPk(userId, { attributes: ['points'] });

    return successResponse(res, 200, 'Staff dashboard stats', {
      salesToday: myTodaySales || 0,
      revenueToday: myTodayRevenue || 0,
      points: user ? user.points : 0,
    });
  } catch (error) {
    return errorResponse(res, 500, 'Error loading staff dashboard', [error.message]);
  }
};
