const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');
require('dotenv').config();
const path = require('path');

const { errorResponse } = require('./utils/response');

// Import Routes
const authRoutes = require('./routes/authRoutes');
const userRoutes = require('./routes/userRoutes');
const branchRoutes = require('./routes/branchRoutes');
const categoryRoutes = require('./routes/categoryRoutes');
const productRoutes = require('./routes/productRoutes');
const supplierRoutes = require('./routes/supplierRoutes');
const saleRoutes = require('./routes/saleRoutes');
const purchaseRoutes = require('./routes/purchaseRoutes');
const gstRoutes = require('./routes/gstRoutes');
const notificationRoutes = require('./routes/notificationRoutes');
const dashboardRoutes = require('./routes/dashboardRoutes');
const superAdminRoutes = require('./routes/superAdminRoutes');
const customerRoutes = require('./routes/customerRoutes');
const cartRoutes = require('./routes/cartRoutes');
const onlineOrderRoutes = require('./routes/onlineOrderRoutes');
const reportRoutes = require('./routes/reportRoutes');
const app = express();

// Middlewares
app.use(helmet({ crossOriginResourcePolicy: false }));
app.use(cors());
app.use(compression());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

if (process.env.NODE_ENV !== 'test') {
  app.use(morgan('dev'));
}

// Routes
app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/users', userRoutes);
app.use('/api/v1/branches', branchRoutes);
app.use('/api/v1/categories', categoryRoutes);
app.use('/api/v1/products', productRoutes);
app.use('/api/v1/suppliers', supplierRoutes);
app.use('/api/v1/sales', saleRoutes);
app.use('/api/v1/purchases', purchaseRoutes);
app.use('/api/v1/gst-registrations', gstRoutes);
app.use('/api/v1/notifications', notificationRoutes);
app.use('/api/v1/dashboard', dashboardRoutes);
app.use('/api/v1/superadmin', superAdminRoutes);
app.use('/api/v1/reports', reportRoutes);

// Customer Facing APIs
app.use('/api/v1/customers', customerRoutes);
app.use('/api/v1/cart', cartRoutes);
app.use('/api/v1/online-orders', onlineOrderRoutes);

// Static files
app.use('/uploads', express.static(path.join(__dirname, '../uploads')));

// 404 Handler
app.use((req, res, next) => {
  errorResponse(res, 404, 'API endpoint not found');
});

// Global Error Handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  require('fs').appendFileSync(require('path').join(__dirname, '../error.log'), new Date().toISOString() + '\\n' + err.stack + '\\n');
  errorResponse(res, 500, 'Internal Server Error', [err.message]);
});

module.exports = app;
