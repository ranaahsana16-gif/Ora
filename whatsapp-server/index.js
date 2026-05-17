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
let latestQr = null;

client.on('qr', (qr) => {
  latestQr = qr;
  console.log('\n📱  Scan this QR code with your WhatsApp:\n');
  qrcode.generate(qr, { small: true });
});

client.on('ready', () => {
  isReady = true;
  latestQr = null;
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

// ─── HTTP Health-Check & Web QR Dashboard (For Hugging Face / Render) ─────────
const http = require('http');
const PORT = process.env.PORT || 7860;
const healthServer = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
  
  let content = '';
  let refreshMeta = '';
  
  if (isReady) {
    content = `
      <div class="card success animate">
        <div class="icon">✅</div>
        <h2>WhatsApp Connected!</h2>
        <p class="desc">The Ora OTP Server is fully connected and active. It is successfully listening and delivering verification codes to your users.</p>
        <div class="badge success">Status: Live & Polling</div>
      </div>
    `;
    // Refresh less frequently when ready
    refreshMeta = '<meta http-equiv="refresh" content="30">';
  } else if (latestQr) {
    const qrImageUrl = `https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${encodeURIComponent(latestQr)}`;
    content = `
      <div class="card qr-container animate">
        <div class="badge warning">Action Required</div>
        <h2 style="margin-top: 15px;">Link WhatsApp Account</h2>
        <p class="desc">Scan this perfect, high-resolution QR code using your phone's WhatsApp to start the 24/7 delivery service.</p>
        
        <div class="qr-box">
          <img src="${qrImageUrl}" alt="WhatsApp QR Code" />
        </div>
        
        <div class="instructions">
          <h3>How to Link:</h3>
          <ol>
            <li>Open <strong>WhatsApp</strong> on your phone.</li>
            <li>Tap <strong>Menu</strong> or <strong>Settings</strong> and select <strong>Linked Devices</strong>.</li>
            <li>Tap <strong>Link a Device</strong> and point your camera at this screen.</li>
          </ol>
        </div>
        <p class="refresh-note">🔄 This page automatically refreshes when connected.</p>
      </div>
    `;
    // Refresh every 5 seconds to automatically detect when they scan!
    refreshMeta = '<meta http-equiv="refresh" content="5">';
  } else {
    content = `
      <div class="card loading animate">
        <div class="spinner"></div>
        <h2>Initializing WhatsApp...</h2>
        <p class="desc">Please wait a few seconds while we start the virtual browser and prepare the connection.</p>
      </div>
    `;
    // Refresh every 3 seconds while initializing
    refreshMeta = '<meta http-equiv="refresh" content="3">';
  }

  const html = `
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      ${refreshMeta}
      <title>Ora WhatsApp OTP Service</title>
      <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;600;700&display=swap" rel="stylesheet">
      <style>
        :root {
          --bg-color: #0b0f19;
          --card-bg: rgba(255, 255, 255, 0.03);
          --card-border: rgba(255, 255, 255, 0.08);
          --primary: #10b981;
          --primary-glow: rgba(16, 185, 129, 0.15);
          --warning: #f59e0b;
          --text: #f3f4f6;
          --text-muted: #9ca3af;
        }
        
        * {
          box-sizing: border-box;
          margin: 0;
          padding: 0;
        }
        
        body {
          font-family: 'Outfit', sans-serif;
          background-color: var(--bg-color);
          color: var(--text);
          min-height: 100vh;
          display: flex;
          align-items: center;
          justify-content: center;
          background-image: 
            radial-gradient(at 0% 0%, rgba(16, 185, 129, 0.08) 0px, transparent 50%),
            radial-gradient(at 100% 100%, rgba(59, 130, 246, 0.08) 0px, transparent 50%);
          padding: 20px;
        }
        
        .container {
          width: 100%;
          max-width: 480px;
        }
        
        .card {
          background: var(--card-bg);
          border: 1px solid var(--card-border);
          backdrop-filter: blur(16px);
          border-radius: 24px;
          padding: 40px 30px;
          text-align: center;
          box-shadow: 0 20px 40px rgba(0, 0, 0, 0.3);
          position: relative;
          overflow: hidden;
        }
        
        .card::before {
          content: '';
          position: absolute;
          top: 0;
          left: 0;
          width: 100%;
          height: 4px;
          background: linear-gradient(90deg, var(--primary), #3b82f6);
        }
        
        .animate {
          animation: fadeInUp 0.6s cubic-bezier(0.16, 1, 0.3, 1);
        }
        
        h2 {
          font-size: 26px;
          font-weight: 700;
          margin-bottom: 12px;
          letter-spacing: -0.5px;
        }
        
        .desc {
          font-size: 15px;
          color: var(--text-muted);
          line-height: 1.6;
          margin-bottom: 24px;
        }
        
        .icon {
          font-size: 64px;
          margin-bottom: 20px;
          filter: drop-shadow(0 10px 15px var(--primary-glow));
        }
        
        .badge {
          display: inline-block;
          padding: 6px 14px;
          border-radius: 100px;
          font-size: 13px;
          font-weight: 600;
          letter-spacing: 0.5px;
          text-transform: uppercase;
        }
        
        .badge.warning {
          background: rgba(245, 158, 11, 0.1);
          color: var(--warning);
          border: 1px solid rgba(245, 158, 11, 0.2);
        }
        
        .badge.success {
          background: rgba(16, 185, 129, 0.1);
          color: var(--primary);
          border: 1px solid rgba(16, 185, 129, 0.2);
        }
        
        .qr-box {
          background: white;
          padding: 16px;
          border-radius: 20px;
          display: inline-block;
          margin-bottom: 24px;
          box-shadow: 0 10px 25px rgba(0, 0, 0, 0.2);
          transition: transform 0.3s ease;
        }
        
        .qr-box:hover {
          transform: scale(1.02);
        }
        
        .qr-box img {
          display: block;
          width: 240px;
          height: 240px;
        }
        
        .instructions {
          text-align: left;
          background: rgba(255, 255, 255, 0.02);
          border: 1px solid var(--card-border);
          border-radius: 16px;
          padding: 20px;
          margin-bottom: 20px;
        }
        
        .instructions h3 {
          font-size: 15px;
          font-weight: 600;
          margin-bottom: 10px;
          color: var(--text);
        }
        
        .instructions ol {
          padding-left: 20px;
          font-size: 14px;
          color: var(--text-muted);
        }
        
        .instructions li {
          margin-bottom: 8px;
          line-height: 1.5;
        }
        
        .instructions li strong {
          color: var(--text);
        }
        
        .refresh-note {
          font-size: 12px;
          color: var(--text-muted);
          margin-top: 10px;
        }
        
        .spinner {
          width: 50px;
          height: 50px;
          border: 3px solid var(--card-border);
          border-top-color: #3b82f6;
          border-radius: 50%;
          animation: spin 1s linear infinite;
          margin: 0 auto 24px auto;
        }
        
        @keyframes spin {
          to { transform: rotate(360deg); }
        }
        
        @keyframes fadeInUp {
          from {
            opacity: 0;
            transform: translateY(20px);
          }
          to {
            opacity: 1;
            transform: translateY(0);
          }
        }
      </style>
    </head>
    <body>
      <div class="container">
        ${content}
      </div>
    </body>
    </html>
  `;
  
  res.end(html);
});
healthServer.listen(PORT, '0.0.0.0', () => {
  console.log(`📡 Health-check & QR Dashboard web server listening on port ${PORT}`);
});
