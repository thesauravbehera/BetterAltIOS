const admin = require('firebase-admin');
admin.initializeApp();

async function backfill() {
  let count = 0;
  let pageToken;

  do {
    const listUsersResult = await admin.auth().listUsers(1000, pageToken);
    pageToken = listUsersResult.pageToken;

    for (const userRecord of listUsersResult.users) {
      if (userRecord.phoneNumber) {
        await admin.firestore().collection('phone_registry').doc(userRecord.phoneNumber).set({
          registeredAt: admin.firestore.FieldValue.serverTimestamp(),
          backfilled: true
        });
        count++;
      }
    }
  } while (pageToken);

  console.log(`Backfilled ${count} phone numbers into phone_registry.`);
}

backfill().catch(console.error);
