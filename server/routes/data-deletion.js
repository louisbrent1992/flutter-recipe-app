const express = require("express");
const router = express.Router();
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");
const rateLimit = require("express-rate-limit");

// Rate limiting for deletion requests
const deletionRequestLimiter = rateLimit({
	windowMs: 15 * 60 * 1000, // 15 minutes
	max: 3, // Limit each IP to 3 requests per windowMs
	message: {
		success: false,
		message: "Too many deletion requests. Please try again later.",
	},
	standardHeaders: true,
	legacyHeaders: false,
});

// Email transporter configuration
const createEmailTransporter = () => {
	return nodemailer.createTransporter({
		host: process.env.SMTP_HOST || "smtp.gmail.com",
		port: process.env.SMTP_PORT || 587,
		secure: false,
		auth: {
			user: process.env.SMTP_USER,
			pass: process.env.SMTP_PASS,
		},
	});
};

// Validate email format
const isValidEmail = (email) => {
	const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
	return emailRegex.test(email);
};

// Log deletion request to Firestore
const logDeletionRequest = async (requestData) => {
	try {
		const db = admin.firestore();
		const logEntry = {
			...requestData,
			status: "pending",
			createdAt: admin.firestore.FieldValue.serverTimestamp(),
			processedAt: null,
			processedBy: null,
		};

		const docRef = await db.collection("deletion_requests").add(logEntry);
		return docRef.id;
	} catch (error) {
		console.error("Error logging deletion request:", error);
		throw error;
	}
};

// Send confirmation email to user
const sendConfirmationEmail = async (email, requestId) => {
	try {
		const transporter = createEmailTransporter();

		const mailOptions = {
			from: {
				name: "RecipEase Privacy Team",
				address: process.env.SMTP_USER || "privacy@recipease.kitchen",
			},
			to: email,
			subject: "Data Deletion Request Received - RecipEase",
			html: `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Data Deletion Request Confirmation</title>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background: linear-gradient(135deg, #ff6b6b 0%, #ee5a24 100%); color: white; padding: 30px; text-align: center; border-radius: 12px 12px 0 0; }
            .content { background: #f8f9fa; padding: 30px; border-radius: 0 0 12px 12px; }
            .warning-box { background: #fff3cd; border: 2px solid #ffc107; border-radius: 8px; padding: 20px; margin: 20px 0; }
            .info-box { background: #d1ecf1; border: 2px solid #bee5eb; border-radius: 8px; padding: 20px; margin: 20px 0; }
            .footer { text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #dee2e6; color: #6c757d; font-size: 14px; }
            h1 { margin: 0; font-size: 24px; }
            h2 { color: #2c3e50; margin-top: 30px; }
            ul { padding-left: 20px; }
            li { margin-bottom: 8px; }
            .request-id { font-family: monospace; background: #e9ecef; padding: 4px 8px; border-radius: 4px; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <div style="display: flex; align-items: center; justify-content: center; gap: 15px; margin-bottom: 10px;">
                <img src="${
									process.env.SERVER_URL || "https://recipease.kitchen"
								}/logo.png" alt="RecipEase Logo" style="width: 40px; height: 40px; object-fit: contain; filter: brightness(0) invert(1);" />
                <h1 style="margin: 0;">RecipEase</h1>
              </div>
              <p>Data Deletion Request Confirmation</p>
            </div>
            
            <div class="content">
              <h2>Request Received</h2>
              <p>We have received your request to delete your RecipEase account and all associated data.</p>
              
              <div class="info-box">
                <p><strong>Request ID:</strong> <span class="request-id">${requestId}</span></p>
                <p><strong>Email:</strong> ${email}</p>
                <p><strong>Submitted:</strong> ${new Date().toLocaleString()}</p>
              </div>
              
              <h2>What Happens Next?</h2>
              <ol>
                <li><strong>Review Period:</strong> We will review your request within 2-3 business days</li>
                <li><strong>Data Deletion:</strong> If approved, we will permanently delete all your data within 30 days</li>
                <li><strong>Confirmation:</strong> You will receive a final confirmation email once deletion is complete</li>
              </ol>
              
              <h2>Data to be Deleted</h2>
              <ul>
                <li>Your account profile and personal information</li>
                <li>All recipes you've created or saved</li>
                <li>Your recipe collections and favorites</li>
                <li>Profile pictures and uploaded images</li>
                <li>App preferences and settings</li>
                <li>Usage analytics and activity data</li>
                <li>Any subscription or billing information</li>
                <li>Comments, ratings, and shared content</li>
              </ul>
              
              <div class="warning-box">
                <p><strong>⚠️ Important:</strong> This action cannot be undone. Once your data is deleted, it cannot be recovered.</p>
              </div>
              
              <h2>Need to Cancel?</h2>
              <p>If you change your mind and want to cancel this deletion request, please reply to this email or contact us at <a href="mailto:privacy@recipease.kitchen">privacy@recipease.kitchen</a> with your request ID: <span class="request-id">${requestId}</span></p>
              
              <h2>Questions?</h2>
              <p>If you have any questions about this process, please don't hesitate to contact our privacy team:</p>
              <ul>
                <li><strong>Email:</strong> <a href="mailto:privacy@recipease.kitchen">privacy@recipease.kitchen</a></li>
                <li><strong>Support:</strong> <a href="mailto:support@recipease.kitchen">support@recipease.kitchen</a></li>
              </ul>
            </div>
            
            <div class="footer">
              <p>&copy; 2024 RecipEase. All rights reserved.</p>
              <p>This email was sent regarding your data deletion request. Please do not reply to this automated message.</p>
            </div>
          </div>
        </body>
        </html>
      `,
			text: `
Data Deletion Request Confirmation - RecipEase

Request ID: ${requestId}
Email: ${email}
Submitted: ${new Date().toLocaleString()}

We have received your request to delete your RecipEase account and all associated data.

What Happens Next?
1. Review Period: We will review your request within 2-3 business days
2. Data Deletion: If approved, we will permanently delete all your data within 30 days
3. Confirmation: You will receive a final confirmation email once deletion is complete

Data to be Deleted:
- Your account profile and personal information
- All recipes you've created or saved
- Your recipe collections and favorites
- Profile pictures and uploaded images
- App preferences and settings
- Usage analytics and activity data
- Any subscription or billing information
- Comments, ratings, and shared content

IMPORTANT: This action cannot be undone. Once your data is deleted, it cannot be recovered.

Need to Cancel?
If you change your mind and want to cancel this deletion request, please reply to this email or contact us at privacy@recipease.kitchen with your request ID: ${requestId}

Questions?
If you have any questions about this process, please contact our privacy team:
- Email: privacy@recipease.kitchen
- Support: support@recipease.kitchen

© 2024 RecipEase. All rights reserved.
      `,
		};

		await transporter.sendMail(mailOptions);
		console.log(`Confirmation email sent to ${email} for request ${requestId}`);
	} catch (error) {
		console.error("Error sending confirmation email:", error);
		// Don't throw error - email failure shouldn't fail the request
	}
};

// Send notification to admin team
const sendAdminNotification = async (requestData, requestId) => {
	try {
		const transporter = createEmailTransporter();

		const mailOptions = {
			from: {
				name: "RecipEase System",
				address: process.env.SMTP_USER || "system@recipease.kitchen",
			},
			to: process.env.ADMIN_EMAIL || "privacy@recipease.kitchen",
			subject: `New Data Deletion Request - ${requestId}`,
			html: `
        <h2>New Data Deletion Request</h2>
        <p><strong>Request ID:</strong> ${requestId}</p>
        <p><strong>Email:</strong> ${requestData.email}</p>
        <p><strong>Reason:</strong> ${requestData.reason || "Not provided"}</p>
        <p><strong>Source:</strong> ${requestData.source}</p>
        <p><strong>User Agent:</strong> ${requestData.userAgent}</p>
        <p><strong>Timestamp:</strong> ${requestData.timestamp}</p>
        
        <h3>Action Required:</h3>
        <ol>
          <li>Review the request in the admin dashboard</li>
          <li>Verify the user's identity if needed</li>
          <li>Process the deletion within 30 days</li>
          <li>Send final confirmation to user</li>
        </ol>
        
        <p><a href="${
					process.env.ADMIN_DASHBOARD_URL || "https://admin.recipease.kitchen"
				}/deletion-requests/${requestId}">View Request in Dashboard</a></p>
      `,
		};

		await transporter.sendMail(mailOptions);
		console.log(`Admin notification sent for request ${requestId}`);
	} catch (error) {
		console.error("Error sending admin notification:", error);
		// Don't throw error - admin notification failure shouldn't fail the request
	}
};

// POST /api/data-deletion-request
router.post(
	"/data-deletion-request",
	deletionRequestLimiter,
	async (req, res) => {
		try {
			const { email, reason, timestamp, userAgent, source } = req.body;

			// Validate required fields
			if (!email) {
				return res.status(400).json({
					success: false,
					message: "Email address is required",
				});
			}

			if (!isValidEmail(email)) {
				return res.status(400).json({
					success: false,
					message: "Please provide a valid email address",
				});
			}

			// Prepare request data
			const requestData = {
				email: email.toLowerCase().trim(),
				reason: reason || "",
				timestamp: timestamp || new Date().toISOString(),
				userAgent: userAgent || "",
				source: source || "unknown",
				ipAddress: req.ip || req.connection.remoteAddress,
				headers: {
					"user-agent": req.get("User-Agent"),
					referer: req.get("Referer"),
					"x-forwarded-for": req.get("X-Forwarded-For"),
				},
			};

			// Log the request to Firestore
			const requestId = await logDeletionRequest(requestData);

			// Send confirmation email to user
			await sendConfirmationEmail(email, requestId);

			// Send notification to admin team
			await sendAdminNotification(requestData, requestId);

			// Log for monitoring
			console.log(`Data deletion request submitted: ${requestId} for ${email}`);

			res.json({
				success: true,
				message: "Data deletion request submitted successfully",
				requestId: requestId,
				estimatedProcessingTime: "30 days",
			});
		} catch (error) {
			console.error("Error processing data deletion request:", error);
			const errorHandler = require("../utils/errorHandler");
			return errorHandler.serverError(
				res,
				"We couldn't process your request right now. Please try again shortly."
			);
		}
	}
);

// GET /api/data-deletion-request/:id (for checking status)
router.get("/data-deletion-request/:id", async (req, res) => {
	try {
		const { id } = req.params;

		const db = admin.firestore();
		const doc = await db.collection("deletion_requests").doc(id).get();

		if (!doc.exists) {
			return res.status(404).json({
				success: false,
				message: "Deletion request not found",
			});
		}

		const data = doc.data();

		// Return limited information for privacy
		res.json({
			success: true,
			data: {
				id: doc.id,
				status: data.status,
				createdAt: data.createdAt,
				processedAt: data.processedAt,
				email: data.email.replace(/(.{2}).*(@.*)/, "$1***$2"), // Mask email
			},
		});
	} catch (error) {
		console.error("Error fetching deletion request:", error);
		const errorHandler = require("../utils/errorHandler");
		return errorHandler.serverError(
			res,
			"We couldn't fetch the request status right now. Please try again shortly."
		);
	}
});

module.exports = router;
