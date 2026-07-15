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
  customerMobile: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  paymentMethod: {
    type: DataTypes.ENUM('cash', 'card', 'upi'),
    defaultValue: 'cash',
  },
  status: {
    type: DataTypes.ENUM('completed', 'refunded', 'failed'),
    defaultValue: 'completed',
  },
  customerId: {
    type: DataTypes.INTEGER,
    allowNull: true, // Null for offline, required for online
  },
  orderType: {
    type: DataTypes.ENUM('offline', 'online'),
    defaultValue: 'offline',
  },
  deliveryStatus: {
    type: DataTypes.ENUM('pending', 'accepted', 'processing', 'packed', 'out_for_delivery', 'delivered', 'cancelled'),
    defaultValue: 'pending',
  },
  subtotal: {
    type: DataTypes.DECIMAL(12, 2),
    allowNull: true,
    defaultValue: 0,
  },
  cgst: {
    type: DataTypes.DECIMAL(12, 2),
    allowNull: true,
    defaultValue: 0,
  },
  sgst: {
    type: DataTypes.DECIMAL(12, 2),
    allowNull: true,
    defaultValue: 0,
  },
  igst: {
    type: DataTypes.DECIMAL(12, 2),
    allowNull: true,
    defaultValue: 0,
  },
  taxableAmount: {
    type: DataTypes.DECIMAL(12, 2),
    allowNull: true,
    defaultValue: 0,
  },
}, {
  paranoid: true,
});

module.exports = Sale;
