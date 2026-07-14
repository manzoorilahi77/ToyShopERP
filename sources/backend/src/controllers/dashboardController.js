const { Sale, SaleItem, Product, User, Purchase, sequelize } = require('../models');
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

    // Fetch today's sales and purchases for charts
    const todaysSales = await Sale.findAll({
      where: { createdAt: { [Op.gte]: today } },
      attributes: ['totalAmount', 'createdAt']
    });

    const todaysPurchases = await Purchase.findAll({
      where: { createdAt: { [Op.gte]: today } },
      attributes: ['totalAmount', 'createdAt']
    });

    // 1. Revenue Analytics (Today) - Cumulative revenue
    let revenueData = [
      { name: '8 AM', total: 0 },
      { name: '10 AM', total: 0 },
      { name: '12 PM', total: 0 },
      { name: '2 PM', total: 0 },
      { name: '4 PM', total: 0 },
      { name: '6 PM', total: 0 },
    ];
    
    const getBucketIndex = (hour) => {
      if (hour < 10) return 0;
      if (hour < 12) return 1;
      if (hour < 14) return 2;
      if (hour < 16) return 3;
      if (hour < 18) return 4;
      return 5;
    };

    let cumulative = 0;
    const bucketTotals = [0, 0, 0, 0, 0, 0];
    for (const sale of todaysSales) {
      const hour = new Date(sale.createdAt).getHours();
      bucketTotals[getBucketIndex(hour)] += parseFloat(sale.totalAmount) || 0;
    }
    for (let i = 0; i < 6; i++) {
      cumulative += bucketTotals[i];
      revenueData[i].total = cumulative;
    }

    // 2. Sales vs Purchases (Morning vs Afternoon)
    let salesData = [
      { name: 'Morning', sales: 0, purchases: 0 },
      { name: 'Afternoon', sales: 0, purchases: 0 }
    ];

    for (const sale of todaysSales) {
      const hour = new Date(sale.createdAt).getHours();
      const amt = parseFloat(sale.totalAmount) || 0;
      if (hour < 12) salesData[0].sales += amt;
      else salesData[1].sales += amt;
    }

    for (const purchase of todaysPurchases) {
      const hour = new Date(purchase.createdAt).getHours();
      const amt = parseFloat(purchase.totalAmount) || 0;
      if (hour < 12) salesData[0].purchases += amt;
      else salesData[1].purchases += amt;
    }

    return successResponse(res, 200, 'Owner dashboard stats', {
      totalRevenue: totalRevenue || 0,
      todayRevenue: todayRevenue || 0,
      activeProducts,
      lowStockProducts,
      revenueData,
      salesData
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

    const myLifetimeSales = await Sale.count({ where: { userId } });
    const myLifetimeRevenue = await Sale.sum('totalAmount', { where: { userId } });
    
    // Fetch user's sale IDs first to avoid Sequelize sum() include bug
    const userSales = await Sale.findAll({ where: { userId }, attributes: ['id'] });
    const saleIds = userSales.map(s => s.id);
    const myLifetimeUnits = await SaleItem.sum('quantity', { where: { saleId: saleIds } });

    const user = await User.findByPk(userId, { attributes: ['points'] });

    return successResponse(res, 200, 'Staff dashboard stats', {
      salesToday: myTodaySales || 0,
      revenueToday: myTodayRevenue || 0,
      points: user ? user.points : 0,
      lifetimeUnits: myLifetimeUnits || 0,
      lifetimeRevenue: myLifetimeRevenue || 0,
    });
  } catch (error) {
    return errorResponse(res, 500, 'Error loading staff dashboard', [error.message]);
  }
};
