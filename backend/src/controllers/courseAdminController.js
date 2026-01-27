const supabase = require('../config/supabase');

exports.createCourse = async (req, res) => {
  try {
    const { course_code, course_name, teacher_email } = req.body;
    const payload = { course_code, course_name, teacher_email };
    const { data, error } = await supabase.from('courses').insert([payload]).select().single();
    if (error) return res.status(400).json({ error: error.message });
    await supabase.from('audit_logs').insert([{ actor_profile_id: req.user.id, action: 'create_course', target_type: 'course', target_id: data.id, details: payload }]);
    res.status(201).json(data);
  } catch (err) {
    res.status(500).json({ error: 'Internal Server Error' });
  }
};

exports.updateCourse = async (req, res) => {
  try {
    const { id } = req.params;
    const { course_name, teacher_email } = req.body;
    const { data, error } = await supabase.from('courses').update({ course_name, teacher_email }).eq('id', id).select().single();
    if (error) return res.status(400).json({ error: error.message });
    await supabase.from('audit_logs').insert([{ actor_profile_id: req.user.id, action: 'update_course', target_type: 'course', target_id: id, details: { course_name, teacher_email } }]);
    res.json(data);
  } catch (err) {
    res.status(500).json({ error: 'Internal Server Error' });
  }
};

exports.deleteCourse = async (req, res) => {
  try {
    const { id } = req.params;
    const { error } = await supabase.from('courses').delete().eq('id', id);
    if (error) return res.status(400).json({ error: error.message });
    await supabase.from('audit_logs').insert([{ actor_profile_id: req.user.id, action: 'delete_course', target_type: 'course', target_id: id, details: {} }]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Internal Server Error' });
  }
};

exports.listCourses = async (req, res) => {
  try {
    const { page = 1, per_page = 50, q } = req.query;
    const from = (page -1) * per_page;
    const to = from + per_page - 1;
    let qObj = supabase.from('courses').select('*').range(from, to).order('course_code');
    if (q) qObj = qObj.ilike('course_name', `%${q}%`);
    const { data, error } = await qObj;
    if (error) return res.status(400).json({ error: error.message });
    res.json({ data });
  } catch (err) {
    res.status(500).json({ error: 'Internal Server Error' });
  }
};