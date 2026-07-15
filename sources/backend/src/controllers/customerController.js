const bcrypt = require('bcrypt');
const { Customer, CustomerAddress, Cart } = require('../models');
const { generateCustomerToken } = require('../utils/jwt');
const { successResponse, errorResponse } = require('../utils/response');

const register = async (req, res) => {
  try {
    const { name, email, password, phone } = req.body;

    const existingCustomer = await Customer.findOne({ where: { email } });
    if (existingCustomer) {
      return errorResponse(res, 400, 'Email is already registered');
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const customer = await Customer.create({
      name,
      email,
      password: hashedPassword,
      phone,
    });

    // Create a cart for the new customer
    await Cart.create({ customerId: customer.id });

    const token = generateCustomerToken(customer);
    const customerData = customer.toJSON();
    delete customerData.password;

    return successResponse(res, 201, 'Registration successful', {
      customer: customerData,
      token,
    });
  } catch (error) {
    console.error('Registration error:', error);
    return errorResponse(res, 500, 'Internal server error');
  }
};

const login = async (req, res) => {
  try {
    const { email, password } = req.body;

    const customer = await Customer.scope('withPassword').findOne({ where: { email } });

    if (!customer || !customer.isActive) {
      return errorResponse(res, 401, 'Invalid credentials or account inactive');
    }

    const isMatch = await bcrypt.compare(password, customer.password);
    if (!isMatch) {
      return errorResponse(res, 401, 'Invalid credentials');
    }

    const token = generateCustomerToken(customer);
    const customerData = customer.toJSON();
    delete customerData.password;

    return successResponse(res, 200, 'Login successful', {
      customer: customerData,
      token,
    });
  } catch (error) {
    console.error('Login error:', error);
    return errorResponse(res, 500, 'Internal server error');
  }
};

const getProfile = async (req, res) => {
  try {
    const customerId = req.user.id;
    const customer = await Customer.findByPk(customerId, {
      include: [{ model: CustomerAddress, as: 'addresses' }]
    });

    if (!customer) {
      return errorResponse(res, 404, 'Customer not found');
    }

    return successResponse(res, 200, 'Profile retrieved', customer);
  } catch (error) {
    console.error('Get profile error:', error);
    return errorResponse(res, 500, 'Internal server error');
  }
};

const updateProfile = async (req, res) => {
  try {
    const customerId = req.user.id;
    const { name, phone } = req.body;

    const customer = await Customer.findByPk(customerId);
    if (!customer) {
      return errorResponse(res, 404, 'Customer not found');
    }

    customer.name = name || customer.name;
    customer.phone = phone || customer.phone;
    await customer.save();

    return successResponse(res, 200, 'Profile updated', customer);
  } catch (error) {
    console.error('Update profile error:', error);
    return errorResponse(res, 500, 'Internal server error');
  }
};

const getAddresses = async (req, res) => {
  try {
    const customerId = req.user.id;
    const addresses = await CustomerAddress.findAll({ where: { customerId } });
    return successResponse(res, 200, 'Addresses retrieved', addresses);
  } catch (error) {
    console.error('Get addresses error:', error);
    return errorResponse(res, 500, 'Internal server error');
  }
};

const addAddress = async (req, res) => {
  try {
    const customerId = req.user.id;
    const { addressLine1, addressLine2, city, state, pincode, isDefault } = req.body;

    if (isDefault) {
      await CustomerAddress.update({ isDefault: false }, { where: { customerId } });
    }

    const address = await CustomerAddress.create({
      customerId,
      addressLine1,
      addressLine2,
      city,
      state,
      pincode,
      isDefault: isDefault || false
    });

    return successResponse(res, 201, 'Address added', address);
  } catch (error) {
    console.error('Add address error:', error);
    return errorResponse(res, 500, 'Internal server error');
  }
};

const deleteAddress = async (req, res) => {
  try {
    const customerId = req.user.id;
    const { id } = req.params;

    const address = await CustomerAddress.findOne({ where: { id, customerId } });
    if (!address) {
      return errorResponse(res, 404, 'Address not found');
    }

    await address.destroy();
    return successResponse(res, 200, 'Address deleted');
  } catch (error) {
    console.error('Delete address error:', error);
    return errorResponse(res, 500, 'Internal server error');
  }
};

module.exports = {
  register,
  login,
  getProfile,
  updateProfile,
  getAddresses,
  addAddress,
  deleteAddress
};
