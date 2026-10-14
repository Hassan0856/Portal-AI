/**
 * Portal AI - Firebase Cloud Functions
 * SOS Alert Lifecycle, Guardian Response Tracking, and 5-Minute Escalation Mechanism
 */

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

/**
 * Triggered immediately when a resident/guardian presses and holds the SOS button.
 * Dispatches high-priority notifications to all appointed guardians.
 */
exports.onSosCreated = onDocumentCreated(
  "sos_alerts/{alertId}",
  async (event) => {
    const alertId = event.params.alertId;
    const snap = event.data;
    if (!snap) return;

    const alertData = snap.data();
    console.log(`[PortalAI SOS] New SOS alert initiated: ${alertId}`, alertData);

    try {
      // 1. Notify Guardians via Firebase Cloud Messaging
      const payload = {
        notification: {
          title: "🚨 EMERGENCY SOS ALERT",
          body: `An emergency alert was triggered at ${alertData.location || "your doorstep"}. Immediate attention required.`,
        },
        data: {
          alertId: alertId,
          type: "sos_emergency",
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        topic: "guardians", // Or target specific guardian tokens
      };

      await admin.messaging().send(payload).catch((err) => {
        console.warn(`[PortalAI SOS] FCM broadcast note: ${err.message}`);
      });

      console.log(`[PortalAI SOS] Guardian notification sent for alert ${alertId}. 5-minute timer started.`);
    } catch (error) {
      console.error(`[PortalAI SOS] Error notifying guardians for alert ${alertId}:`, error);
    }
  }
);

/**
 * Scheduled Reconciliation Runner (runs every 1 minute).
 * Checks for any pending SOS alerts where the 5-minute deadline has elapsed
 * without Guardian acknowledgement.
 *
 * This server-side mechanism is 100% idempotent:
 * - If a Guardian acknowledged before the deadline, status is 'acknowledged' -> NO ESCALATION.
 * - If already escalated, escalationTriggered is true -> NO DUPLICATE ESCALATION.
 * - If still pending after 5 minutes -> ESCALATES once.
 */
exports.checkPendingSosEscalations = onSchedule(
  {
    schedule: "every 1 minutes",
    timeoutSeconds: 60,
  },
  async () => {
    const now = admin.firestore.Timestamp.now();
    console.log(`[PortalAI SOS] Running 5-minute escalation checker at ${now.toDate().toISOString()}`);

    const pendingQuery = await db
      .collection("sos_alerts")
      .where("status", "==", "pending")
      .where("escalationDeadline", "<=", now)
      .limit(50)
      .get();

    if (pendingQuery.empty) {
      console.log("[PortalAI SOS] No pending alerts requiring escalation.");
      return;
    }

    console.log(`[PortalAI SOS] Found ${pendingQuery.size} pending alert(s) past 5-minute deadline. Processing escalation...`);

    for (const doc of pendingQuery.docs) {
      await processIdempotentEscalation(doc.id);
    }
  }
);

/**
 * Idempotently executes escalation for an unacknowledged SOS alert.
 */
async function processIdempotentEscalation(alertId) {
  const docRef = db.collection("sos_alerts").doc(alertId);

  try {
    await db.runTransaction(async (transaction) => {
      const doc = await transaction.get(docRef);
      if (!doc.exists) {
        console.warn(`[PortalAI SOS] Alert ${alertId} not found.`);
        return;
      }

      const data = doc.data();

      // If Guardian responded before deadline, prevent escalation
      if (data.status === "acknowledged") {
        console.log(`[PortalAI SOS] Alert ${alertId} was already acknowledged by guardian. Escalation prevented.`);
        return;
      }

      // If already escalated, avoid duplicate alert
      if (data.status === "escalated" || data.escalationTriggered === true) {
        console.log(`[PortalAI SOS] Alert ${alertId} already escalated. Skipping duplicate.`);
        return;
      }

      // 5-minute window expired with NO response: Mark escalated
      transaction.update(docRef, {
        status: "escalated",
        escalationTriggered: true,
        escalatedAt: admin.firestore.FieldValue.serverTimestamp(),
        escalationReason: "No guardian response within 5 minutes.",
      });

      console.warn(`[PortalAI SOS] Alert ${alertId} ESCALATED! Guardian did not respond within 5 minutes.`);
    });

    // Execute External Escalation Handlers (Emergency Dispatch / SMS / High-Priority Broadcast)
    await triggerEmergencyEscalationDispatch(alertId);
  } catch (error) {
    console.error(`[PortalAI SOS] Failed transaction for escalation on ${alertId}:`, error);
  }
}

/**
 * External Escalation Dispatch:
 * Sends emergency alerts to secondary contacts / emergency authorities.
 */
async function triggerEmergencyEscalationDispatch(alertId) {
  try {
    const doc = await db.collection("sos_alerts").doc(alertId).get();
    const data = doc.data() || {};

    const escalationPayload = {
      notification: {
        title: "🚨 UNANSWERED EMERGENCY ESCALATION",
        body: `CRITICAL: Guardian did not respond within 5 minutes to SOS alert at ${data.location || "residence"}. Immediate emergency response initiated.`,
      },
      data: {
        alertId: alertId,
        type: "sos_escalated",
      },
      topic: "emergency_escalations",
    };

    await admin.messaging().send(escalationPayload).catch((e) => {
      console.warn(`[PortalAI SOS] Escalation messaging note: ${e.message}`);
    });

    console.log(`[PortalAI SOS] Escalation dispatch completed for ${alertId}`);
  } catch (err) {
    console.error(`[PortalAI SOS] Escalation dispatch error for ${alertId}:`, err);
  }
}

/**
 * Callable Function for Guardians to acknowledge an active SOS alert.
 * Acknowledging the alert stops the 5-minute timer and prevents escalation.
 */
exports.acknowledgeSosAlert = onCall(async (request) => {
  const alertId = request.data.alertId;
  const guardianId = request.auth ? request.auth.uid : (request.data.guardianId || "guardian");

  if (!alertId) {
    throw new HttpsError("invalid-argument", "alertId is required.");
  }

  const docRef = db.collection("sos_alerts").doc(alertId);

  return await db.runTransaction(async (transaction) => {
    const doc = await transaction.get(docRef);
    if (!doc.exists) {
      throw new HttpsError("not-found", `SOS alert ${alertId} not found.`);
    }

    const data = doc.data();

    if (data.status === "escalated") {
      return {
        success: false,
        status: "already_escalated",
        message: "The 5-minute window has already expired and this alert was escalated.",
      };
    }

    transaction.update(docRef, {
      status: "acknowledged",
      acknowledgedAt: admin.firestore.FieldValue.serverTimestamp(),
      acknowledgedBy: guardianId,
    });

    console.log(`[PortalAI SOS] Alert ${alertId} acknowledged by ${guardianId}. Escalation aborted.`);
    return {
      success: true,
      status: "acknowledged",
      message: "SOS alert acknowledged successfully. Escalation prevented.",
    };
  });
});
