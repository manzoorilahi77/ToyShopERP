const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Purchase = sequelize.define('Purchase', {
  totalAmount: {
    type: DataTypes.DECIMAL(12, 2),
    allowNull: false,
    defaultValue: 0,
  },
  status: {
    type: DataTypes.ENUM('completed', 'pending', 'cancelled'),
    defaultValue: 'completed',
  },
}, {
  paranoid: true,
});

module.exports = Purchase;
