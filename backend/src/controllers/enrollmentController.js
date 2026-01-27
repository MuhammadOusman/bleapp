const supabase = require('../config/supabase');

exports.listEnrollments = async (req, res) => {
  try {
    const { id } = req.params; // course id
    const { page = 1, per_page = 50, q } = req.query;
    const offset = (page - 1) * per_page;

    // join enrollments -> profiles
    let query = supabase.from('enrollments').select('*, profiles(id,full_name,email,lms_id)').eq('course_id', id).order('enrolled_at', { ascending: false }).range(offset, offset + per_page - 1);
    const { data, error } = await query;
    if (error) return res.status(400).json({ error: error.message });
    res.json({ data });
  } catch (err) {
    res.status(500).json({ error: 'Internal Server Error' });
  }
};

exports.enroll = async (req, res) => {
  try {
    const { id } = req.params; // course id
    const { student_id, email, lms_id, source = 'admin' } = req.body;

    // Resolve student_id if needed
    let sid = student_id;
    if (!sid) {
      let q = supabase.from('profiles').select('id').limit(1);
      if (email) q = q.ilike('email', email);
      if (lms_id) q = q.ilike('lms_id', lms_id);
      const { data } = await q;
      if (!data || data.length === 0) return res.status(404).json({ error: 'Student profile not found' });
      sid = data[0].id;
    }

    // Insert idempotently
    const { error } = await supabase.from('enrollments').insert([{ course_id: id, student_id: sid, source }], { onConflict: ['course_id','student_id'] });
    if (error) {
      // Postgrest doesn't support onConflict in all clients; fallback
      const { data: exists } = await supabase.from('enrollments').select('id').eq('course_id', id).eq('student_id', sid).limit(1);
      if (exists && exists.length > 0) return res.status(200).json({ message: 'Already enrolled' });
      return res.status(400).json({ error: error.message });
    }

    // audit
    await supabase.from('audit_logs').insert([{ actor_profile_id: req.user.id, action: 'enroll_student', target_type: 'course', target_id: id, details: { student_id: sid } }]);

    res.json({ course_id: id, student_id: sid });
  } catch (err) {
    console.error('enroll error', err);
    res.status(500).json({ error: 'Internal Server Error' });
  }
};

exports.unenroll = async (req, res) => {
  try {
    const { id } = req.params; // course id
    const { student_id } = req.body;
    if (!student_id) return res.status(400).json({ error: 'student_id required' });
    const { error } = await supabase.from('enrollments').delete().eq('course_id', id).eq('student_id', student_id);
    if (error) return res.status(400).json({ error: error.message });
    await supabase.from('audit_logs').insert([{ actor_profile_id: req.user.id, action: 'unenroll_student', target_type: 'course', target_id: id, details: { student_id } }]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Internal Server Error' });
  }
};

// Bulk enroll preview (dry run) and commit
exports.bulkEnrollPreview = async (req, res) => {
  try {
    const { id } = req.params; // course id
    const { rows } = req.body; // rows: [{email,lms_id}]
    const preview = [];
    for (const r of rows) {
      const { email, lms_id } = r;
      const { data } = await supabase.from('profiles').select('id,email,lms_id,full_name').or(`email.ilike.${email},lms_id.ilike.${lms_id}`).limit(1);
      if (!data || data.length === 0) {
        preview.push({ ok: false, reason: 'no_profile', row: r });
      } else {
        preview.push({ ok: true, profile: data[0], row: r });
      }
    }
    res.json({ preview });
  } catch (err) {
    res.status(500).json({ error: 'Internal Server Error' });
  }
};

exports.bulkEnrollCommit = async (req, res) => {
  try {
    const { id } = req.params;
    const { profile_ids } = req.body; // [uuid]
    const inserts = profile_ids.map(pid => ({ course_id: id, student_id: pid, source: 'bulk' }));
    const { error } = await supabase.from('enrollments').insert(inserts);
    if (error) return res.status(400).json({ error: error.message });
    await supabase.from('audit_logs').insert([{ actor_profile_id: req.user.id, action: 'bulk_enroll', target_type: 'course', target_id: id, details: { count: profile_ids.length } }]);
    res.json({ inserted: profile_ids.length });
  } catch (err) {
    console.error('bulk commit error', err);
    res.status(500).json({ error: 'Internal Server Error' });
  }
};
