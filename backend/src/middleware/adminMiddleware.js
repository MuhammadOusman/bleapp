module.exports = function adminMiddleware(req, res, next) {
  try {
    const user = req.user;
    if (!user) return res.status(401).json({ error: 'Not authenticated' });

    // If the DB has 'admin' role in the enum this will work; otherwise, allow admin via email list
    if (user.role === 'admin') return next();

    // Optionally allow admins via ADMIN_EMAILS env (comma-separated)
    const admins = (process.env.ADMIN_EMAILS || '').split(',').map(s => s.trim().toLowerCase()).filter(Boolean);
    if (admins.includes((user.email || '').toLowerCase())) return next();

    return res.status(403).json({ error: 'Admin role required' });
  } catch (e) {
    return res.status(500).json({ error: 'Internal Server Error' });
  }
};
