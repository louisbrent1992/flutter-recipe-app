const axios = require("axios");

const BASE_URL = "https://flutter-recipe-app.onrender.com/api";
const TEST_ENDPOINTS = [
	"/discover/search?limit=10",
	"/discover/search?limit=20",
	"/discover/search?limit=50",
	"/discover/search?query=pasta&limit=10",
	"/discover/search?difficulty=Easy&limit=10",
];

async function testEndpoint(endpoint) {
	const startTime = Date.now();
	try {
		const response = await axios.get(`${BASE_URL}${endpoint}`, {
			timeout: 30000,
			headers: {
				"Content-Type": "application/json",
			},
		});
		const endTime = Date.now();
		const duration = endTime - startTime;

		console.log(
			`✅ ${endpoint} - ${duration}ms - ${
				response.data.recipes?.length || 0
			} recipes`
		);
		return {
			success: true,
			duration,
			count: response.data.recipes?.length || 0,
		};
	} catch (error) {
		const endTime = Date.now();
		const duration = endTime - startTime;
		console.log(`❌ ${endpoint} - ${duration}ms - Error: ${error.message}`);
		return { success: false, duration, error: error.message };
	}
}

async function runPerformanceTest() {
	console.log("🚀 Starting performance test...\n");

	const results = [];

	for (const endpoint of TEST_ENDPOINTS) {
		const result = await testEndpoint(endpoint);
		results.push({ endpoint, ...result });

		// Wait 1 second between requests to avoid rate limiting
		await new Promise((resolve) => setTimeout(resolve, 1000));
	}

	console.log("\n📊 Performance Summary:");
	console.log("========================");

	const successfulTests = results.filter((r) => r.success);
	const failedTests = results.filter((r) => !r.success);

	if (successfulTests.length > 0) {
		const avgDuration =
			successfulTests.reduce((sum, r) => sum + r.duration, 0) /
			successfulTests.length;
		const minDuration = Math.min(...successfulTests.map((r) => r.duration));
		const maxDuration = Math.max(...successfulTests.map((r) => r.duration));

		console.log(
			`✅ Successful tests: ${successfulTests.length}/${results.length}`
		);
		console.log(`⏱️  Average response time: ${avgDuration.toFixed(0)}ms`);
		console.log(`⚡ Fastest response: ${minDuration}ms`);
		console.log(`🐌 Slowest response: ${maxDuration}ms`);
	}

	if (failedTests.length > 0) {
		console.log(`❌ Failed tests: ${failedTests.length}/${results.length}`);
		failedTests.forEach((test) => {
			console.log(`   - ${test.endpoint}: ${test.error}`);
		});
	}

	console.log("\n💡 Recommendations:");
	if (successfulTests.length > 0) {
		const avgDuration =
			successfulTests.reduce((sum, r) => sum + r.duration, 0) /
			successfulTests.length;
		if (avgDuration > 5000) {
			console.log(
				"   - Consider implementing caching for frequently accessed data"
			);
			console.log("   - Optimize database queries with proper indexing");
			console.log("   - Consider using a CDN for static content");
		} else if (avgDuration > 2000) {
			console.log(
				"   - Response times are acceptable but could be improved with caching"
			);
		} else {
			console.log("   - Response times are good! 🎉");
		}
	}
}

// Run the test if this file is executed directly
if (require.main === module) {
	runPerformanceTest().catch(console.error);
}

module.exports = { runPerformanceTest };
