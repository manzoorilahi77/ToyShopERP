const { body } = require('express-validator');

const updateNotificationValidation = [
  body('isRead').notEmpty().withMessage('isRead status is required').isBoolean(),
];

module.exports = {
  updateNotificationValidation,
};
