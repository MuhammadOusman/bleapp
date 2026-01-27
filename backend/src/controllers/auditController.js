const supabase = require('../config/supabase');

exports.listLogs = async (req, res) => {
  try {
    const { page = 1, per_page = 50, actor_id, action } = req.query;
    const from = (page - 1) * per_page;
    const to = from + per_page - 1;
    let q = supabase.from('audit_logs').select('*').order('created_at', { ascending: false }).range(from, to);
    if (actor_id) q = q.eq('actor_profile_id', actor_id);
    if (action) q = q.eq('action', action);
    const { data, error } = await q;
    if (error) return res.status(400).json({ error: error.message });
    res.json({ data });
  } catch (err) {
    res.status(500).json({ error: 'Internal Server Error' });
  }
};
