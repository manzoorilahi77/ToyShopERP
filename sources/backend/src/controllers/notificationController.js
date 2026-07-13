const { Notification } = require('../models');
const { successResponse, errorResponse } = require('../utils/response');

exports.getMyNotifications = async (req, res) => {
  try {
    const notifications = await Notification.findAll({
      where: { userId: req.user.id },
      order: [['createdAt', 'DESC']]
    });
    return successResponse(res, 200, 'Notifications retrieved successfully', notifications);
  } catch (error) {
    return errorResponse(res, 500, 'Error retrieving notifications', [error.message]);
  }
};

exports.markAsRead = async (req, res) => {
  try {
    const notification = await Notification.findOne({
      where: { id: req.params.id, userId: req.user.id }
    });
    if (!notification) return errorResponse(res, 404, 'Notification not found');
    
    await notification.update({ isRead: req.body.isRead });
    return successResponse(res, 200, 'Notification status updated', notification);
  } catch (error) {
    return errorResponse(res, 500, 'Error updating notification', [error.message]);
  }
};
