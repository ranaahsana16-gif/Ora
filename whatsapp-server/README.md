---
title: Ora Whatsapp Server
emoji: 📱
colorFrom: green
colorTo: blue
sdk: docker
app_port: 7860
pinned: false
---

# Ora WhatsApp OTP Server

This is a 24/7 background worker for sending WhatsApp OTP verification codes.

## Deploying to Hugging Face Spaces (No Credit Card)
This folder is pre-configured to run directly as a Docker Space on Hugging Face.

### Setup Instructions:
1. Create a **Docker** Space on Hugging Face (choose **Blank** template).
2. Go to **Settings > Variables and Secrets** and add your credentials:
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_KEY`
3. Upload all the files inside this directory directly to the Space.
4. Hugging Face will automatically build and run the server.
5. Watch the **Logs** to scan the WhatsApp QR Code!
