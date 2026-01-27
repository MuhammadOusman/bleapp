/**
 * Migration helper: import master_students into pending_students and attempt to match to profiles
 * Run in staging first: node scripts/migrate_master_students.js --dry
 */

const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const SUPA_URL = process.env.SUPABASE_URL;
const SUPA_KEY = process.env.SUPABASE_SERVICE_KEY;
if (!SUPA_URL || !SUPA_KEY) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_KEY in env');
  process.exit(1);
}

const supabase = createClient(SUPA_URL, SUPA_KEY);

async function run(dry = true) {
  console.log(`Dry run: ${dry}`);

  // find master students that do not have matching profile
  const { data: ms, error } = await supabase.from('master_students').select('*');
  if (error) throw error;

  let inserted = 0;
  for (const m of ms) {
    const email = (m.email || '').toLowerCase();
    const { data: p } = await supabase.from('profiles').select('id').ilike('email', email).limit(1);
    if (!p || p.length === 0) {
      // insert into pending_students if not exists
      const { data: exists } = await supabase.from('pending_students').select('id').ilike('email', email).limit(1);
      if (!exists || exists.length === 0) {
        if (!dry) {
          const { error: insErr } = await supabase.from('pending_students').insert([{ lms_id: m.lms_id, email: m.email, full_name: m.full_name, source: 'master_students' }]);
          if (insErr) console.error('Insert error', insErr);
        }
        inserted++;
      }
    } else {
      // backfill profile lms_id/full_name
      const profileId = p[0].id;
      if (!dry) {
        const { error: updErr } = await supabase.from('profiles').update({ lms_id: m.lms_id, full_name: m.full_name }).eq('id', profileId);
        if (updErr) console.error('Update error', updErr);
      }
    }
  }

  console.log(`Master students processed: ${ms.length}; pending inserted (approx): ${inserted}`);
}

const args = process.argv.slice(2);
const dry = args.includes('--no-dry') ? false : true;
run(dry).then(() => console.log('Done')).catch((e)=>{console.error(e); process.exit(1);});
