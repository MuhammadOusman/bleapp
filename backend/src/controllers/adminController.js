const supabase = require('../config/supabase');

exports.listPendingStudents = async (req, res) => {
  try {
    const { page = 1, per_page = 50 } = req.query;
    const from = (page - 1) * per_page;
    const to = from + per_page - 1;
    const { data, error } = await supabase.from('pending_students').select('*').range(from, to);
    if (error) return res.status(400).json({ error: error.message });
    res.json({ data });
  } catch (err) {
    res.status(500).json({ error: 'Internal Server Error' });
  }
};

exports.approvePendingStudent = async (req, res) => {
  try {
    const { id } = req.params; // pending_students id
    const { create_auth = false } = req.body;
    const { data: pending } = await supabase.from('pending_students').select('*').eq('id', id).limit(1);
    if (!pending || pending.length === 0) return res.status(404).json({ error: 'Pending student not found' });
    const p = pending[0];

    // If profile exists, update; else create profile without auth user
    const { data: existing } = await supabase.from('profiles').select('id').ilike('email', p.email).limit(1);
    let profileId;
    if (existing && existing.length > 0) {
      profileId = existing[0].id;
      await supabase.from('profiles').update({ lms_id: p.lms_id, full_name: p.full_name }).eq('id', profileId);
    } else {
      // Create profile entry only; creating auth user is optional and should be controlled
      const { data: ins } = await supabase.from('profiles').insert([{ email: p.email, full_name: p.full_name, lms_id: p.lms_id, role: 'student' }]).select().single();
      profileId = ins.id;
    }

    // mark pending as approved
    await supabase.from('pending_students').update({ status: 'approved' }).eq('id', id);

    // log audit
    await supabase.from('audit_logs').insert([{ actor_profile_id: req.user.id, action: 'approve_pending_student', target_type: 'pending_student', target_id: id, details: { profile_id: profileId } }]);

    res.json({ profile_id: profileId });
  } catch (err) {
    console.error('approve pending error', err);
    res.status(500).json({ error: 'Internal Server Error' });
  }
};
