const express = require('express');

const router = express.Router();

const {
  verifyFirebaseToken,
  verifyUserStatus,
  requireAdmin,
} = require('../middleware/auth_middleware');

const uploadQuestionFile = require('../middleware/upload_middleware');

const {
  uploadQuestionMedia,
  deleteQuestionMedia,
} = require('../controllers/storage.controller');

// Upload ảnh hoặc âm thanh câu hỏi
router.post(
  '/upload',
  verifyFirebaseToken,
  verifyUserStatus,
  requireAdmin,
  uploadQuestionFile.single('file'),
  uploadQuestionMedia
);

// Xóa ảnh hoặc âm thanh câu hỏi
router.delete(
  '/upload',
  verifyFirebaseToken,
  verifyUserStatus,
  requireAdmin,
  deleteQuestionMedia
);

// Xử lý lỗi Multer và lỗi upload
router.use((err, req, res, next) => {
  if (err instanceof require('multer').MulterError) {
    const message = err.code === 'LIMIT_FILE_SIZE'
      ? 'File vượt quá dung lượng tối đa 20 MB'
      : 'File upload không hợp lệ';

    return res.status(400).json({
      success: false,
      message,
    });
  }

  if (err) {
    return res.status(400).json({
      success: false,
      message: err.message || 'Không thể upload file',
    });
  }

  next();
});

module.exports = router;
