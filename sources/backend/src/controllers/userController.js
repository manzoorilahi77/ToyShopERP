const bcrypt = require('bcrypt');
const { User, Role, Branch } = require('../models');
const { successResponse, errorResponse } = require('../utils/response');

exports.getAllUsers = async (req, res) => {
  try {
    const users = await User.findAll({
      include: [
        { model: Role, as: 'role' },
        { model: Branch, as: 'branch' }
      ]
    });
    return successResponse(res, 200, 'Users retrieved successfully', users);
  } catch (error) {
    return errorResponse(res, 500, 'Error retrieving users', [error.message]);
  }
};

exports.getUserById = async (req, res) => {
  try {
    const user = await User.findByPk(req.params.id, {
      include: [
        { model: Role, as: 'role' },
        { model: Branch, as: 'branch' }
      ]
    });
    if (!user) return errorResponse(res, 404, 'User not found');
    return successResponse(res, 200, 'User retrieved successfully', user);
  } catch (error) {
    return errorResponse(res, 500, 'Error retrieving user', [error.message]);
  }
};

exports.createUser = async (req, res) => {
  try {
    const { name, email, password, roleId, branchId } = req.body;
    
    const existingUser = await User.findOne({ where: { email } });
    if (existingUser) return errorResponse(res, 400, 'Email already in use');

    const hashedPassword = await bcrypt.hash(password, 10);
    const user = await User.create({
      name,
      email,
      password: hashedPassword,
      roleId,
      branchId
    });

    const userData = user.toJSON();
    delete userData.password;
    
    return successResponse(res, 201, 'User created successfully', userData);
  } catch (error) {
    return errorResponse(res, 500, 'Error creating user', [error.message]);
  }
};

exports.updateUser = async (req, res) => {
  try {
    const user = await User.findByPk(req.params.id);
    if (!user) return errorResponse(res, 404, 'User not found');

    const { password, ...updateData } = req.body;
    if (password) {
      updateData.password = await bcrypt.hash(password, 10);
    }

    await user.update(updateData);
    
    const userData = user.toJSON();
    delete userData.password;

    return successResponse(res, 200, 'User updated successfully', userData);
  } catch (error) {
    return errorResponse(res, 500, 'Error updating user', [error.message]);
  }
};

exports.deleteUser = async (req, res) => {
  try {
    const user = await User.findByPk(req.params.id);
    if (!user) return errorResponse(res, 404, 'User not found');
    await user.destroy();
    return successResponse(res, 200, 'User deleted successfully');
  } catch (error) {
    return errorResponse(res, 500, 'Error deleting user', [error.message]);
  }
};

exports.getLeaderboard = async (req, res) => {
  try {
    const leaderboard = await User.findAll({
      order: [['points', 'DESC']],
      limit: 10,
      attributes: ['id', 'name', 'points']
    });
    return successResponse(res, 200, 'Leaderboard retrieved successfully', leaderboard);
  } catch (error) {
    return errorResponse(res, 500, 'Error retrieving leaderboard', [error.message]);
  }
};
