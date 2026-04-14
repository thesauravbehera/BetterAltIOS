/**
 * Firebase Cloud Functions for Fat Burner.
 *
 * Setup (choose one):
 *
 * A) Secret Manager (production):
 *    firebase functions:secrets:set SHOPIFY_ACCESS_TOKEN
 *    firebase functions:config:set shopify.shop_domain="your-store.myshopify.com"
 *
 * B) .env for local emulator (copy .env.example to .env)
 */

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { defineSecret, defineString } from 'firebase-functions/params';
import * as admin from 'firebase-admin';
import { hasPurchasedFatBurner } from './shopify.js';

admin.initializeApp();

const shopifyAccessToken = defineSecret('SHOPIFY_ACCESS_TOKEN');
const shopifyShopDomain = defineString('SHOPIFY_SHOP_DOMAIN', { default: '' });

interface CheckPurchaseRequest {
  email?: string;
  phone?: string;
}

function getShopifyConfig(): { shopDomain: string; accessToken: string } {
  const shopDomain = process.env.SHOPIFY_SHOP_DOMAIN ?? shopifyShopDomain.value();
  const accessToken = process.env.SHOPIFY_ACCESS_TOKEN ?? shopifyAccessToken.value();

  if (!shopDomain || !accessToken) {
    throw new HttpsError(
      'failed-precondition',
      'Shopify is not configured. Set SHOPIFY_SHOP_DOMAIN and SHOPIFY_ACCESS_TOKEN.'
    );
  }

  return { shopDomain, accessToken };
}

export const checkFatBurnerPurchase = onCall(
  { secrets: [shopifyAccessToken] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be signed in to check purchase status.');
    }

    const data = request.data as CheckPurchaseRequest | undefined;

    if (!data || (typeof data !== 'object')) {
      throw new HttpsError('invalid-argument', 'Request must include email or phone.');
    }

    const { email, phone } = data;

    if (!email && !phone) {
      throw new HttpsError('invalid-argument', 'Provide at least one of: email, phone.');
    }

    const emailStr = typeof email === 'string' ? email.trim() : undefined;
    const phoneStr = typeof phone === 'string' ? phone.trim() : undefined;

    if (!emailStr && !phoneStr) {
      throw new HttpsError('invalid-argument', 'Email or phone cannot be empty.');
    }

    try {
      const purchased = await hasPurchasedFatBurner(
        getShopifyConfig(),
        emailStr || undefined,
        phoneStr || undefined
      );
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
  async (event) => {
    try {
      const now = new Date();
      // Format current time into IST to determine logic mapping
      const istTime = new Date(now.toLocaleString("en-US", {timeZone: "Asia/Kolkata"}));
      const h = istTime.getHours();
      const m = istTime.getMinutes();

      let targetPreference = "";
      // Define our targeting boundaries
      // 8-12 slot -> remind at 7:45 AM
      if (h === 7 && m >= 30 && m <= 59) {
        targetPreference = "8-12";
      }
      // 12-4 slot -> remind at 11:45 AM
      else if (h === 11 && m >= 30 && m <= 59) {
        targetPreference = "12-4";
      }
      // 4-8 slot -> remind at 3:45 PM (15:45)
      else if (h === 15 && m >= 30 && m <= 59) {
        targetPreference = "4-8";
      }

      if (targetPreference === "") {
        console.log(`Cron triggered at IST ${h}:${m}, but not within 15-min prior window to any dose bracket.`);
        return;
      }

      console.log(`Targeting users with dose_preference: ${targetPreference}`);
      const usersSnap = await admin.firestore().collection('users')
        .where('dose_preference', '==', targetPreference)
        .get();

      if (usersSnap.empty) {
        console.log('No users found for this dose window.');
        return;
      }

      const batch = admin.firestore().batch();
      const payloads: admin.messaging.Message[] = [];
      const timestamp = admin.firestore.FieldValue.serverTimestamp();

      for (const doc of usersSnap.docs) {
        const userData = doc.data();
        const fcmToken = userData.fcmToken;

        const title = "Time for your Dose! 🔥";
        const body = `Your ${targetPreference} window is approaching. Don't forget to take your BetterAlt capsule and check in!`;

        // Add to Notifications Collection
        const notifRef = doc.ref.collection('notifications').doc();
        batch.set(notifRef, {
          title,
          body,
          createdAt: timestamp,
          read: false,
          type: 'dose_reminder'
        });

        // Add to FCM Payload queue
        if (fcmToken) {
          payloads.push({
            token: fcmToken,
            notification: { title, body },
          });
        }
      }

      // Execute Firestore writes
      await batch.commit();

      // Dispatch Push Notifications
      if (payloads.length > 0) {
        // SendAll can accept an array up to 500 messages
        const response = await admin.messaging().sendEach(payloads);
        console.log(`Successfully sent ${response.successCount} messages; ${response.failureCount} failed.`);
      }

    } catch (error) {
      console.error("Dose Reminder Cron Job Failed:", error);
    }
  }
);
