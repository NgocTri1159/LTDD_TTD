
const express = require('express');
const router = express.Router();

const {
  verifyFirebaseToken,
  verifyUserStatus,
} = require('../middleware/auth_middleware');

const quizController = require('../controllers/quiz.controller');

// ==========================================
// 1. LAY DANH SACH CAU HOI DE THI
// GET /api/quiz/exams/:examId/questions
// ==========================================
router.get(
  '/exams/:examId/questions',
  verifyFirebaseToken,
  verifyUserStatus,
  quizController.getExamQuestions
);

// ==========================================
// 2. BAT DAU LUOT LAM BAI
// POST /api/quiz/attempts/start
// ==========================================
router.post(
  '/attempts/start',
  verifyFirebaseToken,
  verifyUserStatus,
  quizController.startAttempt
);

// ==========================================
// 3. NOP BAI THI
// POST /api/quiz/attempts/:attemptId/submit
// ==========================================
router.post(
  '/attempts/:attemptId/submit',
  verifyFirebaseToken,
  verifyUserStatus,
  quizController.submitAttempt
);

module.exports = router;
