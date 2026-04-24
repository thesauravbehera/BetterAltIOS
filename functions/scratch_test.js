const admin = require('firebase-admin');

// Ensure standard Google Cloud ADC picks up the local firebase login
if (!admin.apps.length) {
    admin.initializeApp();
}

async function checkUser(phoneNumber) {
    console.log("Checking user account for:", phoneNumber);
    try {
        const userRecord = await admin.auth().getUserByPhoneNumber(phoneNumber);
        console.log("Auth UID:", userRecord.uid);
        
        const doc = await admin.firestore().collection('users').doc(userRecord.uid).get();
        if (doc.exists) {
            console.log("\n--- Firestore User Document ---");
            console.log(JSON.stringify(doc.data(), null, 2));
        } else {
            console.log("No Firestore document exists for this UID.");
        }
    } catch (e) {
        console.error("Error looking up user by phone:", e);
    }
    process.exit(0);
}

checkUser('+916280426194');
