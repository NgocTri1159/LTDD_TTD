
-- ======================================================================
-- MIGRATION: 01_submit_quiz_attempt.sql
-- QUIZMASTER: RPC Function nộp bài và chấm điểm nguyên tử
-- ======================================================================

CREATE OR REPLACE FUNCTION public.submit_quiz_attempt(
  p_attempt_id UUID,
  p_user_id TEXT,
  p_status TEXT,
  p_time_spent INTEGER,
  p_end_time TIMESTAMPTZ,
  p_total_score NUMERIC,
  p_correct_count INTEGER,
  p_wrong_count INTEGER,
  p_total_questions INTEGER,
  p_details JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_attempt RECORD;
  v_item JSONB;
  v_detail_id UUID;
  v_choice JSONB;
  v_cau_hoi_id UUID;
  v_dap_an_id UUID;
  v_item_is_correct BOOLEAN;
  v_item_score NUMERIC;
  v_thoi_gian_tra_loi INTEGER;
  v_thu_tu INTEGER;
  v_thu_tu_lua_chon INTEGER;
  v_choice_count INTEGER;

  v_calc_correct_count INTEGER := 0;
  v_calc_wrong_count INTEGER := 0;
  v_calc_unanswered_count INTEGER := 0;
  v_calc_total_score NUMERIC := 0.0;
BEGIN
  -- 1. Kiểm tra tham số bắt buộc.
  IF p_attempt_id IS NULL OR
     p_user_id IS NULL OR
     p_status IS NULL OR
     p_time_spent IS NULL OR
     p_end_time IS NULL OR
     p_total_score IS NULL OR
     p_correct_count IS NULL OR
     p_wrong_count IS NULL OR
     p_total_questions IS NULL OR
     p_details IS NULL THEN
    RAISE EXCEPTION 'ALL_PARAMETERS_REQUIRED_AND_NON_NULL'
      USING ERRCODE = '22004';
  END IF;

  -- 2. Kiểm tra trạng thái.
  IF p_status NOT IN ('hoan_thanh', 'qua_gio') THEN
    RAISE EXCEPTION 'INVALID_STATUS'
      USING ERRCODE = '22023';
  END IF;

  -- Kiểm tra tổng điểm không âm, không NaN, không Infinity.
  IF p_total_score::TEXT ~* '^(nan|infinity|-infinity)$' OR
     p_total_score < 0 THEN
    RAISE EXCEPTION 'INVALID_OR_NEGATIVE_TOTAL_SCORE'
      USING ERRCODE = '22023';
  END IF;

  -- Kiểm tra các chỉ số không âm.
  IF p_time_spent < 0 OR
     p_correct_count < 0 OR
     p_wrong_count < 0 OR
     p_total_questions < 0 THEN
    RAISE EXCEPTION 'NEGATIVE_METRICS_NOT_ALLOWED'
      USING ERRCODE = '22023';
  END IF;

  IF (p_correct_count + p_wrong_count) > p_total_questions THEN
    RAISE EXCEPTION 'SUM_CORRECT_WRONG_EXCEEDS_TOTAL'
      USING ERRCODE = '22023';
  END IF;

  -- 3. Kiểm tra p_details phải là JSON array.
  IF jsonb_typeof(p_details) <> 'array' THEN
    RAISE EXCEPTION 'DETAILS_MUST_BE_ARRAY'
      USING ERRCODE = '22023';
  END IF;

  IF jsonb_array_length(p_details) <> p_total_questions THEN
    RAISE EXCEPTION 'DETAILS_COUNT_MISMATCH'
      USING ERRCODE = '22023';
  END IF;

  -- Kiểm tra không có câu hỏi trùng lặp.
  IF (
    SELECT COUNT(DISTINCT (item->>'cau_hoi_id'))
    FROM jsonb_array_elements(p_details) AS item
  ) <> p_total_questions THEN
    RAISE EXCEPTION 'DUPLICATE_QUESTION_IN_DETAILS'
      USING ERRCODE = '23505';
  END IF;

  -- 4. Khóa lượt thi để chống nộp đồng thời.
  SELECT
    id,
    nguoi_dung_id,
    de_thi_id,
    tong_so_cau,
    trang_thai
  INTO v_attempt
  FROM public.lan_lam_bai
  WHERE id = p_attempt_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'ATTEMPT_NOT_FOUND'
      USING ERRCODE = 'P0002';
  END IF;

  -- Kiểm tra quyền sở hữu.
  IF v_attempt.nguoi_dung_id IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'UNAUTHORIZED_ATTEMPT'
      USING ERRCODE = '42501';
  END IF;

  -- Kiểm tra trạng thái lượt thi.
  IF v_attempt.trang_thai IS DISTINCT FROM 'dang_lam' THEN
    RAISE EXCEPTION 'ATTEMPT_ALREADY_COMPLETED'
      USING ERRCODE = '23505';
  END IF;

  -- Đối chiếu tổng số câu.
  IF v_attempt.tong_so_cau IS DISTINCT FROM p_total_questions THEN
    RAISE EXCEPTION 'TOTAL_QUESTIONS_MISMATCH_WITH_ATTEMPT'
      USING ERRCODE = '22023';
  END IF;

  -- 5. Tiền kiểm tra toàn bộ chi tiết trước khi ghi dữ liệu.
  FOR v_item IN
    SELECT value
    FROM jsonb_array_elements(p_details) AS value
  LOOP
    IF v_item IS NULL OR jsonb_typeof(v_item) <> 'object' THEN
      RAISE EXCEPTION 'DETAIL_ITEM_MUST_BE_OBJECT'
        USING ERRCODE = '22023';
    END IF;

    -- Kiểm tra UUID câu hỏi.
    IF (v_item->>'cau_hoi_id') IS NULL OR
       NOT (
         (v_item->>'cau_hoi_id') ~*
         '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
       ) THEN
      RAISE EXCEPTION 'INVALID_OR_NULL_CAU_HOI_ID'
        USING ERRCODE = '22023';
    END IF;

    v_cau_hoi_id := (v_item->>'cau_hoi_id')::UUID;

    -- Câu hỏi phải thuộc đề thi.
    IF NOT EXISTS (
      SELECT 1
      FROM public.cau_hoi
      WHERE id = v_cau_hoi_id
        AND de_thi_id = v_attempt.de_thi_id

      UNION ALL

      SELECT 1
      FROM public.de_thi_cau_hoi
      WHERE cau_hoi_id = v_cau_hoi_id
        AND de_thi_id = v_attempt.de_thi_id
    ) THEN
      RAISE EXCEPTION 'QUESTION_NOT_BELONG_TO_EXAM'
        USING ERRCODE = '22023';
    END IF;

    -- Kiểm tra điểm đạt được.
    IF (v_item->>'diem_dat_duoc') IS NULL OR
       NOT (
         (v_item->>'diem_dat_duoc') ~* '^[0-9]+(\.[0-9]+)?$'
       ) THEN
      RAISE EXCEPTION 'INVALID_OR_NEGATIVE_DIEM_DAT_DUOC'
        USING ERRCODE = '22023';
    END IF;

    v_item_score := (v_item->>'diem_dat_duoc')::NUMERIC;

    IF v_item_score = 'NaN'::NUMERIC OR
       v_item_score < 0 THEN
      RAISE EXCEPTION 'INVALID_OR_NEGATIVE_DIEM_DAT_DUOC'
        USING ERRCODE = '22023';
    END IF;

    -- Kiểm tra la_dung.
    IF (v_item->>'la_dung') IS NULL OR
       (v_item->>'la_dung') NOT IN ('true', 'false') THEN
      RAISE EXCEPTION 'INVALID_LA_DUNG'
        USING ERRCODE = '22023';
    END IF;

    v_item_is_correct := (v_item->>'la_dung')::BOOLEAN;

    -- Kiểm tra mảng đáp án được chọn.
    IF (v_item ? 'dap_an_da_chon') AND
       (v_item->'dap_an_da_chon' IS NOT NULL) AND
       (jsonb_typeof(v_item->'dap_an_da_chon') <> 'null') THEN

      IF jsonb_typeof(v_item->'dap_an_da_chon') <> 'array' THEN
        RAISE EXCEPTION 'DAP_AN_DA_CHON_MUST_BE_ARRAY'
          USING ERRCODE = '22023';
      END IF;

      v_choice_count :=
        jsonb_array_length(v_item->'dap_an_da_chon');
    ELSE
      v_choice_count := 0;
    END IF;

    -- Hiện chỉ hỗ trợ mot_dap_an.
    IF v_choice_count > 1 THEN
      RAISE EXCEPTION 'MULTIPLE_ANSWERS_NOT_ALLOWED'
        USING ERRCODE = '22023';
    END IF;

    -- Kiểm tra logic đúng / sai / bỏ trống.
    IF v_item_is_correct = TRUE THEN

      -- Câu đúng bắt buộc có đúng một đáp án được chọn.
      IF v_choice_count <> 1 THEN
        RAISE EXCEPTION 'CORRECT_QUESTION_MUST_HAVE_CHOSEN_ANSWER'
          USING ERRCODE = '22023';
      END IF;

      v_calc_correct_count := v_calc_correct_count + 1;
      v_calc_total_score := v_calc_total_score + v_item_score;

    ELSE

      IF v_choice_count > 0 THEN

        -- Câu sai phải có 0 điểm.
        IF v_item_score <> 0 THEN
          RAISE EXCEPTION 'WRONG_ANSWER_MUST_HAVE_ZERO_POINTS'
            USING ERRCODE = '22023';
        END IF;

        v_calc_wrong_count := v_calc_wrong_count + 1;

      ELSE

        -- Câu bỏ trống: la_dung=false, điểm=0, lựa chọn rỗng.
        IF v_item_score <> 0 THEN
          RAISE EXCEPTION 'UNANSWERED_QUESTION_MUST_HAVE_ZERO_POINTS'
            USING ERRCODE = '22023';
        END IF;

        v_calc_unanswered_count :=
          v_calc_unanswered_count + 1;

      END IF;
    END IF;

    -- Kiểm tra cấu trúc snapshot.
    IF NOT (v_item ? 'cau_hoi_snapshot') OR
       jsonb_typeof(v_item->'cau_hoi_snapshot') <> 'object' THEN
      RAISE EXCEPTION 'CAU_HOI_SNAPSHOT_MUST_BE_OBJECT'
        USING ERRCODE = '22023';
    END IF;

    IF NOT (v_item ? 'dap_an_snapshot') OR
       jsonb_typeof(v_item->'dap_an_snapshot') <> 'array' THEN
      RAISE EXCEPTION 'DAP_AN_SNAPSHOT_MUST_BE_ARRAY'
        USING ERRCODE = '22023';
    END IF;

    -- Kiểm tra từng phần tử lựa chọn trước khi ghi.
    IF v_choice_count > 0 THEN
      FOR v_choice IN
        SELECT value
        FROM jsonb_array_elements(v_item->'dap_an_da_chon') AS value
      LOOP
        IF v_choice IS NULL OR
           jsonb_typeof(v_choice) <> 'object' THEN
          RAISE EXCEPTION 'CHOICE_ITEM_MUST_BE_OBJECT'
            USING ERRCODE = '22023';
        END IF;

        IF (v_choice->>'dap_an_id') IS NULL OR
           NOT (
             (v_choice->>'dap_an_id') ~*
             '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
           ) THEN
          RAISE EXCEPTION 'INVALID_OR_NULL_DAP_AN_ID'
            USING ERRCODE = '22023';
        END IF;

        v_dap_an_id := (v_choice->>'dap_an_id')::UUID;

        IF NOT EXISTS (
          SELECT 1
          FROM public.dap_an
          WHERE id = v_dap_an_id
            AND cau_hoi_id = v_cau_hoi_id
        ) THEN
          RAISE EXCEPTION 'ANSWER_NOT_BELONG_TO_QUESTION'
            USING ERRCODE = '22023';
        END IF;

        -- Kiểm tra thứ tự lựa chọn nếu được truyền.
        IF (v_choice ? 'thu_tu_lua_chon') AND
           (v_choice->'thu_tu_lua_chon' IS NOT NULL) AND
           (jsonb_typeof(v_choice->'thu_tu_lua_chon') <> 'null') THEN

          IF NOT (
            (v_choice->>'thu_tu_lua_chon') ~* '^[0-9]+$'
          ) THEN
            RAISE EXCEPTION 'INVALID_THU_TU_LUA_CHON'
              USING ERRCODE = '22023';
          END IF;

          v_thu_tu_lua_chon :=
            (v_choice->>'thu_tu_lua_chon')::INTEGER;
        ELSE
          v_thu_tu_lua_chon := 1;
        END IF;
      END LOOP;
    END IF;

  END LOOP;

  -- 6. Đối chiếu số câu đúng.
  IF p_correct_count <> v_calc_correct_count THEN
    RAISE EXCEPTION 'CORRECT_COUNT_MISMATCH'
      USING ERRCODE = '22023';
  END IF;

  -- Đối chiếu số câu sai.
  IF p_wrong_count <> v_calc_wrong_count THEN
    RAISE EXCEPTION 'WRONG_COUNT_MISMATCH'
      USING ERRCODE = '22023';
  END IF;

  -- Đối chiếu tổng số câu đúng + sai + bỏ trống.
  IF (
    v_calc_correct_count +
    v_calc_wrong_count +
    v_calc_unanswered_count
  ) <> p_total_questions THEN
    RAISE EXCEPTION 'ANSWER_COUNTS_DO_NOT_MATCH_TOTAL'
      USING ERRCODE = '22023';
  END IF;

  -- Đối chiếu tổng điểm sau khi làm tròn 2 chữ số.
  IF ROUND(v_calc_total_score, 2) <> p_total_score THEN
    RAISE EXCEPTION 'TOTAL_SCORE_MISMATCH'
      USING ERRCODE = '22023';
  END IF;

  -- 7. Cập nhật lượt thi.
  UPDATE public.lan_lam_bai
  SET
    tong_diem = p_total_score,
    so_cau_dung = p_correct_count,
    so_cau_sai = p_wrong_count,
    tong_so_cau = p_total_questions,
    thoi_gian_lam_bai_giay = p_time_spent,
    trang_thai = p_status,
    ket_thuc_luc = p_end_time
  WHERE id = p_attempt_id;

  -- 8. Ghi chi tiết từng câu hỏi và đáp án đã chọn.
  FOR v_item IN
    SELECT value
    FROM jsonb_array_elements(p_details) AS value
  LOOP
    v_cau_hoi_id := (v_item->>'cau_hoi_id')::UUID;

    -- Thời gian trả lời.
    IF (v_item ? 'thoi_gian_tra_loi_giay') AND
       (v_item->'thoi_gian_tra_loi_giay' IS NOT NULL) AND
       (jsonb_typeof(v_item->'thoi_gian_tra_loi_giay') <> 'null') THEN

      IF NOT (
        (v_item->>'thoi_gian_tra_loi_giay') ~* '^[0-9]+$'
      ) THEN
        RAISE EXCEPTION 'INVALID_THOI_GIAN_TRA_LOI_GIAY'
          USING ERRCODE = '22023';
      END IF;

      v_thoi_gian_tra_loi :=
        (v_item->>'thoi_gian_tra_loi_giay')::INTEGER;
    ELSE
      v_thoi_gian_tra_loi := 0;
    END IF;

    -- Thứ tự câu hỏi.
    IF (v_item ? 'thu_tu') AND
       (v_item->'thu_tu' IS NOT NULL) AND
       (jsonb_typeof(v_item->'thu_tu') <> 'null') THEN

      IF NOT ((v_item->>'thu_tu') ~* '^[0-9]+$') THEN
        RAISE EXCEPTION 'INVALID_THU_TU'
          USING ERRCODE = '22023';
      END IF;

      v_thu_tu := (v_item->>'thu_tu')::INTEGER;
    ELSE
      v_thu_tu := 1;
    END IF;

    -- Ghi chi tiết câu hỏi.
    INSERT INTO public.chi_tiet_lam_bai (
      lan_lam_bai_id,
      cau_hoi_id,
      diem_dat_duoc,
      la_dung,
      thoi_gian_tra_loi_giay,
      thu_tu,
      cau_hoi_snapshot,
      dap_an_snapshot
    )
    VALUES (
      p_attempt_id,
      v_cau_hoi_id,
      (v_item->>'diem_dat_duoc')::NUMERIC,
      (v_item->>'la_dung')::BOOLEAN,
      v_thoi_gian_tra_loi,
      v_thu_tu,
      v_item->'cau_hoi_snapshot',
      v_item->'dap_an_snapshot'
    )
    RETURNING id INTO v_detail_id;

    -- Ghi đáp án đã chọn nếu có.
    IF (v_item ? 'dap_an_da_chon') AND
       (v_item->'dap_an_da_chon' IS NOT NULL) AND
       (jsonb_typeof(v_item->'dap_an_da_chon') <> 'null') AND
       jsonb_array_length(v_item->'dap_an_da_chon') > 0 THEN

      FOR v_choice IN
        SELECT value
        FROM jsonb_array_elements(v_item->'dap_an_da_chon') AS value
      LOOP
        v_dap_an_id := (v_choice->>'dap_an_id')::UUID;

        IF (v_choice ? 'thu_tu_lua_chon') AND
           (v_choice->'thu_tu_lua_chon' IS NOT NULL) AND
           (jsonb_typeof(v_choice->'thu_tu_lua_chon') <> 'null') THEN

          v_thu_tu_lua_chon :=
            (v_choice->>'thu_tu_lua_chon')::INTEGER;
        ELSE
          v_thu_tu_lua_chon := 1;
        END IF;

        INSERT INTO public.dap_an_da_chon (
          chi_tiet_lam_bai_id,
          dap_an_id,
          noi_dung_tra_loi,
          thu_tu_lua_chon
        )
        VALUES (
          v_detail_id,
          v_dap_an_id,
          v_choice->>'noi_dung_tra_loi',
          v_thu_tu_lua_chon
        );
      END LOOP;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'attempt_id', p_attempt_id,
    'total_score', p_total_score,
    'correct_count', p_correct_count,
    'wrong_count', p_wrong_count,
    'status', p_status
  );
END;
$$;

-- ======================================================================
-- PHÂN QUYỀN VÀ BẢO MẬT FUNCTION
-- ======================================================================

REVOKE ALL ON FUNCTION public.submit_quiz_attempt(
  UUID,
  TEXT,
  TEXT,
  INTEGER,
  TIMESTAMPTZ,
  NUMERIC,
  INTEGER,
  INTEGER,
  INTEGER,
  JSONB
) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.submit_quiz_attempt(
  UUID,
  TEXT,
  TEXT,
  INTEGER,
  TIMESTAMPTZ,
  NUMERIC,
  INTEGER,
  INTEGER,
  INTEGER,
  JSONB
) TO service_role;
