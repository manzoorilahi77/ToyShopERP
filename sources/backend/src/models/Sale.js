const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Sale = sequelize.define('Sale', {
  invoiceNumber: {
    type: DataTypes.STRING,
    allowNull: false,
    unique: true,
  },
  totalAmount: {
    type: DataTypes.DECIMAL(12, 2),
    allowNull: false,
    defaultValue: 0,
  },
  paymentMethod: {
    type: DataTypes.ENUM('cash', 'card', 'upi'),
    defaultValue: 'cash',
  },
  status: {
    type: DataTypes.ENUM('completed', 'refunded', 'failed'),
    defaultValue: 'completed',
  },
}, {
  paranoid: true,
});

module.exports = Sale;
