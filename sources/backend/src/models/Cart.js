const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Cart = sequelize.define('Cart', {
  // customerId will be added via associations
}, {
  timestamps: true,
});

module.exports = Cart;
