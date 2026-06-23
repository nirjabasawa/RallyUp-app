/**
 * RallyUp — Firestore-triggered FCM sender.
 *
 * What this does:
 *   When a new doc is created under `notifications/{notificationId}`,
 *   look up the recipient user (`userId` field on the notification
 *   doc), read their `fcmTokens` array from `users/{uid}`, and send
 *   each token an FCM push containing the notification's title,
 *   body, and `targetType` / `targetId` so the client can route the
 *   tap.
 *
 *   Dead tokens (NotRegistered / InvalidArgument) are pruned from the
 *   user's `fcmTokens` array so we don't keep re-sending to them.
 *
 * Deploy:
 *   1. `cd functions && npm install`
 *   2. `firebase deploy --only functions`
 *
 * Local dev:
 *   `firebase emulators:start --only functions,firestore`
 *
 * NOTE: This function runs in the Firebase Functions Node runtime, not
 * inside the Flutter app. It lives alongside the Flutter source so the
 * client + server live in the same repo, but it is deployed
 * independently and has nothing to do with the Dart build.
 */

const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

exports.sendPushOnNotificationCreate = functions.firestore
  .document("notifications/{notificationId}")
  .onCreate(async (snap, context) => {
    const data = snap.data() || {};
    const userId = data.userId;
    if (!userId || typeof userId !== "string" || userId.length === 0) {
      console.log("notification skipped: missing userId");
      return null;
    }

    // Load the recipient's tokens.
    const userRef = db.collection("users").doc(userId);
    const userSnap = await userRef.get();
    if (!userSnap.exists) {
      console.log(`notification ${context.params.notificationId}: user ` +
        `${userId} doesn't exist — skipping`);
      return null;
    }
    const userData = userSnap.data() || {};
    const tokens = Array.isArray(userData.fcmTokens)
      ? userData.fcmTokens.filter(
          (t) => typeof t === "string" && t.length > 0
        )
      : [];
    if (tokens.length === 0) {
      console.log(`notification ${context.params.notificationId}: no ` +
        `fcmTokens for ${userId} — skipping`);
      return null;
    }

    // Build the push payload. Keep title/body short and stuff routing
    // info into `data` so the client picks the same destination a
    // tray tap would.
    const title = (data.title || "RallyUp").toString();
    const body = (data.body || "You have a new notification.").toString();
    const targetType = data.targetType ? data.targetType.toString() : "";
    const targetId = data.targetId ? data.targetId.toString() : "";
    const type = data.type ? data.type.toString() : "";

    // sendEachForMulticast lets us collect per-token results so we
    // can prune dead tokens from the user's array.
    const result = await messaging.sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: {
        type,
        targetType,
        targetId,
        notificationId: context.params.notificationId,
      },
      apns: {
        payload: { aps: { sound: "default", badge: 1 } },
      },
      android: {
        priority: "high",
        notification: { sound: "default" },
      },
    });

    const deadTokens = [];
    result.responses.forEach((resp, idx) => {
      if (resp.success) return;
      const code = resp.error && resp.error.code;
      console.warn(
        `notification ${context.params.notificationId}: token ` +
          `${idx} failed with ${code}: ${resp.error && resp.error.message}`
      );
      if (
        code === "messaging/invalid-registration-token" ||
        code === "messaging/registration-token-not-registered"
      ) {
        deadTokens.push(tokens[idx]);
      }
    });

    if (deadTokens.length > 0) {
      console.log(
        `Pruning ${deadTokens.length} dead tokens for user ${userId}`
      );
      await userRef.update({
        fcmTokens: admin.firestore.FieldValue.arrayRemove(...deadTokens),
      });
    }

    return null;
  });
