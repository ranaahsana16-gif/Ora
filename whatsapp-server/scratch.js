require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');
const ws = require('ws');
const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
  realtime: { transport: ws },
});

async function run() {
  const { data, error } = await supabase.auth.admin.generateLink({
    type: 'magiclink',
    email: 'phone.923085121676@ora-auth.internal'
  });
  console.log(JSON.stringify(data, null, 2));
}
run();
