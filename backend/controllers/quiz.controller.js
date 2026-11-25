const quizService = require('../services/quiz.service');

function isValidUuid(id) {
  if (!id || typeof id !== 'string') return false;
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  return uuidRegex.test(id);
}

/**
 * GET /api/quiz/exams/:examId/questions
 * Lấy danh sách câu hỏi làm bài (Đã ẩn la_dung và giai_thich)
 */
async function getExamQuestions(req, res) {
  const { examId } = req.params;

  if (!isValidUuid(examId)) {
    return res.status(400).json({
      success: false,
      message: 'Mã đề thi không hợp lệ',
    });
  }

  try {
    const { data, error } = await quizService.getSafeExamQuestions(examId);

    if (error) {
      if (error.code === 'EXAM_NOT_FOUND') {
        return res.status(404).json({
          success: false,
          message: error.message,
        });
      }

      console.error('Lỗi Supabase khi tải câu hỏi bài thi:', error);
      return res.status(500).json({
        success: false,
        message: 'Lỗi máy chủ khi tải câu hỏi bài thi',
      });
    }

    return res.json({
      success: true,
      message: 'Tải danh sách câu hỏi an toàn thành công',
      data,
    });
  } catch (e) {
    console.error('Lỗi ngoại lệ getExamQuestions:', e);
    return res.status(500).json({
      success: false,
      message: 'Lỗi máy chủ nội bộ',
    });
  }
}

/**
 * POST /api/quiz/attempts/start
 * Khởi tạo lượt làm bài mới (Giai đoạn 2)
 */
async function startAttempt(req, res) {
  const { examId, gameModeId } = req.body || {};

  // 1. Kiểm tra định dạng examId và gameModeId
  if (!examId || !isValidUuid(examId)) {
    return res.status(400).json({
      success: false,
      message: 'examId không hợp lệ hoặc không được để trống',
    });
  }

  if (!gameModeId || !isValidUuid(gameModeId)) {
    return res.status(400).json({
      success: false,
      message: 'gameModeId không hợp lệ hoặc không được để trống',
    });
  }

  // 2. Lấy userId từ Firebase token qua req.auth.uid (Tuyệt đối không nhận từ body)
  const userId = req.auth?.uid;
  if (!userId) {
    return res.status(401).json({
      success: false,
      message: 'Yêu cầu xác thực tài khoản người dùng',
    });
  }

  try {
    const { data, error } = await quizService.startAttempt({
      userId,
      examId,
      gameModeId,
    });

    if (error) {
      const status = error.status || 500;
      return res.status(status).json({
        success: false,
        message: error.message || 'Không thể bắt đầu lượt thi',
      });
    }

    return res.status(201).json({
      success: true,
      message: 'Bắt đầu bài thi thành công',
      data,
    });
  } catch (e) {
    console.error('Lỗi ngoại lệ startAttempt:', e);
    return res.status(500).json({
      success: false,
      message: 'Lỗi máy chủ nội bộ',
    });
  }
}

/**
 * POST /api/quiz/attempts/:attemptId/submit
 * Nộp bài thi, chấm điểm độc lập phía Server và lưu kết quả (Giai đoạn 3)
 */
async function submitAttempt(req, res) {
  const { attemptId } = req.params;

  // 1. Kiểm tra attemptId
  if (!isValidUuid(attemptId)) {
    return res.status(400).json({
      success: false,
      message: 'Mã lượt thi (attemptId) không hợp lệ',
    });
  }

  // 2. Lấy userId từ Firebase token qua req.auth.uid (Tuyệt đối không nhận từ body)
  const userId = req.auth?.uid;
  if (!userId) {
    return res.status(401).json({
      success: false,
      message: 'Yêu cầu xác thực tài khoản người dùng',
    });
  }

  // 3. Kiểm tra mảng answers bắt buộc
  const userAnswers = req.body?.answers;
  if (!Array.isArray(userAnswers)) {
    return res.status(400).json({
      success: false,
      message: 'Trường answers bắt buộc phải là một mảng',
    });
  }

  try {
    const { data, error } = await quizService.submitAttempt({
      userId,
      attemptId,
      userAnswers,
    });

    if (error) {
      const status = error.status || 500;
      return res.status(status).json({
        success: false,
        message: error.message || 'Lỗi khi nộp bài thi',
      });
    }

    return res.json({
      success: true,
      message: 'Nộp bài thành công',
      data,
    });
  } catch (e) {
    console.error('Lỗi ngoại lệ submitAttempt:', e);
    return res.status(500).json({
      success: false,
      message: 'Lỗi máy chủ nội bộ',
    });
  }
}

module.exports = {
  getExamQuestions,
  startAttempt,
  submitAttempt,
};
