const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const GstRate = sequelize.define('GstRate', {
  rate: {
    type: DataTypes.DECIMAL(5, 2),
    allowNull: false,
    unique: true,
  },
  description: {
    type: DataTypes.STRING,
  },
}, {
  paranoid: true,
  timestamps: true,
});

module.exports = GstRate;
