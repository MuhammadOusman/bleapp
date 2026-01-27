module.exports = function adminMiddleware(req, res, next) {
  try {
    const user = req.user;
    if (!user) return res.status(401).json({ error: 'Not authenticated' });
    if (user.role !== 'admin') return res.status(403).json({ error: 'Admin role required' });
    next();
  } catch (e) {
    return res.status(500).json({ error: 'Internal Server Error' });
  }
};
