const express = require('express');
const router = express.Router();
const userController = require('../controllers/userController');
const { createUserValidation, updateUserValidation } = require('../validations/userValidation');
const validate = require('../middleware/validate');
const { authenticate, authorize } = require('../middleware/auth');

router.use(authenticate);

router.get('/leaderboard', userController.getLeaderboard);

router.get('/', authorize('Super Admin', 'Owner', 'Manager'), userController.getAllUsers);
router.get('/:id', userController.getUserById); // user can view own profile, or admins
router.post('/', authorize('Super Admin', 'Owner', 'Manager'), createUserValidation, validate, userController.createUser);
router.put('/:id', authorize('Super Admin', 'Owner', 'Manager'), updateUserValidation, validate, userController.updateUser);
router.delete('/:id', authorize('Super Admin', 'Owner'), userController.deleteUser);

module.exports = router;
