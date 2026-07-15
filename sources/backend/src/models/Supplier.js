const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Supplier = sequelize.define('Supplier', {
  name: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  contact: {
    type: DataTypes.STRING,
  },
  gstNumber: {
    type: DataTypes.STRING,
  },
  isActive: {
    type: DataTypes.BOOLEAN,
    defaultValue: true,
  },
  state: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  stateCode: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  gstVerificationStatus: {
    type: DataTypes.ENUM('verified', 'pending', 'failed', 'not_applicable'),
    defaultValue: 'pending',
  },
}, {
  paranoid: true,
});

module.exports = Supplier;
