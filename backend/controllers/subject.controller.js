
const subjectService = require('../services/subject_service');

/** Helper to check if user is admin */
function isAdmin(user) {
  return user && ['admin', 'super_admin'].includes(user.vaiTro);
}

/** Validate UUID (simple regex) */
function isValidUuid(id) {
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  return uuidRegex.test(id);
}

/** GET /api/subjects */
async function getAllSubjects(req, res) {
  const admin = isAdmin(req.user);
  try {
    const { data, error } = await subjectService.getAllSubjects(admin);
    if (error) {
      console.error('Supabase error (getAllSubjects):', error);
      return res.status(500).json({ success: false, message: 'Internal server error' });
    }
    return res.json({ success: true, message: 'Subjects retrieved successfully', data });
  } catch (e) {
    console.error('Unexpected error (getAllSubjects):', e);
    return res.status(500).json({ success: false, message: 'Internal server error' });
  }
}

/** GET /api/subjects/:id */
async function getSubjectById(req, res) {
  const { id } = req.params;
  if (!isValidUuid(id)) {
    return res.status(400).json({ success: false, message: 'Invalid subject id' });
  }
  const admin = isAdmin(req.user);
  try {
    const { data, error } = await subjectService.getSubjectById(id, admin);
    if (error) {
      // Supabase returns error when no row
      if (error.code === 'PGRST116') {
        return res.status(404).json({ success: false, message: 'Subject not found' });
      }
      console.error('Supabase error (getSubjectById):', error);
      return res.status(500).json({ success: false, message: 'Internal server error' });
    }
    if (!data) {
      return res.status(404).json({ success: false, message: 'Subject not found' });
    }
    return res.json({ success: true, message: 'Subject retrieved successfully', data });
  } catch (e) {
    console.error('Unexpected error (getSubjectById):', e);
    return res.status(500).json({ success: false, message: 'Internal server error' });
  }
}

/** POST /api/subjects */
async function createSubject(req, res) {
  const { ten_mon, mo_ta, bieu_tuong, mau_sac, thu_tu_hien_thi, trang_thai } = req.body;
  // Validate required field
  if (!ten_mon || typeof ten_mon !== 'string' || ten_mon.trim() === '') {
    return res.status(400).json({ success: false, message: 'ten_mon is required and cannot be empty' });
  }
  const payload = {
    ten_mon: ten_mon.trim(),
  };
  // Validate optional text fields (string or null)
  if (mo_ta !== undefined) {
    if (mo_ta !== null && typeof mo_ta !== 'string') {
      return res.status(400).json({ success: false, message: 'mo_ta must be string or null' });
    }
    payload.mo_ta = mo_ta;
  }
  if (bieu_tuong !== undefined) {
    if (bieu_tuong !== null && typeof bieu_tuong !== 'string') {
      return res.status(400).json({ success: false, message: 'bieu_tuong must be string or null' });
    }
    payload.bieu_tuong = bieu_tuong;
  }
  if (mau_sac !== undefined) {
    if (mau_sac !== null && typeof mau_sac !== 'string') {
      return res.status(400).json({ success: false, message: 'mau_sac must be string or null' });
    }
    payload.mau_sac = mau_sac;
  }
  // Validate thu_tu_hien_thi as non‑negative integer (must be number)
  if (thu_tu_hien_thi !== undefined) {
    if (typeof thu_tu_hien_thi !== 'number' || !Number.isInteger(thu_tu_hien_thi) || thu_tu_hien_thi < 0) {
      return res.status(400).json({ success: false, message: 'thu_tu_hien_thi must be a non‑negative integer' });
    }
    payload.thu_tu_hien_thi = thu_tu_hien_thi;
  }
      if (trang_thai !== undefined) {
      if (typeof trang_thai !== 'boolean') {
        return res.status(400).json({ success: false, message: 'trang_thai must be boolean' });
      }
      payload.trang_thai = trang_thai;
    }

  try {
    const { data, error } = await subjectService.createSubject(payload, req.user.id);
    if (error) {
      // Unique constraint violation (postgresql code 23505)
      if (error.code === '23505') {
        return res.status(409).json({ success: false, message: 'Tên môn học đã tồn tại' });
      }
      console.error('Supabase error (createSubject):', error);
      return res.status(500).json({ success: false, message: 'Internal server error' });
    }
    return res.status(201).json({ success: true, message: 'Subject created successfully', data });
  } catch (e) {
    console.error('Unexpected error (createSubject):', e);
    return res.status(500).json({ success: false, message: 'Internal server error' });
  }
}

/** PUT /api/subjects/:id */
async function updateSubject(req, res) {
  const { id } = req.params;
  if (!isValidUuid(id)) {
    return res.status(400).json({ success: false, message: 'Invalid subject id' });
  }
  const allowedFields = ['ten_mon', 'mo_ta', 'bieu_tuong', 'mau_sac', 'thu_tu_hien_thi', 'trang_thai'];
  const payload = {};
  for (const field of allowedFields) {
    if (Object.prototype.hasOwnProperty.call(req.body, field)) {
      let value = req.body[field];
      if (field === 'ten_mon') {
        if (typeof value !== 'string' || value.trim() === '') {
          return res.status(400).json({ success: false, message: 'ten_mon cannot be empty' });
        }
        value = value.trim();
      }
      if (field === 'thu_tu_hien_thi') {
        if (typeof value !== 'number' || !Number.isInteger(value) || value < 0) {
          return res.status(400).json({ success: false, message: 'thu_tu_hien_thi must be a non‑negative integer' });
        }
      }
      if (field === 'trang_thai') {
        if (typeof value !== 'boolean') {
          return res.status(400).json({ success: false, message: 'trang_thi must be boolean' });
        }
      }
      if (['mo_ta','bieu_tuong','mau_sac'].includes(field)) {
        if (value !== null && typeof value !== 'string') {
          return res.status(400).json({ success: false, message: `${field} must be string or null` });
        }
      }
      payload[field] = value;
    }
  }

  if (Object.keys(payload).length === 0) {
    return res.status(400).json({ success: false, message: 'No valid fields provided for update' });
  }

  try {
    const { data, error } = await subjectService.updateSubject(id, payload);
    if (error) {
      if (error.code === '23505') {
        return res.status(409).json({ success: false, message: 'Tên môn học đã tồn tại' });
      }
      if (error.code === 'PGRST116') {
        return res.status(404).json({ success: false, message: 'Subject not found' });
      }
      console.error('Supabase error (updateSubject):', error);
      return res.status(500).json({ success: false, message: 'Internal server error' });
    }
    if (!data) {
      return res.status(404).json({
        success: false,
        message: 'Subject not found'
      });
    }
    return res.json({ success: true, message: 'Subject updated successfully', data });
  } catch (e) {
    console.error('Unexpected error (updateSubject):', e);
    return res.status(500).json({ success: false, message: 'Internal server error' });
  }
}

/** PATCH /api/subjects/:id/status */
async function patchSubjectStatus(req, res) {
  const { id } = req.params;
  const { trang_thai } = req.body;
  if (!isValidUuid(id)) {
    return res.status(400).json({ success: false, message: 'Invalid subject id' });
  }
  if (typeof trang_thai !== 'boolean') {
    return res.status(400).json({ success: false, message: 'trang_thai must be boolean' });
  }
  try {
    const { data, error } = await subjectService.patchSubjectStatus(id, trang_thai);
    if (error) {
      if (error.code === 'PGRST116') {
        return res.status(404).json({ success: false, message: 'Subject not found' });
      }
      console.error('Supabase error (patchSubjectStatus):', error);
      return res.status(500).json({ success: false, message: 'Internal server error' });
    }
    if (!data) {
      return res.status(404).json({
        success: false,
        message: 'Subject not found'
      });
    }
    return res.json({ success: true, message: 'Subject status updated successfully', data });
  } catch (e) {
    console.error('Unexpected error (patchSubjectStatus):', e);
    return res.status(500).json({ success: false, message: 'Internal server error' });
  }
}

module.exports = {
  getAllSubjects,
  getSubjectById,
  createSubject,
  updateSubject,
  patchSubjectStatus,
};
