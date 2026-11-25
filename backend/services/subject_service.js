const supabase = require('../config/supabase');

/**
 * Service layer for Subject (mon_hoc) operations.
 * All functions return { data, error }.
 */

/**
 * Get list of subjects.
 * Admin: gets all subjects.
 * User: gets active subjects only.
 */
async function getAllSubjects(isAdmin) {
  let query = supabase
    .from('mon_hoc')
    .select('*')
    .order('thu_tu_hien_thi', { ascending: true })
    .order('ngay_tao', { ascending: true });

  if (!isAdmin) {
    query = query.eq('trang_thai', true);
  }

  const { data, error } = await query;

  return { data, error };
}

/**
 * Get subject detail by ID.
 * Admin: can view active and inactive subjects.
 * User: can view active subjects only.
 */
async function getSubjectById(id, isAdmin) {
  let query = supabase
    .from('mon_hoc')
    .select('*')
    .eq('id', id);

  if (!isAdmin) {
    query = query.eq('trang_thai', true);
  }

  const { data, error } = await query.single();

  return { data, error };
}

/**
 * Create a new subject.
 */
async function createSubject(payload, creatorId) {
  const insertData = {
    ...payload,
    nguoi_tao_id: creatorId,
  };

  const { data, error } = await supabase
    .from('mon_hoc')
    .insert([insertData])
    .select('*')
    .single();

  return { data, error };
}

/**
 * Update an existing subject.
 */
async function updateSubject(id, payload) {
  const { data, error } = await supabase
    .from('mon_hoc')
    .update(payload)
    .eq('id', id)
    .select('*')
    .single();

  return { data, error };
}

/**
 * Update subject status only.
 */
async function patchSubjectStatus(id, status) {
  const { data, error } = await supabase
    .from('mon_hoc')
    .update({ trang_thai: status })
    .eq('id', id)
    .select('*')
    .single();

  return { data, error };
}

module.exports = {
  getAllSubjects,
  getSubjectById,
  createSubject,
  updateSubject,
  patchSubjectStatus,
};