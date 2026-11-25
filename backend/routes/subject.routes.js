const express = require('express');
const router = express.Router();

const {
  verifyFirebaseToken,
  verifyUserStatus,
  requireAdmin,
} = require('../middleware/auth_middleware');

const subjectController = require('../controllers/subject.controller');

// GET /api/subjects - danh sách môn học
router.get(
  '/',
  verifyFirebaseToken,
  verifyUserStatus,
  subjectController.getAllSubjects
);

// GET /api/subjects/:id - chi tiết môn học
router.get(
  '/:id',
  verifyFirebaseToken,
  verifyUserStatus,
  subjectController.getSubjectById
);

// POST /api/subjects - tạo môn học (admin)
router.post(
  '/',
  verifyFirebaseToken,
  verifyUserStatus,
  requireAdmin,
  subjectController.createSubject
);

// PUT /api/subjects/:id - cập nhật môn học (admin)
router.put(
  '/:id',
  verifyFirebaseToken,
  verifyUserStatus,
  requireAdmin,
  subjectController.updateSubject
);

// PATCH /api/subjects/:id/status - thay đổi trạng thái (admin)
router.patch(
  '/:id/status',
  verifyFirebaseToken,
  verifyUserStatus,
  requireAdmin,
  subjectController.patchSubjectStatus
);

module.exports = router;
