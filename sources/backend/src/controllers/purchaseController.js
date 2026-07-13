const { Purchase, PurchaseItem, Product, Supplier, sequelize } = require('../models');
const { successResponse, errorResponse } = require('../utils/response');

exports.getAllPurchases = async (req, res) => {
  try {
    const purchases = await Purchase.findAll({
      include: [
        { model: PurchaseItem, as: 'items', include: [{ model: Product, as: 'product' }] },
        { model: Supplier, as: 'supplier' }
      ],
      order: [['createdAt', 'DESC']]
    });
    return successResponse(res, 200, 'Purchases retrieved successfully', purchases);
  } catch (error) {
    return errorResponse(res, 500, 'Error retrieving purchases', [error.message]);
  }
};

exports.getPurchaseById = async (req, res) => {
  try {
    const purchase = await Purchase.findByPk(req.params.id, {
      include: [
        { model: PurchaseItem, as: 'items', include: [{ model: Product, as: 'product' }] },
        { model: Supplier, as: 'supplier' }
      ]
    });
    if (!purchase) return errorResponse(res, 404, 'Purchase not found');
    return successResponse(res, 200, 'Purchase retrieved successfully', purchase);
  } catch (error) {
    return errorResponse(res, 500, 'Error retrieving purchase', [error.message]);
  }
};

exports.createPurchase = async (req, res) => {
  const transaction = await sequelize.transaction();
  try {
    const { branchId, supplierId, items } = req.body;

    let totalAmount = 0;
    const purchaseItemsData = [];

    // Calculate total and prepare items data
    for (const item of items) {
      const product = await Product.findByPk(item.productId, { transaction });
      if (!product) {
        throw new Error(`Product with ID ${item.productId} not found`);
      }

      const subTotal = item.costPrice * item.quantity;
      totalAmount += subTotal;

      purchaseItemsData.push({
        productId: product.id,
        quantity: item.quantity,
        costPrice: item.costPrice,
      });

      // Increment stock
      await product.update({ stock: product.stock + item.quantity }, { transaction });
    }

    // Create Purchase
    const purchase = await Purchase.create({
      branchId,
      supplierId,
      totalAmount,
      status: 'completed'
    }, { transaction });

    // Create Purchase Items
    const itemsToCreate = purchaseItemsData.map(item => ({ ...item, purchaseId: purchase.id }));
    await PurchaseItem.bulkCreate(itemsToCreate, { transaction });

    await transaction.commit();
    return successResponse(res, 201, 'Purchase (Stock Addition) completed successfully', purchase);
  } catch (error) {
    await transaction.rollback();
    return errorResponse(res, 400, 'Failed to complete purchase', [error.message]);
  }
};
