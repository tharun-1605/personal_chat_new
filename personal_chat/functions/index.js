const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.sendNotificationOnMessage = functions.firestore
  .document("messages/{messageId}")
  .onCreate(async (snap, context) => {
    const messageData = snap.data();
    const receiverId = messageData.receiverId;
    const senderId = messageData.senderId;
    
    if (!receiverId || !senderId) return;

    // Get the receiver user doc to find the FCM token
    const receiverDoc = await admin.firestore().collection("users").doc(receiverId).get();
    if (!receiverDoc.exists) return;
    
    const receiverData = receiverDoc.data();
    const fcmToken = receiverData.fcmToken; // Assuming fcmToken is saved on login
    if (!fcmToken) {
      console.log("No FCM token for user", receiverId);
      return;
    }

    // Get sender data to show the name
    const senderDoc = await admin.firestore().collection("users").doc(senderId).get();
    const senderName = senderDoc.exists ? senderDoc.data().username : "Someone";

    const payload = {
      notification: {
        title: `New message from ${senderName}`,
        body: "You have received a new message.", // Message content is encrypted, so we just say "new message"
        sound: "default"
      },
      data: {
        chatId: messageData.chatId,
        click_action: "FLUTTER_NOTIFICATION_CLICK"
      }
    };

    try {
      await admin.messaging().sendToDevice(fcmToken, payload);
      console.log("Notification sent successfully");
    } catch (error) {
      console.error("Error sending notification", error);
    }
  });
