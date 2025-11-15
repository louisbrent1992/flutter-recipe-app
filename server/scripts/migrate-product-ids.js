/**
 * Script to migrate old product IDs to new ones in purchase records
 * Run with: node server/scripts/migrate-product-ids.js
 */

require("dotenv").config();
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
require("../config/firebase").initFirebase();

const db = getFirestore();

async function migrateProductIds() {
	try {
		console.log("Starting product ID migration...");

		// Migration map: old product ID -> new product ID
		const migrationMap = {
			'recipease_imports_10': 'recipease_imports_15',
			'recipease_ultimate_bundle': 'recipease_ultimate_bundle_v2',
		};

		const oldProductIds = Object.keys(migrationMap);
		let totalUpdated = 0;
		let totalUsersChecked = 0;
		const migrationResults = {};

		// Initialize results for each old product ID
		oldProductIds.forEach((oldId) => {
			migrationResults[oldId] = {
				oldId,
				newId: migrationMap[oldId],
				count: 0,
			};
		});

		// Get all users
		const usersSnapshot = await db.collection("users").get();
		totalUsersChecked = usersSnapshot.size;

		console.log(`Checking ${totalUsersChecked} users for old product IDs...`);

		// Process each user's purchases
		for (const userDoc of usersSnapshot.docs) {
			const userId = userDoc.id;
			const purchasesRef = db
				.collection("users")
				.doc(userId)
				.collection("purchases");

			// Check each old product ID
			for (const oldProductId of oldProductIds) {
				// Query purchases with the old product ID
				const purchasesSnapshot = await purchasesRef
					.where("productId", "==", oldProductId)
					.get();

				if (!purchasesSnapshot.empty) {
					const batch = db.batch();
					let batchCount = 0;

					purchasesSnapshot.forEach((purchaseDoc) => {
						const newProductId = migrationMap[oldProductId];
						batch.update(purchaseDoc.ref, {
							productId: newProductId,
							migratedAt: FieldValue.serverTimestamp(),
							migratedFrom: oldProductId,
						});
						batchCount++;
					});

					if (batchCount > 0) {
						await batch.commit();
						migrationResults[oldProductId].count += batchCount;
						totalUpdated += batchCount;
						console.log(
							`✅ Updated ${batchCount} purchase(s) for user ${userId}: ${oldProductId} -> ${migrationMap[oldProductId]}`
						);
					}
				}
			}
		}

		console.log(`\n🎉 Migration complete!`);
		console.log(`Total users checked: ${totalUsersChecked}`);
		console.log(`Total purchases updated: ${totalUpdated}`);
		console.log(`\nMigration breakdown:`);
		Object.values(migrationResults).forEach((result) => {
			console.log(`  ${result.oldId} -> ${result.newId}: ${result.count} records`);
		});

		process.exit(0);
	} catch (error) {
		console.error("❌ Error during product ID migration:", error);
		process.exit(1);
	}
}

migrateProductIds();

