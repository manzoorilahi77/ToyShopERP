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
  tradeName: {
    type: DataTypes.STRING,
  },
  address: {
    type: DataTypes.TEXT,
  },
  state: {
    type: DataTypes.STRING,
  },
  stateCode: {
    type: DataTypes.STRING,
  },
  email: {
    type: DataTypes.STRING,
  },
  phone: {
    type: DataTypes.STRING,
  },
  status: {
    type: DataTypes.ENUM('active', 'inactive', 'suspended', 'cancelled'),
    defaultValue: 'active',
  },
}, {
  paranoid: true,
});

module.exports = GstRegistration;
