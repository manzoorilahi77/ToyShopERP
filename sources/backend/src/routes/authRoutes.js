const express = require('express');
const router = express.Router();

const { login, refreshToken, resetPassword, logout, getPublicUsers } = require('../controllers/authController');
const { loginValidation, refreshTokenValidation, resetPasswordValidation } = require('../validations/authValidation');
const validate = require('../middleware/validate');
const { authenticate } = require('../middleware/auth');

router.get('/users', getPublicUsers);
router.post('/login', loginValidation, validate, login);
router.post('/refresh-token', refreshTokenValidation, validate, refreshToken);
router.post('/reset-password', authenticate, resetPasswordValidation, validate, resetPassword);
router.post('/logout', authenticate, logout);

module.exports = router;
