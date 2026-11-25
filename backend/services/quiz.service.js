
const supabase = require('../config/supabase');

function isValidUuid(id) {
  if (!id || typeof id !== 'string') return false;

  const uuidRegex =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

  return uuidRegex.test(id);
}

/**
 * Service xử lý nghiệp vụ thi và làm bài (Quiz Service)
 */

/**
 * Lấy danh sách câu hỏi an toàn cho bài thi (Giai đoạn 1).
 */
async function getSafeExamQuestions(examId) {
  const { data: exam, error: examError } = await supabase
    .from('de_thi')
    .select(
      'id, tieu_de, mo_ta, thoi_gian_lam_bai_giay, trang_thai, cong_khai'
    )
    .eq('id', examId)
    .maybeSingle();

  if (examError) {
    return { data: null, error: examError };
  }

  if (!exam) {
    return {
      data: null,
      error: {
        code: 'EXAM_NOT_FOUND',
        message: 'Đề thi không tồn tại',
      },
    };
  }

  let { data: questions, error: qError } = await supabase
    .from('cau_hoi')
    .select(`
      id,
      loai_cau_hoi_id,
      noi_dung,
      hinh_anh_url,
      am_thanh_url,
      diem,
      thoi_gian_giay,
      thu_tu,
      muc_do,
      dap_an (
        id,
        cau_hoi_id,
        noi_dung,
        hinh_anh_url,
        thu_tu
      )
    `)
    .eq('de_thi_id', examId)
    .order('thu_tu', { ascending: true });

  if (qError) {
    return { data: null, error: qError };
  }

  if (!questions || questions.length === 0) {
    const { data: links, error: linkError } = await supabase
      .from('de_thi_cau_hoi')
      .select('cau_hoi_id, thu_tu, diem')
      .eq('de_thi_id', examId)
      .order('thu_tu', { ascending: true });

    if (linkError) {
      return { data: null, error: linkError };
    }

    if (links && links.length > 0) {
      const questionIds = links.map((l) => l.cau_hoi_id);

      const { data: qLinked, error: qLinkedError } = await supabase
        .from('cau_hoi')
        .select(`
          id,
          loai_cau_hoi_id,
          noi_dung,
          hinh_anh_url,
          am_thanh_url,
          diem,
          thoi_gian_giay,
          thu_tu,
          muc_do,
          dap_an (
            id,
            cau_hoi_id,
            noi_dung,
            hinh_anh_url,
            thu_tu
          )
        `)
        .in('id', questionIds);

      if (qLinkedError) {
        return { data: null, error: qLinkedError };
      }

      const qMap = new Map((qLinked || []).map((q) => [q.id, q]));

      questions = links
        .map((l) => {
          const item = qMap.get(l.cau_hoi_id);

          if (!item) return null;

          return {
            ...item,
            thu_tu: l.thu_tu ?? item.thu_tu,
            diem: l.diem ?? item.diem,
          };
        })
        .filter(Boolean);
    }
  }

  const safeQuestions = (questions || []).map((q) => {
    const sortedAnswers = (q.dap_an || [])
      .map((a) => ({
        id: a.id,
        cau_hoi_id: a.cau_hoi_id,
        noi_dung: a.noi_dung,
        hinh_anh_url: a.hinh_anh_url,
        thu_tu: a.thu_tu,
      }))
      .sort((a, b) => a.thu_tu - b.thu_tu);

    return {
      id: q.id,
      loai_cau_hoi_id: q.loai_cau_hoi_id,
      noi_dung: q.noi_dung,
      hinh_anh_url: q.hinh_anh_url,
      am_thanh_url: q.am_thanh_url,
      diem: q.diem,
      thoi_gian_giay: q.thoi_gian_giay,
      thu_tu: q.thu_tu,
      muc_do: q.muc_do,
      dap_an: sortedAnswers,
    };
  });

  return {
    data: {
      exam: {
        id: exam.id,
        tieu_de: exam.tieu_de,
        mo_ta: exam.mo_ta,
        thoi_gian_lam_bai_giay: exam.thoi_gian_lam_bai_giay,
        tong_so_cau: safeQuestions.length,
      },
      questions: safeQuestions,
    },
    error: null,
  };
}

/**
 * Khởi tạo lượt thi mới (Giai đoạn 2).
 */
async function startAttempt({ userId, examId, gameModeId }) {
  const { data: exam, error: examError } = await supabase
    .from('de_thi')
    .select(
      'id, tieu_de, mo_ta, thoi_gian_lam_bai_giay, trang_thai, cong_khai'
    )
    .eq('id', examId)
    .maybeSingle();

  if (examError) {
    console.error('Lỗi truy vấn đề thi:', examError);

    return {
      data: null,
      error: {
        status: 500,
        message: 'Lỗi kiểm tra thông tin đề thi',
      },
    };
  }

  if (!exam) {
    return {
      data: null,
      error: {
        status: 404,
        message: 'Đề thi không tồn tại',
      },
    };
  }

  if (exam.trang_thai !== 'da_xuat_ban') {
    return {
      data: null,
      error: {
        status: 403,
        message: 'Đề thi chưa được xuất bản',
      },
    };
  }

  if (!exam.cong_khai) {
    return {
      data: null,
      error: {
        status: 403,
        message: 'Đề thi không được phép truy cập công khai',
      },
    };
  }

  const { data: gameMode, error: modeError } = await supabase
    .from('che_do_choi')
    .select('id, ma_che_do, ten_che_do, trang_thai')
    .eq('id', gameModeId)
    .maybeSingle();

  if (modeError) {
    console.error('Lỗi truy vấn chế độ chơi:', modeError);

    return {
      data: null,
      error: {
        status: 500,
        message: 'Lỗi kiểm tra chế độ chơi',
      },
    };
  }

  if (!gameMode) {
    return {
      data: null,
      error: {
        status: 404,
        message: 'Chế độ chơi không tồn tại',
      },
    };
  }

  if (gameMode.trang_thai !== true) {
    return {
      data: null,
      error: {
        status: 400,
        message: 'Chế độ chơi hiện đang bị vô hiệu hóa',
      },
    };
  }

  const { count: directCount, error: directCountErr } = await supabase
    .from('cau_hoi')
    .select('id', { count: 'exact', head: true })
    .eq('de_thi_id', examId);

  if (directCountErr) {
    console.error('Lỗi đếm câu hỏi trực tiếp:', directCountErr);

    return {
      data: null,
      error: {
        status: 500,
        message: 'Lỗi kiểm tra câu hỏi đề thi',
      },
    };
  }

  let totalQuestions = directCount || 0;

  if (totalQuestions === 0) {
    const { count: linkedCount, error: linkedCountErr } = await supabase
      .from('de_thi_cau_hoi')
      .select('id', { count: 'exact', head: true })
      .eq('de_thi_id', examId);

    if (linkedCountErr) {
      console.error('Lỗi đếm câu hỏi liên kết:', linkedCountErr);

      return {
        data: null,
        error: {
          status: 500,
          message: 'Lỗi kiểm tra câu hỏi liên kết đề thi',
        },
      };
    }

    totalQuestions = linkedCount || 0;
  }

  if (totalQuestions === 0) {
    return {
      data: null,
      error: {
        status: 400,
        message: 'Đề thi chưa có câu hỏi nào',
      },
    };
  }

  const newAttempt = {
    nguoi_dung_id: userId,
    de_thi_id: examId,
    che_do_choi_id: gameModeId,
    tong_so_cau: totalQuestions,
    tong_diem: 0,
    so_cau_dung: 0,
    so_cau_sai: 0,
    thoi_gian_lam_bai_giay: 0,
    trang_thai: 'dang_lam',
    bat_dau_luc: new Date().toISOString(),
  };

  const { data: attempt, error: insertError } = await supabase
    .from('lan_lam_bai')
    .insert([newAttempt])
    .select(`
      id,
      nguoi_dung_id,
      de_thi_id,
      che_do_choi_id,
      tong_so_cau,
      thoi_gian_lam_bai_giay,
      trang_thai,
      bat_dau_luc
    `)
    .single();

  if (insertError) {
    console.error('Lỗi khi tạo bản ghi lan_lam_bai:', insertError);

    return {
      data: null,
      error: {
        status: 500,
        message: 'Lỗi máy chủ khi tạo lượt thi',
      },
    };
  }

  return {
    data: {
      attempt: {
        id: attempt.id,
        de_thi_id: attempt.de_thi_id,
        che_do_choi_id: attempt.che_do_choi_id,
        tong_so_cau: attempt.tong_so_cau,
        thoi_gian_lam_bai_giay: attempt.thoi_gian_lam_bai_giay,
        trang_thai: attempt.trang_thai,
        bat_dau_luc: attempt.bat_dau_luc,
      },
      exam: {
        id: exam.id,
        tieu_de: exam.tieu_de,
        thoi_gian_lam_bai_giay: exam.thoi_gian_lam_bai_giay,
      },
      gameMode: {
        id: gameMode.id,
        ma_che_do: gameMode.ma_che_do,
        ten_che_do: gameMode.ten_che_do,
      },
    },
    error: null,
  };
}

/**
 * Nộp bài thi, chấm điểm độc lập phía Server và lưu kết quả an toàn.
 * Chỉ chấp nhận lưu qua PostgreSQL RPC submit_quiz_attempt.
 */
async function submitAttempt({ userId, attemptId, userAnswers }) {
  // 1. Kiểm tra lượt thi trong lan_lam_bai.
  const { data: attempt, error: attemptError } = await supabase
    .from('lan_lam_bai')
    .select(`
      id,
      nguoi_dung_id,
      de_thi_id,
      che_do_choi_id,
      tong_so_cau,
      trang_thai,
      bat_dau_luc,
      de_thi (
        id,
        tieu_de,
        thoi_gian_lam_bai_giay
      )
    `)
    .eq('id', attemptId)
    .maybeSingle();

  if (attemptError) {
    console.error('Lỗi kiểm tra lượt thi:', attemptError);

    return {
      data: null,
      error: {
        status: 500,
        message: 'Lỗi kiểm tra thông tin lượt thi',
      },
    };
  }

  if (!attempt) {
    return {
      data: null,
      error: {
        status: 404,
        message: 'Lượt thi không tồn tại',
      },
    };
  }

  // Kiểm tra quyền sở hữu lượt thi.
  if (attempt.nguoi_dung_id !== userId) {
    return {
      data: null,
      error: {
        status: 403,
        message: 'Bạn không có quyền nộp lượt thi của người dùng khác',
      },
    };
  }

  // Kiểm tra trạng thái lượt thi.
  if (attempt.trang_thai !== 'dang_lam') {
    return {
      data: null,
      error: {
        status: 400,
        message:
          'Lượt thi này đã hoàn thành hoặc không ở trạng thái đang làm',
      },
    };
  }

  const exam = attempt.de_thi;

  if (!exam) {
    return {
      data: null,
      error: {
        status: 404,
        message: 'Không tìm thấy thông tin đề thi của lượt thi này',
      },
    };
  }

  // 2. Tính thời gian làm bài theo đồng hồ Server.
  const now = new Date();
  const startTime = new Date(attempt.bat_dau_luc);

  const rawTimeSpentSeconds = Math.max(
    0,
    Math.round((now.getTime() - startTime.getTime()) / 1000)
  );

  // Thêm 15 giây độ trễ mạng chấp nhận được.
  const isOverdue =
    rawTimeSpentSeconds > exam.thoi_gian_lam_bai_giay + 15;

  const status = isOverdue ? 'qua_gio' : 'hoan_thanh';

  const finalTimeSpentSeconds = Math.min(
    rawTimeSpentSeconds,
    exam.thoi_gian_lam_bai_giay
  );

  // 3. Lấy toàn bộ câu hỏi và đáp án thật từ Database.
  let { data: questions, error: qError } = await supabase
    .from('cau_hoi')
    .select(`
      id,
      loai_cau_hoi_id,
      noi_dung,
      giai_thich,
      hinh_anh_url,
      am_thanh_url,
      diem,
      thoi_gian_giay,
      thu_tu,
      muc_do,
      loai_cau_hoi (
        id,
        ma_loai,
        ten_loai
      ),
      dap_an (
        id,
        cau_hoi_id,
        noi_dung,
        hinh_anh_url,
        la_dung,
        thu_tu
      )
    `)
    .eq('de_thi_id', attempt.de_thi_id)
    .order('thu_tu', { ascending: true });

  if (qError) {
    console.error('Lỗi lấy câu hỏi đề thi:', qError);

    return {
      data: null,
      error: {
        status: 500,
        message: 'Lỗi tải dữ liệu câu hỏi từ hệ thống',
      },
    };
  }

  if (!questions || questions.length === 0) {
    const { data: links, error: linkError } = await supabase
      .from('de_thi_cau_hoi')
      .select('cau_hoi_id, thu_tu, diem')
      .eq('de_thi_id', attempt.de_thi_id)
      .order('thu_tu', { ascending: true });

    if (linkError) {
      return {
        data: null,
        error: {
          status: 500,
          message: 'Lỗi tải liên kết câu hỏi',
        },
      };
    }

    if (links && links.length > 0) {
      const qIds = links.map((l) => l.cau_hoi_id);

      const { data: qLinked, error: qLinkedErr } = await supabase
        .from('cau_hoi')
        .select(`
          id,
          loai_cau_hoi_id,
          noi_dung,
          giai_thich,
          hinh_anh_url,
          am_thanh_url,
          diem,
          thoi_gian_giay,
          thu_tu,
          muc_do,
          loai_cau_hoi (
            id,
            ma_loai,
            ten_loai
          ),
          dap_an (
            id,
            cau_hoi_id,
            noi_dung,
            hinh_anh_url,
            la_dung,
            thu_tu
          )
        `)
        .in('id', qIds);

      if (qLinkedErr) {
        return {
          data: null,
          error: {
            status: 500,
            message: 'Lỗi tải câu hỏi liên kết',
          },
        };
      }

      const qMap = new Map((qLinked || []).map((q) => [q.id, q]));

      questions = links
        .map((l) => {
          const item = qMap.get(l.cau_hoi_id);

          if (!item) return null;

          return {
            ...item,
            thu_tu: l.thu_tu ?? item.thu_tu,
            diem: l.diem ?? item.diem,
          };
        })
        .filter(Boolean);
    }
  }

  if (!questions || questions.length === 0) {
    return {
      data: null,
      error: {
        status: 400,
        message: 'Đề thi của lượt thi này không có câu hỏi nào',
      },
    };
  }

  // 4. Kiểm tra dữ liệu bài làm do client gửi lên.
  if (!Array.isArray(userAnswers)) {
    return {
      data: null,
      error: {
        status: 400,
        message: 'Trường answers bắt buộc phải là một mảng',
      },
    };
  }

  const examQuestionMap = new Map(
    questions.map((q) => [q.id, q])
  );

  const seenQuestionIds = new Set();
  const submittedMap = new Map();

  for (const item of userAnswers) {
    if (!item || typeof item !== 'object' || Array.isArray(item)) {
      return {
        data: null,
        error: {
          status: 400,
          message:
            'Mỗi phần tử trong answers phải là một đối tượng hợp lệ',
        },
      };
    }

    const qId = item.questionId;

    if (!isValidUuid(qId)) {
      return {
        data: null,
        error: {
          status: 400,
          message: `Mã câu hỏi (questionId) '${qId}' không hợp lệ`,
        },
      };
    }

    // Không cho phép câu hỏi bị trùng trong request.
    if (seenQuestionIds.has(qId)) {
      return {
        data: null,
        error: {
          status: 400,
          message: `Câu hỏi ${qId} bị lặp lại trong danh sách câu trả lời`,
        },
      };
    }

    seenQuestionIds.add(qId);

    if (!examQuestionMap.has(qId)) {
      return {
        data: null,
        error: {
          status: 400,
          message: `Câu hỏi ${qId} không thuộc đề thi của lượt thi này`,
        },
      };
    }

    const question = examQuestionMap.get(qId);

    // Không tự suy đoán cách chấm điểm loại câu hỏi chưa hỗ trợ.
    const questionType = question.loai_cau_hoi?.ma_loai;

    if (!questionType) {
      return {
        data: null,
        error: {
          status: 500,
          message: `Không thể xác định loại câu hỏi cho câu hỏi ${qId}`,
        },
      };
    }

    if (questionType !== 'mot_dap_an') {
      return {
        data: null,
        error: {
          status: 400,
          message: `Loại câu hỏi '${questionType}' chưa được hỗ trợ chấm điểm tự động`,
        },
      };
    }

    if (
      item.selectedAnswerIds !== undefined &&
      !Array.isArray(item.selectedAnswerIds)
    ) {
      return {
        data: null,
        error: {
          status: 400,
          message: `Trường selectedAnswerIds của câu hỏi ${qId} phải là một mảng`,
        },
      };
    }

    const selectedIds = item.selectedAnswerIds || [];

    // Kiểm tra UUID và đáp án trùng.
    const seenAnswerIds = new Set();

    for (const ansId of selectedIds) {
      if (!isValidUuid(ansId)) {
        return {
          data: null,
          error: {
            status: 400,
            message: `Mã đáp án '${ansId}' trong câu hỏi ${qId} không hợp lệ`,
          },
        };
      }

      if (seenAnswerIds.has(ansId)) {
        return {
          data: null,
          error: {
            status: 400,
            message: `Đáp án ${ansId} bị lặp lại trong cùng câu hỏi ${qId}`,
          },
        };
      }

      seenAnswerIds.add(ansId);
    }

    // Loại mot_dap_an không được chọn nhiều hơn một đáp án.
    if (selectedIds.length > 1) {
      return {
        data: null,
        error: {
          status: 400,
          message: `Câu hỏi ${qId} là trắc nghiệm 1 đáp án, không được chọn nhiều đáp án`,
        },
      };
    }

    // Kiểm tra đáp án có thuộc câu hỏi tương ứng không.
    const validAnswerIds = new Set(
      (question.dap_an || []).map((a) => a.id)
    );

    for (const ansId of selectedIds) {
      if (!validAnswerIds.has(ansId)) {
        return {
          data: null,
          error: {
            status: 400,
            message: `Đáp án ${ansId} không thuộc câu hỏi ${qId}`,
          },
        };
      }
    }

    submittedMap.set(qId, selectedIds);
  }

  // 5. Chấm điểm độc lập phía Server.
  let totalScore = 0;
  let correctCount = 0;
  let wrongCount = 0;

  const totalQuestions = questions.length;
  const questionDetailsToSave = [];

  for (const q of questions) {
    const selectedIds = submittedMap.get(q.id) || [];
    const answersList = q.dap_an || [];

    let isCorrect = false;
    let earnedPoints = 0;

    const selectedAnswerRecords = [];

    // Kiểm tra điểm câu hỏi từ Database.
    // Chấp nhận number hoặc chuỗi số không rỗng.
    const hasValidPointsType =
      typeof q.diem === 'number' ||
      (typeof q.diem === 'string' && q.diem.trim() !== '');

    if (!hasValidPointsType) {
      return {
        data: null,
        error: {
          status: 500,
          message: `Điểm số của câu hỏi ${q.id} bị thiếu hoặc không hợp lệ trong cơ sở dữ liệu`,
        },
      };
    }

    const questionPoints = Number(q.diem);

    if (
      !Number.isFinite(questionPoints) ||
      questionPoints < 0
    ) {
      return {
        data: null,
        error: {
          status: 500,
          message: `Điểm số của câu hỏi ${q.id} không hợp lệ hoặc bị âm trong cơ sở dữ liệu`,
        },
      };
    }

    if (selectedIds.length > 0) {
      const chosenId = selectedIds[0];

      const matchedChoice = answersList.find(
        (a) => a.id === chosenId
      );

      if (matchedChoice && matchedChoice.la_dung === true) {
        // Trả lời đúng: nhận chính xác điểm câu hỏi.
        isCorrect = true;
        earnedPoints = questionPoints;

        correctCount++;
        totalScore += earnedPoints;
      } else {
        // Trả lời sai: 0 điểm.
        isCorrect = false;
        earnedPoints = 0;

        wrongCount++;
      }

      if (matchedChoice) {
        selectedAnswerRecords.push({
          dap_an_id: matchedChoice.id,
          noi_dung_tra_loi: matchedChoice.noi_dung,
          thu_tu_lua_chon: 1,
        });
      }
    } else {
      // Bỏ trống: 0 điểm, không tăng số câu sai.
      isCorrect = false;
      earnedPoints = 0;
    }

    const questionSnapshot = {
      id: q.id,
      noi_dung: q.noi_dung,
      hinh_anh_url: q.hinh_anh_url,
      am_thanh_url: q.am_thanh_url,
      diem: q.diem,
      thoi_gian_giay: q.thoi_gian_giay,
      thu_tu: q.thu_tu,
      muc_do: q.muc_do,
      giai_thich: q.giai_thich,
    };

    const answersSnapshot = answersList.map((a) => ({
      id: a.id,
      cau_hoi_id: a.cau_hoi_id,
      noi_dung: a.noi_dung,
      hinh_anh_url: a.hinh_anh_url,
      la_dung: a.la_dung,
      thu_tu: a.thu_tu,
    }));

    questionDetailsToSave.push({
      cau_hoi_id: q.id,
      diem_dat_duoc: earnedPoints,
      la_dung: isCorrect,
      thoi_gian_tra_loi_giay: 0,
      thu_tu: q.thu_tu,
      cau_hoi_snapshot: questionSnapshot,
      dap_an_snapshot: answersSnapshot,
      dap_an_da_chon: selectedAnswerRecords,
    });
  }

  const unansweredCount =
    totalQuestions - correctCount - wrongCount;

  // Giữ quy tắc làm tròn tổng điểm đến 2 chữ số thập phân.
  const roundedTotalScore =
    Math.round(totalScore * 100) / 100;

  // 6. Lưu dữ liệu duy nhất qua PostgreSQL RPC.
  const { data: rpcRes, error: rpcErr } = await supabase.rpc(
    'submit_quiz_attempt',
    {
      p_attempt_id: attemptId,
      p_user_id: userId,
      p_status: status,
      p_time_spent: finalTimeSpentSeconds,
      p_end_time: now.toISOString(),
      p_total_score: roundedTotalScore,
      p_correct_count: correctCount,
      p_wrong_count: wrongCount,
      p_total_questions: totalQuestions,
      p_details: questionDetailsToSave,
    }
  );

  if (rpcErr) {
    console.error(
      'Lỗi thực thi PostgreSQL RPC submit_quiz_attempt:',
      rpcErr
    );

    if (rpcErr.code === 'P0002') {
      return {
        data: null,
        error: {
          status: 404,
          message: 'Lượt thi không tồn tại',
        },
      };
    }

    if (rpcErr.code === '42501') {
      return {
        data: null,
        error: {
          status: 403,
          message: 'Bạn không có quyền nộp lượt thi này',
        },
      };
    }

    if (
      rpcErr.code === '23505' ||
      rpcErr.message?.includes('ATTEMPT_ALREADY_COMPLETED')
    ) {
      return {
        data: null,
        error: {
          status: 400,
          message:
            'Lượt thi này đã hoàn thành hoặc không ở trạng thái đang làm',
        },
      };
    }

    if (rpcErr.code === '22023' || rpcErr.code === '22004') {
      return {
        data: null,
        error: {
          status: 400,
          message: `Dữ liệu nộp bài không hợp lệ: ${rpcErr.message}`,
        },
      };
    }

    if (rpcErr.code === 'PGRST202') {
      return {
        data: null,
        error: {
          status: 503,
          message:
            'Hệ thống chưa kích hoạt hàm lưu kết quả thi nguyên tử (Vui lòng thực thi migration 01_submit_quiz_attempt.sql trong Supabase SQL Editor)',
        },
      };
    }

    return {
      data: null,
      error: {
        status: 500,
        message: 'Lỗi thực thi giao dịch lưu kết quả thi',
      },
    };
  }

  return {
    data: {
      attemptId,
      totalScore: roundedTotalScore,
      correctCount,
      wrongCount,
      unansweredCount,
      totalQuestions,
      timeSpentSeconds: finalTimeSpentSeconds,
      status,
    },
    error: null,
  };
}

module.exports = {
  getSafeExamQuestions,
  startAttempt,
  submitAttempt,
};
