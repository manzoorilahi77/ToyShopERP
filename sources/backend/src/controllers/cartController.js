const { Cart, CartItem, Product, Category } = require('../models');
const { successResponse, errorResponse } = require('../utils/response');

const getCart = async (req, res) => {
  try {
    const customerId = req.user.id;
    let cart = await Cart.findOne({
      where: { customerId },
      include: [
        {
          model: CartItem,
          as: 'items',
          include: [
            {
              model: Product,
              as: 'product',
              include: [{ model: Category, as: 'category' }]
            }
          ]
        }
      ]
    });

    if (!cart) {
      cart = await Cart.create({ customerId });
      cart.items = [];
    }

    return successResponse(res, 200, 'Cart retrieved', cart);
  } catch (error) {
    console.error('Get cart error:', error);
    return errorResponse(res, 500, 'Internal server error');
  }
};

const addToCart = async (req, res) => {
  try {
    const customerId = req.user.id;
    const { productId, quantity } = req.body;

    let cart = await Cart.findOne({ where: { customerId } });
    if (!cart) {
      cart = await Cart.create({ customerId });
    }

    const product = await Product.findByPk(productId);
    if (!product) {
      return errorResponse(res, 404, 'Product not found');
    }

    if (product.stockQuantity < quantity) {
      return errorResponse(res, 400, 'Not enough stock available');
    }

    let cartItem = await CartItem.findOne({ where: { cartId: cart.id, productId } });

    if (cartItem) {
      cartItem.quantity += parseInt(quantity, 10);
      await cartItem.save();
    } else {
      cartItem = await CartItem.create({
        cartId: cart.id,
        productId,
        quantity: parseInt(quantity, 10)
      });
    }

    return successResponse(res, 200, 'Added to cart', cartItem);
  } catch (error) {
    console.error('Add to cart error:', error);
    return errorResponse(res, 500, 'Internal server error');
  }
};

const updateCartItem = async (req, res) => {
  try {
    const customerId = req.user.id;
    const { itemId } = req.params;
    const { quantity } = req.body;

    const cart = await Cart.findOne({ where: { customerId } });
    if (!cart) {
      return errorResponse(res, 404, 'Cart not found');
    }

    const cartItem = await CartItem.findOne({ where: { id: itemId, cartId: cart.id } });
    if (!cartItem) {
      return errorResponse(res, 404, 'Cart item not found');
    }

    if (quantity <= 0) {
      await cartItem.destroy();
      return successResponse(res, 200, 'Item removed from cart');
    }

    const product = await Product.findByPk(cartItem.productId);
    if (product.stockQuantity < quantity) {
      return errorResponse(res, 400, 'Not enough stock available');
    }

    cartItem.quantity = quantity;
    await cartItem.save();

    return successResponse(res, 200, 'Cart updated', cartItem);
  } catch (error) {
    console.error('Update cart item error:', error);
    return errorResponse(res, 500, 'Internal server error');
  }
};

const removeFromCart = async (req, res) => {
  try {
    const customerId = req.user.id;
    const { itemId } = req.params;

    const cart = await Cart.findOne({ where: { customerId } });
    if (!cart) {
      return errorResponse(res, 404, 'Cart not found');
    }

    const cartItem = await CartItem.findOne({ where: { id: itemId, cartId: cart.id } });
    if (!cartItem) {
      return errorResponse(res, 404, 'Cart item not found');
    }

    await cartItem.destroy();
    return successResponse(res, 200, 'Item removed from cart');
  } catch (error) {
    console.error('Remove from cart error:', error);
    return errorResponse(res, 500, 'Internal server error');
  }
};

const clearCart = async (req, res) => {
  try {
    const customerId = req.user.id;
    const cart = await Cart.findOne({ where: { customerId } });
    if (!cart) {
      return successResponse(res, 200, 'Cart cleared');
    }

    await CartItem.destroy({ where: { cartId: cart.id } });
    return successResponse(res, 200, 'Cart cleared');
  } catch (error) {
    console.error('Clear cart error:', error);
    return errorResponse(res, 500, 'Internal server error');
  }
};

module.exports = {
  getCart,
  addToCart,
  updateCartItem,
  removeFromCart,
  clearCart
};
