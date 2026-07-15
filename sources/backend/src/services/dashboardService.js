const { Sale, Purchase, Product, Category, Supplier, User, Notification, sequelize } = require('../models');
const { Op } = require('sequelize');

exports.getOverviewStats = async (period) => {
  let startDate = new Date();
  startDate.setHours(0, 0, 0, 0);

  let thisMonthStart = new Date(startDate.getFullYear(), startDate.getMonth(), 1);

  if (period === 'year') {
    startDate.setMonth(0, 1);
  } else if (period === 'month') {
    startDate = thisMonthStart;
  } else if (period === 'week') {
    startDate.setDate(startDate.getDate() - startDate.getDay());
  } else if (period === 'today') {
    // already set to start of today
  }

  const dateFilter = { [Op.gte]: startDate };

  const [
    totalSales,
    totalPurchases,
    totalRevenueResult,
    totalProducts,
    totalCategories,
    totalSuppliers,
    lowStockCount,
    todaySales,
    monthlySales,
    monthlyRevenueResult,
    uniqueCustomersResult
  ] = await Promise.all([
    Sale.count(),
    Purchase.count(),
    Sale.sum('totalAmount'),
    Product.count(),
    Category.count(),
    Supplier.count(),
    Product.count({ where: { stock: { [Op.lte]: 10 } } }),
    Sale.count({
      where: {
        createdAt: {
          [Op.gte]: new Date(new Date().setHours(0, 0, 0, 0))
        }
      }
    }),
    Sale.count({
      where: {
        createdAt: { [Op.gte]: thisMonthStart }
      }
    }),
    Sale.sum('totalAmount', {
      where: {
        createdAt: { [Op.gte]: thisMonthStart }
      }
    }),
    Sale.count({
      distinct: true,
      col: 'customerMobile'
    })
  ]);

  return {
    "Total Sales": totalSales || 0,
    "Total Purchases": totalPurchases || 0,
    "Total Revenue": totalRevenueResult || 0,
    "Total Products": totalProducts || 0,
    "Total Categories": totalCategories || 0,
    "Total Customers": uniqueCustomersResult || 0,
    "Total Suppliers": totalSuppliers || 0,
    "Low Stock Count": lowStockCount || 0,
    "Today's Sales": todaySales || 0,
    "Monthly Sales": monthlySales || 0,
    "Monthly Revenue": monthlyRevenueResult || 0,
    "Recent Growth Statistics": "Data available" // simplified for now
  };
};

exports.getRecentActivities = async () => {
  // Fetch top 5 from multiple models
  const sales = await Sale.findAll({
    limit: 5,
    order: [['createdAt', 'DESC']],
    include: [{ model: User, as: 'user', attributes: ['name'] }]
  });

  const purchases = await Purchase.findAll({
    limit: 5,
    order: [['createdAt', 'DESC']]
  });

  const products = await Product.findAll({
    limit: 5,
    order: [['createdAt', 'DESC']]
  });

  const suppliers = await Supplier.findAll({
    limit: 5,
    order: [['createdAt', 'DESC']]
  });

  let activities = [];

  sales.forEach(s => {
    activities.push({
      type: 'Sale',
      description: `Invoice ${s.invoiceNumber || s.id} created`,
      user: s.user ? s.user.name : 'System',
      date: s.createdAt
    });
  });

  purchases.forEach(p => {
    activities.push({
      type: 'Purchase',
      description: `Purchase ID ${p.id} created`,
      user: 'System',
      date: p.createdAt
    });
  });

  products.forEach(p => {
    activities.push({
      type: 'Product',
      description: `Product ${p.name} added`,
      user: 'System',
      date: p.createdAt
    });
  });

  suppliers.forEach(s => {
    activities.push({
      type: 'Supplier',
      description: `Supplier ${s.name} added`,
      user: 'System',
      date: s.createdAt
    });
  });

  activities.sort((a, b) => new Date(b.date) - new Date(a.date));

  return activities.slice(0, 15);
};
