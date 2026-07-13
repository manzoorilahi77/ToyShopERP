const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Category = sequelize.define('Category', {
  name: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  icon: {
    type: DataTypes.STRING,
  },
  color: {
    type: DataTypes.STRING,
  },
}, {
  paranoid: true,
});

module.exports = Category;
