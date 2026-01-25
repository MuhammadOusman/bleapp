const supabase = require('../config/supabase');

// Try a few heuristics to resolve an advertised string to a student profile
exports.resolveByAdvertised = async (req, res) => {
    try {
        const { advertised } = req.body;
        if (!advertised) return res.status(400).json({ error: 'advertised is required' });

        // 1) Exact match on device_signature
        let { data } = await supabase.from('profiles').select('*').eq('device_signature', advertised).limit(1);
        if (data && data.length) return res.json({ profile: data[0] });

        // 2) Containment match (case-insensitive)
        const pat = `%${advertised}%`;
        const { data: contains } = await supabase.from('profiles').select('*').ilike('device_signature', pat).limit(1);
        if (contains && contains.length) return res.json({ profile: contains[0] });

        // 3) Blocked signatures array contains the advertised signature
        // Supabase supports .contains for array columns
        const { data: blocked } = await supabase.from('profiles').select('*').contains('blocked_signatures', [advertised]).limit(1);
        if (blocked && blocked.length) return res.json({ profile: blocked[0] });

        // 4) Nothing found
        return res.status(404).json({ error: 'No matching profile found' });
    } catch (err) {
        console.error('resolveByAdvertised error', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
};