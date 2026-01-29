module.exports = function adminMiddleware(req, res, next) {
    try {
        const user = req.user;
        if (!user) return res.status(401).json({ error: 'Not authenticated' });

        // STRICT DB CHECK
        if (user.role === 'admin') {
            return next();
        }

        // (Optional) Keep the .env fallback just in case you lock yourself out of the DB
        // You can remove this block if you are confident in your DB entries.
        const adminEmails = (process.env.ADMIN_EMAILS || '').split(',').map(s => s.trim().toLowerCase());
        if (user.email && adminEmails.includes(user.email.toLowerCase())) {
            return next();
        }

        return res.status(403).json({ error: 'Access denied: Admin privileges required.' });
    } catch (e) {
        return res.status(500).json({ error: 'Internal Server Error' });
    }
};