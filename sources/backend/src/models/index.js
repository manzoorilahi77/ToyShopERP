const sequelize = require('../config/database');
const Role = require('./Role');
const Branch = require('./Branch');
const User = require('./User');
const Category = require('./Category');
const Product = require('./Product');
const Supplier = require('./Supplier');
const Sale = require('./Sale');
const SaleItem = require('./SaleItem');
const Purchase = require('./Purchase');
const PurchaseItem = require('./PurchaseItem');
const GstRegistration = require('./GstRegistration');
const Notification = require('./Notification');
const Badge = require('./Badge');
const UserBadge = require('./UserBadge');

// Setup Associations

// Role - User (1:N)
Role.hasMany(User, { foreignKey: 'roleId', as: 'users' });
User.belongsTo(Role, { foreignKey: 'roleId', as: 'role' });

// Branch - User (1:N)
Branch.hasMany(User, { foreignKey: 'branchId', as: 'users' });
User.belongsTo(Branch, { foreignKey: 'branchId', as: 'branch' });

// Category - Product (1:N)
Category.hasMany(Product, { foreignKey: 'categoryId', as: 'products' });
Product.belongsTo(Category, { foreignKey: 'categoryId', as: 'category' });

// Branch - Sale (1:N)
Branch.hasMany(Sale, { foreignKey: 'branchId', as: 'sales' });
Sale.belongsTo(Branch, { foreignKey: 'branchId', as: 'branch' });

// User - Sale (1:N)
User.hasMany(Sale, { foreignKey: 'userId', as: 'sales' });
Sale.belongsTo(User, { foreignKey: 'userId', as: 'user' });

// Sale - SaleItem (1:N)
Sale.hasMany(SaleItem, { foreignKey: 'saleId', as: 'items', onDelete: 'CASCADE' });
SaleItem.belongsTo(Sale, { foreignKey: 'saleId', as: 'sale' });

// Product - SaleItem (1:N)
Product.hasMany(SaleItem, { foreignKey: 'productId', as: 'saleItems' });
SaleItem.belongsTo(Product, { foreignKey: 'productId', as: 'product' });

// Branch - Purchase (1:N)
Branch.hasMany(Purchase, { foreignKey: 'branchId', as: 'purchases' });
Purchase.belongsTo(Branch, { foreignKey: 'branchId', as: 'branch' });

// Supplier - Purchase (1:N)
Supplier.hasMany(Purchase, { foreignKey: 'supplierId', as: 'purchases' });
Purchase.belongsTo(Supplier, { foreignKey: 'supplierId', as: 'supplier' });

// Purchase - PurchaseItem (1:N)
Purchase.hasMany(PurchaseItem, { foreignKey: 'purchaseId', as: 'items', onDelete: 'CASCADE' });
PurchaseItem.belongsTo(Purchase, { foreignKey: 'purchaseId', as: 'purchase' });

// Product - PurchaseItem (1:N)
Product.hasMany(PurchaseItem, { foreignKey: 'productId', as: 'purchaseItems' });
PurchaseItem.belongsTo(Product, { foreignKey: 'productId', as: 'product' });

// Branch - GstRegistration (1:1)
Branch.hasOne(GstRegistration, { foreignKey: 'branchId', as: 'gstRegistration', onDelete: 'CASCADE' });
GstRegistration.belongsTo(Branch, { foreignKey: 'branchId', as: 'branch' });

// User - Notification (1:N)
User.hasMany(Notification, { foreignKey: 'userId', as: 'notifications', onDelete: 'CASCADE' });
Notification.belongsTo(User, { foreignKey: 'userId', as: 'user' });

// User - Badge (N:M)
User.belongsToMany(Badge, { through: UserBadge, foreignKey: 'userId', as: 'badges' });
Badge.belongsToMany(User, { through: UserBadge, foreignKey: 'badgeId', as: 'users' });

module.exports = {
  sequelize,
  Role,
  Branch,
  User,
  Category,
  Product,
  Supplier,
  Sale,
  SaleItem,
  Purchase,
  PurchaseItem,
  GstRegistration,
  Notification,
  Badge,
  UserBadge,
};
