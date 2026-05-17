require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');
const ws = require('ws');
const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY || process.env.SUPABASE_SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
  realtime: { transport: ws },
});

async function run() {
  const adminClient = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
    realtime: { transport: ws },
  });
  const email = 'phone.923085121676@ora-auth.internal';
  
  const { data: linkData, error: linkErr } = await adminClient.auth.admin.generateLink({
    type: 'magiclink',
    email: email
  });
  
  console.log('OTP generated:', linkData.properties.email_otp);
  
  // Try verifying
  const { data: verifyData, error: verifyErr } = await supabase.auth.verifyOtp({
    email: email,
    token: linkData.properties.email_otp,
    type: 'email'
  });
  
  if (verifyErr) {
    console.error('Verify error:', verifyErr);
  } else {
    console.log('Verify success! User ID:', verifyData.user.id);
  }
}
run();
