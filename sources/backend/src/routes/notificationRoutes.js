const express = require('express');
const router = express.Router();
const notificationController = require('../controllers/notificationController');
const { updateNotificationValidation } = require('../validations/notificationValidation');
const validate = require('../middleware/validate');
const { authenticate } = require('../middleware/auth');

router.use(authenticate);

router.get('/', notificationController.getMyNotifications);
router.patch('/:id/read', updateNotificationValidation, validate, notificationController.markAsRead);

module.exports = router;
