/**
 * Firebase Cloud Functions for Fat Burner.
 *
 * Shopify credentials are loaded from environment variables (.env file).
 * The .env file is automatically deployed with the functions but never
 * committed to git (listed in .gitignore).
 */

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import * as admin from 'firebase-admin';
import { hasPurchasedFatBurner } from './shopify.js';

admin.initializeApp();

interface CheckPurchaseRequest {
  email?: string;
  phone?: string;
}

function getShopifyConfig(): { shopDomain: string; clientId: string; clientSecret: string } {
  const shopDomain = process.env.SHOPIFY_SHOP_DOMAIN ?? '';
  const clientId = process.env.SHOPIFY_CLIENT_ID ?? '';
  const clientSecret = process.env.SHOPIFY_CLIENT_SECRET ?? '';

  if (!shopDomain || !clientId || !clientSecret) {
    throw new HttpsError(
      'failed-precondition',
      'Shopify is not configured. Set SHOPIFY_SHOP_DOMAIN, SHOPIFY_CLIENT_ID, and SHOPIFY_CLIENT_SECRET in .env.'
    );
  }

  return { shopDomain, clientId, clientSecret };
}

export const checkFatBurnerPurchase = onCall(
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be signed in to check purchase status.');
    }

    const data = request.data as CheckPurchaseRequest | undefined;
    console.log(`[checkFatBurnerPurchase] Raw request data: ${JSON.stringify(data)}`);
    console.log(`[checkFatBurnerPurchase] Auth UID: ${request.auth.uid}`);

    if (!data || (typeof data !== 'object')) {
      throw new HttpsError('invalid-argument', 'Request must include email or phone.');
    }

    const { email, phone } = data;

    if (!email && !phone) {
      throw new HttpsError('invalid-argument', 'Provide at least one of: email, phone.');
    }

    const emailStr = typeof email === 'string' ? email.trim() : undefined;
    const phoneStr = typeof phone === 'string' ? phone.trim() : undefined;

    console.log(`[checkFatBurnerPurchase] Parsed email="${emailStr}", phone="${phoneStr}"`);

    if (!emailStr && !phoneStr) {
      throw new HttpsError('invalid-argument', 'Email or phone cannot be empty.');
    }

    try {
      const purchased = await hasPurchasedFatBurner(
        getShopifyConfig(),
        emailStr || undefined,
        phoneStr || undefined
      );
      console.log(`[checkFatBurnerPurchase] Result: purchased=${purchased}`);
      
      // Update Firestore — non-blocking, don't let this crash the response
      if (request.auth.uid) {
        try {
          await admin.firestore().collection('users').doc(request.auth.uid).set({
            has_purchased: purchased
          }, { merge: true });
          console.log(`[checkFatBurnerPurchase] Firestore updated has_purchased=${purchased}`);
        } catch (firestoreErr) {
          console.error('[checkFatBurnerPurchase] Firestore write failed (non-fatal):', firestoreErr);
        }
      }

      return { purchased };
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Unknown error';
      console.error('checkFatBurnerPurchase failed:', message);
      throw new HttpsError('internal', 'Unable to verify purchase. Please try again later.');
    }
  }
);


export const doseReminderCron = onSchedule(
  { schedule: 'every 15 minutes', timeZone: 'Asia/Kolkata' },
  async () => {
    try {
      const now = new Date();
      const istTime = new Date(now.toLocaleString("en-US", {timeZone: "Asia/Kolkata"}));
      const h = istTime.getHours();
      const m = istTime.getMinutes();

      // Rotating message templates (cycles every 3 days)
      const dayOfYear = Math.floor(
        (istTime.getTime() - new Date(istTime.getFullYear(), 0, 0).getTime()) / 86400000
      );
      const rotationIndex = dayOfYear % 3;

      const doseTemplates = [
        { title: "Capsule 1 Awaits! 🔥", body: "Your body is primed for fat burning. Grab your first capsule now!" },
        { title: "Keep the Streak Alive! 💪", body: "Champions don't skip. Time for your morning capsule — stay consistent!" },
        { title: "Consistency is Key! 🎯", body: "Every capsule counts toward your goal. Take Capsule 1 now!" },
      ];

      const streakTemplates = [
        { title: "⚠️ Streak in Danger!", body: "Your time slot is ending soon! Take your capsule NOW!" },
        { title: "🚨 Don't Lose Your Progress!", body: "Time is running out for today. Log your capsule now!" },
        { title: "⏰ Last Call for Today!", body: "Your capsule window is about to close. Your streak depends on it!" },
      ];

      const dayEndTemplates = [
        { title: "🌙 Streak Loss Imminent!", body: "The day is almost over and your capsule goal isn't met. Log them now to save your progress!" },
        { title: "📊 Final Streak Check", body: "Did you take both capsules today? Don't let a missed day break your momentum!" },
      ];

      let isStreakWarning = false;
      let isDayEndCheck = false;

      // Capsule reminders (15 min before slot START and slot END)
      // We mapped the preference target earlier, but since we redesigned it
      // to use queryPreferences arrays below, we can just remove targetPreference
      // entirely to fix the TS error.

      // Re-writing the logic for clarity in the Cron context
      let queryPreferences: string[] = [];
      if (h === 7 && m >= 30 && m <= 50) queryPreferences = ["8-12"]; // Start 8-12
      if (h === 11 && m >= 30 && m <= 50) queryPreferences = ["8-12", "12-4"]; // End 8-12, Start 12-4
      if (h === 15 && m >= 30 && m <= 50) queryPreferences = ["12-4", "4-8"]; // End 12-4, Start 4-8
      if (h === 19 && m >= 30 && m <= 50) queryPreferences = ["4-8"]; // End 4-8

      // Streak warnings (slot end exactly)
      if (h === 12 && m >= 0 && m <= 10) { queryPreferences = ["8-12"]; isStreakWarning = true; }
      if (h === 16 && m >= 0 && m <= 10) { queryPreferences = ["12-4"]; isStreakWarning = true; }
      if (h === 20 && m >= 0 && m <= 10) { queryPreferences = ["4-8"]; isStreakWarning = true; }

      // Day-end check (Streak Loss) at 10:30 PM (22:30)
      if (h === 22 && m >= 15 && m <= 45) {
        isDayEndCheck = true;
      }

      if (queryPreferences.length === 0 && !isDayEndCheck) {
        console.log(`Cron triggered at IST ${h}:${m}, not in any window.`);
        return;
      }

      // Select the right template
      let notifTitle: string;
      let notifBody: string;

      if (isDayEndCheck) {
        const tmpl = dayEndTemplates[rotationIndex % 2];
        notifTitle = tmpl.title;
        notifBody = tmpl.body;
      } else if (isStreakWarning) {
        const tmpl = streakTemplates[rotationIndex];
        notifTitle = tmpl.title;
        notifBody = tmpl.body;
      } else {
        const tmpl = doseTemplates[rotationIndex];
        notifTitle = tmpl.title;
        notifBody = tmpl.body;
      }

      // Query users
      let usersSnap;
      if (isDayEndCheck) {
        usersSnap = await admin.firestore().collection('users').get();
      } else {
        usersSnap = await admin.firestore().collection('users')
          .where('dose_preference', 'in', queryPreferences)
          .get();
      }

      if (usersSnap.empty) {
        console.log('No users found for this notification window.');
        return;
      }

      const batch = admin.firestore().batch();
      const payloads: admin.messaging.Message[] = [];
      const timestamp = admin.firestore.FieldValue.serverTimestamp();

      // Build today's IST date key for checking daily_logs
      const istNow = new Date(new Date().toLocaleString("en-US", {timeZone: "Asia/Kolkata"}));
      const todayKey = `${istNow.getFullYear()}-${String(istNow.getMonth() + 1).padStart(2, '0')}-${String(istNow.getDate()).padStart(2, '0')}`;

      for (const doc of usersSnap.docs) {
        const userData = doc.data();
        const fcmToken = userData.fcmToken;

        // For day-end streak-break: only notify users who HAVEN'T completed both capsules
        if (isDayEndCheck) {
          try {
            const dailyLog = await doc.ref.collection('daily_logs').doc(todayKey).get();
            const logData = dailyLog.data();
            const dose1Done = logData?.capsuleDose1 === true;
            const dose2Done = logData?.capsuleDose2 === true;

            if (dose1Done && dose2Done) {
              // User completed both capsules → skip, no streak break
              continue;
            }
          } catch (logErr) {
            console.warn(`Failed to check daily_log for user ${doc.id}: ${logErr}`);
          }
        }

        // Add to Notifications Collection
        const notifRef = doc.ref.collection('notifications').doc();
        batch.set(notifRef, {
          title: notifTitle,
          body: notifBody,
          createdAt: timestamp,
          read: false,
          type: isStreakWarning ? 'streak_warning' : isDayEndCheck ? 'day_end_check' : 'dose_reminder',
        });

        // Add to FCM Payload queue
        if (fcmToken) {
          payloads.push({
            token: fcmToken,
            notification: { title: notifTitle, body: notifBody },
          });
        }
      }

      // Execute Firestore writes
      await batch.commit();

      // Dispatch Push Notifications
      if (payloads.length > 0) {
        const response = await admin.messaging().sendEach(payloads);
        console.log(`Successfully sent ${response.successCount} messages; ${response.failureCount} failed.`);
      }

    } catch (error) {
      console.error("Dose Reminder Cron Job Failed:", error);
    }
  }
);
