const express = require('express');
const router = express.Router();
const branchController = require('../controllers/branchController');
const { createBranchValidation, updateBranchValidation } = require('../validations/branchValidation');
const validate = require('../middleware/validate');
const { authenticate, authorize } = require('../middleware/auth');

router.use(authenticate);

router.get('/', branchController.getAllBranches);
router.get('/:id', branchController.getBranchById);
router.post('/', authorize('Super Admin', 'Owner'), createBranchValidation, validate, branchController.createBranch);
router.put('/:id', authorize('Super Admin', 'Owner'), updateBranchValidation, validate, branchController.updateBranch);
router.delete('/:id', authorize('Super Admin', 'Owner'), branchController.deleteBranch);

module.exports = router;
