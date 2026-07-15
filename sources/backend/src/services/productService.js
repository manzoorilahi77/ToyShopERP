const { Product, Category } = require('../models');
const { Op } = require('sequelize');

exports.getLowStockProducts = async () => {
  const products = await Product.findAll({
    where: {
      stock: { [Op.lte]: 10 }
    },
    include: [{ model: Category, as: 'category' }],
    order: [['stock', 'ASC']]
  });

  return products.map(p => ({
    "Product ID": p.id,
    "Product Name": p.name,
    "SKU": `PROD-${p.id}`,
    "Category": p.category ? p.category.name : 'Uncategorized',
    "Current Quantity": p.stock,
    "Minimum Stock": 10,
    "Branch": p.branchId || 'Main Branch',
    "Status": p.isActive ? 'Active' : 'Inactive'
  }));
};
