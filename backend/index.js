require('dotenv').config();
const express = require('express');
const admin = require('firebase-admin');
const cors = require('cors');

const app = express();
app.use(cors({ origin: true }));
app.use(express.json());

// Initialize Firebase Admin
// The service account key should be provided via an environment variable in production
// Try to initialize from GOOGLE_APPLICATION_CREDENTIALS, or fall back to local serviceAccountKey.json if present
try {
  if (process.env.FIREBASE_SERVICE_ACCOUNT_BASE64) {
    const serviceAccount = JSON.parse(
      Buffer.from(process.env.FIREBASE_SERVICE_ACCOUNT_BASE64, 'base64').toString('utf8')
    );
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
  } else {
    // If running locally and have the file
    const serviceAccount = require('./serviceAccountKey.json');
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
  }
} catch (error) {
  console.warn("Firebase Admin failed to initialize. Ensure FIREBASE_SERVICE_ACCOUNT_BASE64 is set or serviceAccountKey.json exists.", error.message);
}

// Health check endpoint
app.get('/', (req, res) => {
  res.status(200).send('Personal Chat Backend is running.');
});

// Endpoint to send push notifications
app.post('/api/notifications/send', async (req, res) => {
  const { token, title, body, chatId } = req.body;

  if (!token || !title || !body) {
    return res.status(400).json({ error: 'Missing required fields: token, title, body' });
  }

  const payload = {
    token: token,
    notification: {
      title: title,
      body: body,
    },
    data: {
      title: title,
      body: body,
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
    },
    android: {
      priority: 'high',
      notification: {
        channelId: 'high_importance_channel',
        sound: 'default',
      },
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
        },
      },
    },
  };

  if (chatId) {
    payload.data.chatId = chatId;
  }

  try {
    const response = await admin.messaging().send(payload);
    console.log('Successfully sent message:', response);
    res.status(200).json({ success: true, messageId: response });
  } catch (error) {
    console.error('Error sending message:', error);
    res.status(500).json({ error: 'Failed to send notification', details: error.message });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server listening on port ${PORT}`);
});
