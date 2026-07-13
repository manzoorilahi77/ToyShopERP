const { body } = require('express-validator');

const loginValidation = [
  body('email').isEmail().withMessage('Please provide a valid email'),
  body('password').notEmpty().withMessage('Password is required'),
];

const refreshTokenValidation = [
  body('token').notEmpty().withMessage('Refresh token is required'),
];

const resetPasswordValidation = [
  body('oldPassword').notEmpty().withMessage('Old password is required'),
  body('newPassword')
    .isLength({ min: 6 })
    .withMessage('New password must be at least 6 characters long'),
];

module.exports = {
  loginValidation,
  refreshTokenValidation,
  resetPasswordValidation,
};
