const supabase = require('../config/supabase');

module.exports = async (req, res, next) => {
    try {
        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({ error: 'No token provided' });
        }

        const token = authHeader.split(' ')[1];
        
        // 1. Verify Supabase User
        const { data: { user }, error: authError } = await supabase.auth.getUser(token);
        if (authError || !user) {
            return res.status(401).json({ error: 'Invalid or expired token' });
        }

        // 2. Fetch the role and profile details from our table
        const { data: profile, error: profileError } = await supabase
            .from('profiles')
            .select('*')
            .eq('id', user.id)
            .single();

        if (profileError || !profile) {
            return res.status(404).json({ error: 'User profile not found' });
        }

        // Attach everything to the request object
        req.user = {
            id: user.id,
            email: user.email,
            role: profile.role,
            device_signature: profile.device_signature,
            blocked_signatures: profile.blocked_signatures
        };

        next();
    } catch (err) {
        console.error('Middleware Error:', err);
        res.status(500).json({ error: 'Authentication middleware failed' });
    }
};