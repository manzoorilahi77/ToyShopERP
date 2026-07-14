const { Product } = require('./src/models');
const { Op } = require('sequelize');

Product.destroy({
  where: {
    deletedAt: {
      [Op.ne]: null
    }
  },
  force: true
}).then(deletedCount => {
  console.log(`Successfully permanently deleted ${deletedCount} soft-deleted products.`);
  process.exit(0);
}).catch(err => {
  console.error('Error deleting products:', err);
  process.exit(1);
});
