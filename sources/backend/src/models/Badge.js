const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Badge = sequelize.define('Badge', {
  title: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  icon: {
    type: DataTypes.STRING,
  },
  criteria: {
    type: DataTypes.STRING,
  },
}, {
  paranoid: true,
});

module.exports = Badge;
