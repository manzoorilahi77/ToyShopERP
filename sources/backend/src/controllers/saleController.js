const { Sale, SaleItem, Product, User, sequelize } = require('../models');
const { successResponse, errorResponse } = require('../utils/response');

exports.getMySales = async (req, res) => {
  try {
    const { id: userId } = req.user;

    const sales = await Sale.findAll({
      where: { userId },
      include: [
        { model: SaleItem, as: 'items', include: [{ model: Product, as: 'product' }] },
        { model: User, as: 'user', attributes: ['id', 'name'] }
      ],
      order: [['createdAt', 'DESC']]
    });
    return successResponse(res, 200, 'My sales retrieved successfully', sales);
  } catch (error) {
    return errorResponse(res, 500, 'Error retrieving sales', [error.message]);
  }
};

exports.getAllSales = async (req, res) => {
  try {
    const { branchId, role } = req.user;
    
    // If not super admin or owner, restrict to own branch
    const whereClause = {};
    if (role !== 'Super Admin' && role !== 'Owner') {
      whereClause.branchId = branchId;
    }

    const sales = await Sale.findAll({
      where: whereClause,
      include: [
        { model: SaleItem, as: 'items', include: [{ model: Product, as: 'product' }] },
        { model: User, as: 'user', attributes: ['id', 'name'] }
      ],
      order: [['createdAt', 'DESC']]
    });
    return successResponse(res, 200, 'Sales retrieved successfully', sales);
  } catch (error) {
    return errorResponse(res, 500, 'Error retrieving sales', [error.message]);
  }
};

exports.getSaleById = async (req, res) => {
  try {
    const sale = await Sale.findByPk(req.params.id, {
      include: [
        { model: SaleItem, as: 'items', include: [{ model: Product, as: 'product' }] },
        { model: User, as: 'user', attributes: ['id', 'name'] }
      ]
    });
    if (!sale) return errorResponse(res, 404, 'Sale not found');
    return successResponse(res, 200, 'Sale retrieved successfully', sale);
  } catch (error) {
    return errorResponse(res, 500, 'Error retrieving sale', [error.message]);
  }
};

exports.createSale = async (req, res) => {
  const transaction = await sequelize.transaction();
  try {
    const { branchId, items, paymentMethod, customerMobile } = req.body;
    const userId = req.user.id;

    let totalAmount = 0;
    const saleItemsData = [];
    let totalItems = 0;

    // Validate stock and calculate total
    for (const item of items) {
      const product = await Product.findByPk(item.productId, { transaction });
      if (!product) {
        throw new Error(`Product with ID ${item.productId} not found`);
      }
      if (product.stock < item.quantity) {
        throw new Error(`Insufficient stock for product ${product.name}`);
      }

      const subTotal = product.price * item.quantity;
      totalAmount += subTotal;
      totalItems += item.quantity;

      saleItemsData.push({
        productId: product.id,
        quantity: item.quantity,
        unitPrice: product.price,
        subTotal,
      });

      // Deduct stock
      await product.update({ stock: product.stock - item.quantity }, { transaction });
    }

    // Generate Invoice Number
    const dateStr = new Date().toISOString().slice(0, 10).replace(/-/g, '');
    const randomSuffix = Math.floor(1000 + Math.random() * 9000);
    const invoiceNumber = `INV-${dateStr}-${randomSuffix}`;

    // Create Sale
    const sale = await Sale.create({
      invoiceNumber,
      branchId,
      userId,
      totalAmount,
      customerMobile,
      paymentMethod,
      status: 'completed'
    }, { transaction });

    // Create Sale Items
    const itemsToCreate = saleItemsData.map(item => ({ ...item, saleId: sale.id }));
    await SaleItem.bulkCreate(itemsToCreate, { transaction });

    // Gamification: Add points to staff (1 point per 100 Rs/Dollars of sale)
    const pointsEarned = Math.floor(totalAmount / 100);
    const user = await User.findByPk(userId, { transaction });
    if (user) {
      await user.update({ points: user.points + pointsEarned }, { transaction });
    }

    await transaction.commit();
    return successResponse(res, 201, 'Sale completed successfully', { sale, pointsEarned });
  } catch (error) {
    await transaction.rollback();
    return errorResponse(res, 400, 'Failed to complete sale', [error.message]);
  }
};
