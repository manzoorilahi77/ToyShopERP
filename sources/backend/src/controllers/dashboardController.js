const { Sale, SaleItem, Product, User, Purchase, Notification, sequelize } = require('../models');
const { successResponse, errorResponse } = require('../utils/response');
const { Op } = require('sequelize');
const dashboardService = require('../services/dashboardService');

exports.getOwnerDashboard = async (req, res) => {
  try {
    const period = req.query.period || 'Today';
    let startDate = new Date();
    startDate.setHours(0, 0, 0, 0);
    let endDate = new Date(startDate);
    endDate.setDate(endDate.getDate() + 1);

    if (period === 'Yesterday') {
      startDate.setDate(startDate.getDate() - 1);
      endDate.setDate(endDate.getDate() - 1);
    } else if (period === 'Last 7 Days') {
      startDate.setDate(startDate.getDate() - 7);
    } else if (period === 'This Month') {
      startDate.setDate(1);
    } else if (/^\d{4}-\d{2}-\d{2}$/.test(period)) {
      // Specific Date YYYY-MM-DD
      startDate = new Date(period);
      startDate.setHours(0, 0, 0, 0);
      endDate = new Date(startDate);
      endDate.setDate(endDate.getDate() + 1);
    } else if (/^\d{4}-\d{2}$/.test(period)) {
      // Specific Month YYYY-MM
      startDate = new Date(`${period}-01`);
      startDate.setHours(0, 0, 0, 0);
      endDate = new Date(startDate);
      endDate.setMonth(endDate.getMonth() + 1);
    }

    const dateFilter = {
      [Op.gte]: startDate,
      [Op.lt]: endDate
    };

    const branchId = req.query.branchId;
    const branchFilter = (branchId && branchId !== 'all') ? { branchId } : {};

    const totalRevenue = await Sale.sum('totalAmount', { where: branchFilter });
    const todayRevenue = await Sale.sum('totalAmount', {
      where: { ...branchFilter, createdAt: dateFilter }
    });

    const onlineRevenue = await Sale.sum('totalAmount', { where: { ...branchFilter, createdAt: dateFilter, orderType: 'online' } });
    const offlineRevenue = await Sale.sum('totalAmount', { where: { ...branchFilter, createdAt: dateFilter, orderType: 'offline' } });

    const todayOrders = await Sale.count({
      where: { ...branchFilter, createdAt: dateFilter }
    });
    
    const todayOnlineOrders = await Sale.count({
      where: { ...branchFilter, createdAt: dateFilter, orderType: 'online' }
    });
    
    const todayOfflineOrders = await Sale.count({
      where: { ...branchFilter, createdAt: dateFilter, orderType: 'offline' }
    });

    const totalPurchases = await Purchase.sum('totalAmount', { 
      where: { ...branchFilter, createdAt: dateFilter } 
    });

    const activeProducts = await Product.count({ where: { isActive: true } });
    const lowStockProducts = await Product.count({ where: { stock: { [Op.lt]: 10 } } });

    const sixtyDaysAgo = new Date();
    sixtyDaysAgo.setDate(sixtyDaysAgo.getDate() - 60);
    const agingStockCount = await Product.count({
      where: {
        createdAt: { [Op.lt]: sixtyDaysAgo },
        stock: { [Op.gt]: 0 }
      }
    });

    const unreadNotifications = await Notification.count({
      where: { userId: req.user.id, isRead: false }
    });

    const pendingApprovals = 0; // Defaulting for now

    // Top Performer
    const topSales = await Sale.findAll({
      where: { ...branchFilter, createdAt: dateFilter },
      attributes: [
        'userId',
        [sequelize.fn('SUM', sequelize.col('total_amount')), 'totalRevenue']
      ],
      include: [{
        model: User,
        as: 'user',
        attributes: ['name']
      }],
      group: ['userId', 'user.id'],
      order: [[sequelize.literal('totalRevenue'), 'DESC']],
      limit: 1,
      raw: true
    });

    let topPerformer = {
      name: 'No Sales Yet',
      revenue: 0,
      units: 0,
      initials: 'NA',
      color: '#2563EB'
    };

    if (topSales.length > 0 && topSales[0].userId) {
      const topUserId = topSales[0].userId;
      const revenue = parseFloat(topSales[0].totalRevenue) || 0;
      const name = topSales[0]['user.name'] || 'Unknown';
      const initials = name.substring(0, 2).toUpperCase() || 'NA';

      const topUserSales = await Sale.findAll({ where: { ...branchFilter, userId: topUserId, createdAt: dateFilter }, attributes: ['id'] });
      const topUserSaleIds = topUserSales.map(s => s.id);
      const units = await SaleItem.sum('quantity', { where: { saleId: topUserSaleIds } }) || 0;

      topPerformer = { name, revenue, units, initials, color: '#2563EB' };
    }

    const todaysSales = await Sale.findAll({
      where: { ...branchFilter, createdAt: dateFilter },
      attributes: ['totalAmount', 'createdAt']
    });

    const todaysPurchases = await Purchase.findAll({
      where: { ...branchFilter, createdAt: dateFilter },
      attributes: ['totalAmount', 'createdAt']
    });

    // Calculate Profit
    const salesForProfit = await Sale.findAll({
      where: { ...branchFilter, createdAt: dateFilter },
      attributes: ['id'],
      include: [
        {
          model: SaleItem,
          as: 'items',
          attributes: ['unitPrice', 'quantity'],
          include: [
            {
              model: Product,
              as: 'product',
              attributes: ['costPrice']
            }
          ]
        }
      ]
    });

    let profitEstimate = 0;
    for (const sale of salesForProfit) {
      if (sale.items) {
        for (const item of sale.items) {
          const cost = parseFloat(item.product?.costPrice || 0);
          const price = parseFloat(item.unitPrice || 0);
          const qty = parseInt(item.quantity || 0);
          profitEstimate += (price - cost) * qty;
        }
      }
    }

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
      onlineRevenue: onlineRevenue || 0,
      offlineRevenue: offlineRevenue || 0,
      todayOrders: todayOrders || 0,
      todayOnlineOrders: todayOnlineOrders || 0,
      todayOfflineOrders: todayOfflineOrders || 0,
      totalPurchases: totalPurchases || 0,
      profitEstimate: profitEstimate || 0,
      activeProducts,
      lowStockProducts,
      agingStockCount,
      unreadNotifications,
      pendingApprovals,
      topPerformer,
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

exports.getDashboardOverview = async (req, res) => {
  try {
    const period = req.query.period || 'today';
    const stats = await dashboardService.getOverviewStats(period);
    
    return successResponse(res, 200, 'Dashboard overview retrieved successfully', stats);
  } catch (error) {
    return errorResponse(res, 500, 'Error retrieving dashboard overview', [error.message]);
  }
};

exports.getRecentActivities = async (req, res) => {
  try {
    const activities = await dashboardService.getRecentActivities();
    return successResponse(res, 200, 'Recent activities retrieved successfully', activities);
  } catch (error) {
    return errorResponse(res, 500, 'Error retrieving recent activities', [error.message]);
  }
};
