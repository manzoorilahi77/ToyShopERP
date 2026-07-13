const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const GstRegistration = sequelize.define('GstRegistration', {
  gstNumber: {
    type: DataTypes.STRING,
    allowNull: false,
    unique: true,
  },
  businessName: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  state: {
    type: DataTypes.STRING,
  },
}, {
  paranoid: true,
});

module.exports = GstRegistration;
