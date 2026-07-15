const { Sale, SaleItem, Cart, CartItem, Product, Notification, User, Role } = require('../models');
const { successResponse, errorResponse } = require('../utils/response');
const sequelize = require('../config/database');

const generateInvoiceNumber = () => {
  const dateStr = new Date().toISOString().slice(0, 10).replace(/-/g, '');
  const randomSuffix = Math.floor(1000 + Math.random() * 9000);
  return `INV-${dateStr}-${randomSuffix}`;
};

const placeOrder = async (req, res) => {
  const transaction = await sequelize.transaction();
  
  try {
    const customerId = req.user.id;
    const { paymentMethod, paymentStatus, addressId, notes } = req.body;

    const cart = await Cart.findOne({
      where: { customerId },
      include: [{ model: CartItem, as: 'items', include: [{ model: Product, as: 'product' }] }]
    });

    if (!cart || cart.items.length === 0) {
      await transaction.rollback();
      return errorResponse(res, 400, 'Cart is empty');
    }

    let subtotal = 0;
    let cgstTotal = 0;
    let sgstTotal = 0;
    let igstTotal = 0;
    let totalAmount = 0;
    
    // In a real app we'd calculate GST based on GST rates and branch location vs customer location
    // For simplicity, we just calculate a flat rate or 0 if not set on product
    const saleItemsData = [];

    for (const item of cart.items) {
      if (item.product.stock < item.quantity) {
        await transaction.rollback();
        return errorResponse(res, 400, `Not enough stock for ${item.product.name}`);
      }

      const itemTotal = item.product.price * item.quantity;
      // Mocking 18% GST (9% CGST, 9% SGST)
      const cgst = itemTotal * 0.09;
      const sgst = itemTotal * 0.09;

      subtotal += itemTotal;
      cgstTotal += cgst;
      sgstTotal += sgst;
      totalAmount += (itemTotal + cgst + sgst);

      saleItemsData.push({
        productId: item.productId,
        quantity: item.quantity,
        unitPrice: item.product.price,
        subTotal: itemTotal + cgst + sgst,
        gstPercent: 18,
        gstAmount: cgst + sgst,
        taxableAmount: itemTotal,
      });

      // Reduce stock
      await item.product.update(
        { stock: item.product.stock - item.quantity },
        { transaction }
      );
    }

    const invoiceNumber = generateInvoiceNumber();

    const sale = await Sale.create({
      invoiceNumber,
      totalAmount,
      subtotal,
      cgst: cgstTotal,
      sgst: sgstTotal,
      igst: igstTotal,
      taxableAmount: subtotal,
      paymentMethod: paymentMethod || 'cash',
      status: paymentStatus === 'success' ? 'completed' : 'pending',
      customerId,
      orderType: 'online',
      deliveryStatus: 'pending',
      branchId: 1 // Defaulting to branch 1 for online orders
    }, { transaction });

    for (const itemData of saleItemsData) {
      itemData.saleId = sale.id;
      await SaleItem.create(itemData, { transaction });
    }

    // Clear cart
    await CartItem.destroy({ where: { cartId: cart.id }, transaction });

    // Notify Salesmen and Admins
    const staff = await User.findAll({
      include: [{ model: Role, as: 'role', where: { name: ['Admin', 'Super Admin', 'Staff'] } }]
    });

    const notifications = staff.map(u => ({
      userId: u.id,
      title: 'New Online Order',
      message: `Order ${invoiceNumber} placed by customer.`,
      isRead: false
    }));
    await Notification.bulkCreate(notifications, { transaction });

    await transaction.commit();
    return successResponse(res, 201, 'Order placed successfully', sale);
  } catch (error) {
    if (transaction) await transaction.rollback();
    console.error('Place order error:', error);
    return errorResponse(res, 500, error.message || 'Internal server error', error.stack);
  }
};

const getOrderHistory = async (req, res) => {
  try {
    const customerId = req.user.id;
    const orders = await Sale.findAll({
      where: { customerId, orderType: 'online' },
      include: [{ model: SaleItem, as: 'items', include: [{ model: Product, as: 'product' }] }],
      order: [['createdAt', 'DESC']]
    });

    return successResponse(res, 200, 'Orders retrieved', orders);
  } catch (error) {
    console.error('Get order history error:', error);
    return errorResponse(res, 500, error.message || 'Internal server error', error.stack);
  }
};

const getOrderDetails = async (req, res) => {
  try {
    const customerId = req.user.id;
    const { orderId } = req.params;
    
    const order = await Sale.findOne({
      where: { id: orderId, customerId, orderType: 'online' },
      include: [{ model: SaleItem, as: 'items', include: [{ model: Product, as: 'product' }] }]
    });

    if (!order) {
      return errorResponse(res, 404, 'Order not found');
    }

    return successResponse(res, 200, 'Order details retrieved', order);
  } catch (error) {
    console.error('Get order details error:', error);
    return errorResponse(res, 500, 'Internal server error');
  }
};

module.exports = {
  placeOrder,
  getOrderHistory,
  getOrderDetails
};
