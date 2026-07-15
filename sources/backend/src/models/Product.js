const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Product = sequelize.define('Product', {
  name: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  price: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false,
    defaultValue: 0,
  },
  costPrice: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false,
    defaultValue: 0,
  },
  stock: {
    type: DataTypes.INTEGER,
    defaultValue: 0,
  },
  isFavorite: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
  },
  image: {
    type: DataTypes.STRING,
  },
  isActive: {
    type: DataTypes.BOOLEAN,
    defaultValue: true,
  },
  hsnCode: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  gstRate: {
    type: DataTypes.DECIMAL(5, 2),
    allowNull: true,
    defaultValue: 0,
  },
}, {
  paranoid: true,
});

module.exports = Product;
