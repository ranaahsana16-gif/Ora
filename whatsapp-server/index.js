/**
 * Ora WhatsApp OTP Server
 * ─────────────────────────────────────────────────────────────────────────────
 * Polls the Supabase `otp_requests` table every 3 seconds for pending OTPs
 * and sends them to the customer's WhatsApp number.
 *
 * Setup:
 *   1. npm install
 *   2. Copy .env.example → .env and fill in your values
 *   3. npm start
 *   4. Scan the QR code with the WhatsApp account you want to send from
 *
 * Run persistently with: npx pm2 start index.js --name ora-whatsapp
 */

require('dotenv').config();
const { Client, LocalAuth } = require('whatsapp-web.js');
const qrcode = require('qrcode-terminal');
const { createClient } = require('@supabase/supabase-js');
const ws = require('ws');
const net = require('net');

// ─── Single Instance Port Lock ──────────────────────────────────────────────
const SINGLE_INSTANCE_PORT = 12456;
const dummyServer = net.createServer();

dummyServer.once('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.log(`ℹ️  Ora WhatsApp OTP Server is already running on port ${SINGLE_INSTANCE_PORT}. Exiting...`);
    process.exit(0);
  } else {
    console.error('❌  Single-instance server error:', err.message);
  }
});

dummyServer.listen(SINGLE_INSTANCE_PORT, '127.0.0.1', () => {
  console.log(`⚡  Single-instance lock acquired on port ${SINGLE_INSTANCE_PORT}`);
});

// ─── Config ────────────────────────────────────────────────────────────────
const SUPABASE_URL        = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;
const POLL_INTERVAL_MS    = 3000; // Poll every 3 seconds

if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
  console.error('❌  Missing SUPABASE_URL or SUPABASE_SERVICE_KEY in .env');
  process.exit(1);
}

// ─── Supabase Client (service role — bypasses RLS) ─────────────────────────
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
  realtime: { transport: ws },
});

// ─── WhatsApp Client ────────────────────────────────────────────────────────
const client = new Client({
  authStrategy: new LocalAuth({ clientId: 'ora-otp-server' }),
  puppeteer: {
    headless: true,
    executablePath: process.env.PUPPETEER_EXECUTABLE_PATH || null,
    args: [
      '--no-sandbox', 
      '--disable-setuid-sandbox'
    ],
  },
});

let isReady = false;

client.on('qr', (qr) => {
  console.log('\n📱  Scan this QR code with your WhatsApp:\n');
  qrcode.generate(qr, { small: true });
});

client.on('ready', () => {
  isReady = true;
  console.log('✅  WhatsApp client is ready! Polling for OTP requests...\n');
  startPolling();
});

client.on('auth_failure', (msg) => {
  console.error('❌  WhatsApp auth failed:', msg);
});

client.on('disconnected', (reason) => {
  isReady = false;
  console.warn('⚠️  WhatsApp disconnected:', reason);
  console.log('   Attempting to reconnect...');
  client.initialize();
});

// ─── OTP Polling ────────────────────────────────────────────────────────────
function formatPhoneForWhatsApp(phone) {
  // Remove all non-digits
  let digits = phone.replace(/\D/g, '');

  // Convert Pakistani local format (03XX → 923XX)
  if (digits.startsWith('0') && digits.length === 11) {
    digits = '92' + digits.slice(1);
  }

  // Already has country code but missing +
  // Format expected by whatsapp-web.js: "923001234567@c.us"
  return digits + '@c.us';
}

async function checkIfStoreIsOpen() {
  try {
    const { data, error } = await supabase
      .from('app_settings')
      .select('is_shop_open, is_auto_timing, opening_time, closing_time')
      .eq('id', 1)
      .single();

    if (error || !data) {
      console.warn('⚠️  Could not fetch store status, defaulting to open:', error?.message);
      return true;
    }

    const { is_shop_open, is_auto_timing, opening_time, closing_time } = data;

    if (!is_auto_timing) {
      return !!is_shop_open;
    }

    if (opening_time && closing_time) {
      const options = { timeZone: 'Asia/Karachi', hour: '2-digit', minute: '2-digit', hour12: false };
      const formatter = new Intl.DateTimeFormat([], options);
      const parts = formatter.formatToParts(new Date());
      const hour = parseInt(parts.find(p => p.type === 'hour').value, 10);
      const minute = parseInt(parts.find(p => p.type === 'minute').value, 10);

      const [openH, openM] = opening_time.split(':').map(Number);
      const [closeH, closeM] = closing_time.split(':').map(Number);

      const nowMinutes = hour * 60 + minute;
      const openMinutes = openH * 60 + openM;
      const closeMinutes = closeH * 60 + closeM;

      if (openMinutes < closeMinutes) {
        return nowMinutes >= openMinutes && nowMinutes <= closeMinutes;
      } else {
        return nowMinutes >= openMinutes || nowMinutes <= closeMinutes;
      }
    }

    return true;
  } catch (err) {
    console.error('❌  Error checking store status:', err.message);
    return true;
  }
}

async function processPendingOtps() {
  if (!isReady) return;

  try {
    const isOpen = await checkIfStoreIsOpen();
    if (!isOpen) {
      // Fetch any pending requests and fail them immediately because the store is closed
      const { data: requests } = await supabase
        .from('otp_requests')
        .select('id, phone_number')
        .eq('status', 'pending')
        .gt('expires_at', new Date().toISOString());

      if (requests && requests.length > 0) {
        console.log(`😴  Shop is closed. Rejecting ${requests.length} OTP request(s)...`);
        for (const req of requests) {
          await supabase
            .from('otp_requests')
            .update({ status: 'failed', error: 'Store is currently closed' })
            .eq('id', req.id);
        }
      }
      return;
    }

    // Fetch all pending, non-expired OTP requests
    const { data: requests, error } = await supabase
      .from('otp_requests')
      .select('*')
      .eq('status', 'pending')
      .gt('expires_at', new Date().toISOString())
      .order('created_at', { ascending: true });

    if (error) {
      console.error('❌  Supabase fetch error:', error.message);
      return;
    }

    if (!requests || requests.length === 0) return;

    console.log(`📋  Found ${requests.length} pending OTP request(s)`);

    for (const req of requests) {
      const waNumber = formatPhoneForWhatsApp(req.phone_number);
      const message = `🔐 Your Ora verification code is: *${req.otp_code}*\n\nThis code expires in 10 minutes. Do not share it with anyone.`;

      try {
        // Mark as "sending" to prevent duplicate sends
        await supabase
          .from('otp_requests')
          .update({ status: 'sent', sent_at: new Date().toISOString() })
          .eq('id', req.id);

        await client.sendMessage(waNumber, message);
        console.log(`✅  OTP sent to ${req.phone_number} (${waNumber})`);
      } catch (sendError) {
        console.error(`❌  Failed to send to ${req.phone_number}:`, sendError.message);

        // Mark as failed so the app can retry
        await supabase
          .from('otp_requests')
          .update({ status: 'failed', error: sendError.message })
          .eq('id', req.id);
      }
    }
  } catch (err) {
    console.error('❌  Unexpected error in polling:', err.message);
  }
}

function startPolling() {
  setInterval(processPendingOtps, POLL_INTERVAL_MS);
}

// ─── Initialize ─────────────────────────────────────────────────────────────
console.log('🚀  Starting Ora WhatsApp OTP Server...');
client.initialize();
