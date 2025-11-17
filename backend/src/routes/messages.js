const express = require('express');
const { asyncHandler } = require('../middleware/errorHandler');
const { verifyToken } = require('../middleware/auth');
const { query } = require('../db');
const logger = require('../utils/logger');
const multer = require('multer');

// Parse multipart/form-data for attachments + text fields
const upload = multer({ storage: multer.memoryStorage() });

const fs = require('fs');
const path = require('path');

const router = express.Router();

// Debug middleware: log presence of Authorization header (helps debug 401s)
router.use((req, res, next) => {
	try {
		const hasAuth = !!req.headers.authorization;
		if (!hasAuth) logger.debug('Messages route: Authorization header NOT present');
		else logger.debug('Messages route: Authorization header present');
	} catch (e) {
		logger.debug('Messages route: Authorization check failed', e?.message);
	}
	next();
});

// List conversations (lightweight)
router.get('/', verifyToken, asyncHandler(async (req, res) => {
	// Return only conversations where the authenticated user is a member
	const wallet = req.user?.walletAddress;
	if (!wallet) return res.status(400).json({ success: false, error: 'Invalid user' });
	try {
		const result = await query(
			`SELECT c.id,
				c.title,
				c.avatar_url,
				c.created_at,
				COALESCE(cm.last_read, to_timestamp(0)) AS last_read_at,
				-- unread count: messages in conv newer than member.last_read
				COALESCE((SELECT COUNT(*) FROM messages m WHERE m.conversation_id = c.id AND m.created_at > COALESCE(cm.last_read, to_timestamp(0))), 0) AS unread_count
			     FROM conversations c
			 JOIN conversation_members cm ON cm.conversation_id = c.id
			 WHERE cm.wallet_address = $1
			 ORDER BY c.created_at DESC
			 LIMIT 200`,
			 [wallet]
		);
		// normalize field names to expected client keys
		const rows = result.rows.map(r => ({
			id: r.id,
			title: r.title,
			avatar: r.avatar_url || null,
			avatar_url: r.avatar_url || null,
			displayAvatar: r.avatar_url || null,
			created_at: r.created_at,
			createdAt: r.created_at,
			last_read_at: r.last_read_at,
			unreadCount: parseInt(r.unread_count, 10) || 0,
			unread_count: parseInt(r.unread_count, 10) || 0
		}));
		res.json({ success: true, count: rows.length, data: rows });
	} catch (e) {
		logger.debug('Messages GET fallback - DB query failed, returning empty list', e?.message);
		res.json({ success: true, count: 0, data: [] });
	}
}));

// Get messages for a conversation
router.get('/:conversationId/messages', verifyToken, asyncHandler(async (req, res) => {
	const { conversationId } = req.params;
	const page = parseInt(req.query.page || '1');
	const limit = parseInt(req.query.limit || '50');
	const offset = (page - 1) * limit;

	try {
		const result = await query(
			`SELECT m.id,
					m.sender_wallet,
					m.message AS content,
					m.message AS message,
					m.message AS text,
					m.message AS body,
					m.created_at,
					m.created_at AS createdAt,
					p.username AS senderUsername,
					p.username AS sender_username,
					p.display_name AS senderDisplayName,
					p.display_name AS sender_display_name,
					p.avatar_url AS senderAvatar,
					p.avatar_url AS sender_avatar
			 FROM messages m
			 LEFT JOIN profiles p ON p.wallet_address = m.sender_wallet
			 WHERE m.conversation_id = $1
			 ORDER BY m.created_at DESC
			 LIMIT $2 OFFSET $3`,
			[conversationId, limit, offset]
		);

		// Ensure every row has consistent fields (some DBs may return nulls)
		const rows = result.rows.map(r => ({
			id: r.id,
			conversation_id: r.conversation_id,
			sender_wallet: r.sender_wallet,
			content: r.content,
			message: r.message,
			text: r.text,
			body: r.body,
			created_at: r.created_at,
			createdAt: r.createdat || r.createdAt || r.created_at,
			senderUsername: r.senderusername || r.senderUsername || r.sender_username || null,
			sender_username: r.sender_username || r.senderUsername || null,
			senderDisplayName: r.senderDisplayName || r.sender_display_name || null,
			sender_display_name: r.sender_display_name || r.senderDisplayName || null,
			senderAvatar: r.senderAvatar || r.sender_avatar || null,
			sender_avatar: r.sender_avatar || r.senderAvatar || null
		}));

		res.json({ success: true, count: rows.length, data: rows });
	} catch (e) {
		logger.debug('Messages conversation GET fallback - DB query failed for', conversationId);
		res.json({ success: true, count: 0, data: [] });
	}
}));

// Post a message to a conversation
// Accept JSON and multipart/form-data (attachments)
router.post('/:conversationId/messages', verifyToken, upload.any(), asyncHandler(async (req, res) => {
	const { conversationId } = req.params;
	const sender = req.user?.walletAddress || 'unknown';

	// Accept several possible field names from different clients
	let content = null;
	if (req.body) {
		content = req.body.content || req.body.message || req.body.body || req.body.text || req.body.messageBody || null;

		// If still null, attempt to find the first string field in the body
		if (!content) {
			for (const k of Object.keys(req.body)) {
				const v = req.body[k];
				if (typeof v === 'string' && v.trim().length > 0) {
					content = v;
					break;
				}
			}
		}
	}

	if (!content || (typeof content === 'string' && content.trim().length === 0)) {
		try {
			logger.info('Messages POST received missing content. Body snapshot: ' + JSON.stringify(req.body || {}));
		} catch (e) {
			logger.info('Messages POST received missing content. Body snapshot unavailable');
		}
		return res.status(400).json({ success: false, error: 'Content is required' });
	}

	try {
		const insert = await query(
			`INSERT INTO messages (conversation_id, sender_wallet, message)
			 VALUES ($1, $2, $3) RETURNING id`,
			[conversationId, sender, content]
		);

		const messageId = insert.rows[0].id;

		const result = await query(
			`SELECT m.id, m.conversation_id, m.sender_wallet,
					m.message AS content,
					m.message AS message,
					m.message AS text,
					m.message AS body,
					m.created_at,
					m.created_at AS createdAt,
					p.username AS senderUsername,
					p.username AS sender_username,
					p.display_name AS senderDisplayName,
					p.display_name AS sender_display_name,
					p.avatar_url AS senderAvatar,
					p.avatar_url AS sender_avatar
			 FROM messages m
			 LEFT JOIN profiles p ON p.wallet_address = m.sender_wallet
			 WHERE m.id = $1`,
			[messageId]
		);

		const r = result.rows[0] || {};
		const message = {
			id: r.id,
			conversation_id: r.conversation_id,
			sender_wallet: r.sender_wallet,
			content: r.content,
			message: r.message,
			text: r.text,
			body: r.body,
			created_at: r.created_at,
			createdAt: r.createdAt || r.created_at,
			senderUsername: r.senderUsername || r.sender_username || null,
			sender_username: r.sender_username || r.senderUsername || null,
			senderDisplayName: r.senderDisplayName || r.sender_display_name || null,
			sender_display_name: r.sender_display_name || r.senderDisplayName || null,
			senderAvatar: r.senderAvatar || r.sender_avatar || null,
			sender_avatar: r.sender_avatar || r.senderAvatar || null
		};

		// Emit via WebSocket if available
		const io = req.app.get('io');
		if (io) io.to(`conversation:${conversationId}`).emit('message:received', message);

		res.status(201).json({ success: true, data: message });
	} catch (e) {
		logger.debug('Messages POST fallback - DB insert failed, returning stub');
		const stub = {
			id: `msg_${Date.now()}`,
			conversation_id: conversationId,
			sender_wallet: sender,
			content,
			message: content,
			text: content,
			body: content,
			created_at: new Date().toISOString(),
			createdAt: new Date().toISOString(),
			senderUsername: null,
			sender_username: null,
			senderDisplayName: null,
			sender_display_name: null,
			senderAvatar: null,
			sender_avatar: null
		};
		const io = req.app.get('io');
		if (io) io.to(`conversation:${conversationId}`).emit('message:received', stub);
		res.status(201).json({ success: true, data: stub });
	}
}));

// Mark conversation as read by current user
router.put('/:conversationId/read', verifyToken, asyncHandler(async (req, res) => {
	const { conversationId } = req.params;
	const wallet = req.user?.walletAddress;

	if (!wallet) return res.status(400).json({ success: false, error: 'Invalid user' });

	try {
		await query(
			`UPDATE conversation_members SET last_read = NOW() WHERE conversation_id = $1 AND wallet_address = $2`,
			[conversationId, wallet]
		);

		// Emit read update to conversation room
		try {
			const io = req.app.get('io');
			if (io) io.to(`conversation:${conversationId}`).emit('conversation:member:read', { wallet, conversationId, last_read_at: new Date().toISOString() });
		} catch (e) {
			logger.debug('Failed to emit conversation read event', e?.message);
		}
		res.json({ success: true, message: 'Marked as read' });
	} catch (e) {
		logger.debug('Mark read fallback - DB update failed for', conversationId);
		res.json({ success: true, message: 'Marked as read (stub)' });
	}
}));

// Mark a specific message as read by current user (frontend expects this route)
router.put('/:conversationId/messages/:messageId/read', verifyToken, asyncHandler(async (req, res) => {
	const { conversationId, messageId } = req.params;
	const wallet = req.user?.walletAddress;

	if (!wallet) return res.status(400).json({ success: false, error: 'Invalid user' });

	try {
		// Get the message timestamp to set as last_read
		const msgRes = await query(
			`SELECT created_at FROM messages WHERE id = $1 AND conversation_id = $2 LIMIT 1`,
			[messageId, conversationId]
		);

		if (!msgRes.rows || msgRes.rows.length === 0) {
			return res.status(404).json({ success: false, error: 'Message not found' });
		}

		const messageCreatedAt = msgRes.rows[0].created_at;

		await query(
			`UPDATE conversation_members SET last_read = $1 WHERE conversation_id = $2 AND wallet_address = $3`,
			[messageCreatedAt, conversationId, wallet]
		);

		// Emit read event for this message so other clients update UI
		try {
			const io = req.app.get('io');
			if (io) io.to(`conversation:${conversationId}`).emit('message:read', { messageId, conversationId, wallet, last_read_at: messageCreatedAt });
		} catch (e) {
			logger.debug('Failed to emit message read event', e?.message);
		}

		res.json({ success: true, message: 'Message marked as read', messageId, last_read_at: messageCreatedAt });
	} catch (e) {
		logger.debug('Mark message read fallback - DB update failed for', conversationId, messageId, e?.message);
		res.status(500).json({ success: false, error: 'Failed to mark message read' });
	}
}));

// Get conversation members
router.get('/:conversationId/members', verifyToken, asyncHandler(async (req, res) => {
	const { conversationId } = req.params;
	try {
		// Return standardized fields and enrich with profile display name + avatar when available
		const result = await query(
			`SELECT cm.wallet_address AS wallet_address,
					cm.wallet_address AS wallet,
					cm.wallet_address AS walletAddress,
					cm.joined_at,
					cm.last_read AS last_read_at,
					p.display_name AS displayName,
					p.username AS username,
					p.avatar_url AS avatar_url
			 FROM conversation_members cm
			 LEFT JOIN profiles p ON p.wallet_address = cm.wallet_address
			 WHERE cm.conversation_id = $1`,
			[conversationId]
		);

		// If no explicit members found (rare), try to derive members from messages senders as a fallback
		let rows = result.rows;
		if ((!rows || rows.length === 0)) {
			logger.debug('Members GET: no conversation_members rows found, deriving from messages for', conversationId);
			try {
				const msgRes = await query(
					`SELECT DISTINCT sender_wallet AS wallet_address FROM messages WHERE conversation_id = $1 LIMIT 50`,
					[conversationId]
				);
				rows = (msgRes.rows || []).map(r => ({ wallet_address: r.wallet_address, wallet: r.wallet_address, walletAddress: r.wallet_address, joined_at: null, last_read_at: null }));
			} catch (e) {
				logger.debug('Members GET fallback from messages failed for', conversationId, e?.message);
				rows = [];
			}
		}

		res.json({ success: true, count: rows.length, data: rows });
	} catch (e) {
		logger.debug('Members GET fallback - DB query failed for', conversationId, e?.message);
		res.json({ success: true, count: 0, data: [] });
	}
}));

// Add a member to a conversation
router.post('/:conversationId/members', verifyToken, asyncHandler(async (req, res) => {
	const { conversationId } = req.params;
	const { walletAddress, username } = req.body || {};
	let wallet = walletAddress;

	// If username provided, resolve to wallet address
	if (!wallet && username) {
		try {
			const p = await query('SELECT wallet_address FROM profiles WHERE username = $1 LIMIT 1', [username]);
			if (p.rows.length > 0) wallet = p.rows[0].wallet_address;
		} catch (e) {
			logger.debug('Failed to resolve username to wallet', username, e?.message);
		}
	}

	if (!wallet) return res.status(400).json({ success: false, error: 'walletAddress or username required' });

	try {
		await query(
			`INSERT INTO conversation_members (conversation_id, wallet_address) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
			[conversationId, wallet]
		);

		const members = await query(
			`SELECT wallet_address AS wallet, joined_at, last_read AS last_read_at FROM conversation_members WHERE conversation_id = $1`,
			[conversationId]
		);

				try {
					const io = req.app.get('io');
					if (io) io.to(`conversation:${conversationId}`).emit('chat:members-updated', { conversationId, members: members.rows });
				} catch (e) { logger.debug('Failed to emit members updated', e?.message); }
				// Also emit to each member's user room to help clients update their conversation list
				try {
					const io2 = req.app.get('io');
					if (io2) {
						for (const m of members.rows) {
							try { io2.to(`user:${(m.wallet || '').toString().toLowerCase()}`).emit('chat:members-updated', { conversationId, members: members.rows }); } catch (e) {}
						}
					}
				} catch (e) {}
				res.status(201).json({ success: true, data: members.rows });
	} catch (e) {
		logger.debug('Add member fallback - DB insert failed', e?.message);
		res.status(201).json({ success: true, data: [] });
	}
}));

// Create a new conversation
router.post('/', verifyToken, asyncHandler(async (req, res) => {
	const { title, members } = req.body || {};
	const creator = req.user?.walletAddress || null;

	if (!creator) return res.status(400).json({ success: false, error: 'Invalid user' });

	// members should be an array of wallet addresses (strings)
	const membersArr = Array.isArray(members) ? members : [];

	try {
		// create conversation
		const convInsert = await query(
			`INSERT INTO conversations (title, created_by) VALUES ($1, $2) RETURNING id, title, created_at`,
			[title || null, creator]
		);
		const conv = convInsert.rows[0];

		// ensure creator is a member
		const uniqueMembers = Array.from(new Set([creator, ...membersArr]));

		for (const w of uniqueMembers) {
			try {
				await query(
					`INSERT INTO conversation_members (conversation_id, wallet_address) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
					[conv.id, w]
				);
			} catch (e) {
				// continue inserting other members even if one fails
				logger.debug('Failed to insert conversation member', w, e?.message);
			}
		}

				// Emit chat:new-conversation event to each member's personal room
				try {
					const io = req.app.get('io');
					if (io) {
						const conversationPayload = { ...conv, members: uniqueMembers };
						for (const m of uniqueMembers) {
							try { io.to(`user:${(m || '').toString().toLowerCase()}`).emit('chat:new-conversation', conversationPayload); } catch (e) { logger.debug('Failed to emit new conversation to user', m, e?.message); }
						}
					}
				} catch (e) { logger.debug('chat:new-conversation emit failed', e?.message); }

				// return created conversation with minimal members list
				res.status(201).json({ success: true, data: { ...conv, members: uniqueMembers } });
	} catch (e) {
		logger.debug('Create conversation fallback - DB insert failed', e?.message);
		const stubId = `conv_${Date.now()}`;
		const uniqueMembers = Array.from(new Set([creator, ...membersArr]));
		res.status(201).json({ success: true, data: { id: stubId, title: title || null, created_at: new Date().toISOString(), members: uniqueMembers } });
	}
}));

module.exports = router;

// Conversation avatar upload
// POST /api/conversations/:conversationId/avatar
router.post('/:conversationId/avatar', verifyToken, upload.single('file'), asyncHandler(async (req, res) => {
	const { conversationId } = req.params;
	if (!req.file) return res.status(400).json({ success: false, error: 'No file uploaded' });

	try {
		const uploadsDir = path.join(__dirname, '..', '..', 'uploads', 'conversations');
		if (!fs.existsSync(uploadsDir)) fs.mkdirSync(uploadsDir, { recursive: true });
		const originalName = req.file.originalname || `${Date.now()}.png`;
		const safeName = `${conversationId}_${Date.now()}_${originalName.replace(/[^a-zA-Z0-9.\-_]/g, '_')}`;
		const destPath = path.join(uploadsDir, safeName);
		fs.writeFileSync(destPath, req.file.buffer);

		// Store relative URL so clients can resolve via baseUrl
		const avatarUrl = `/uploads/conversations/${safeName}`;
		try {
			await query('UPDATE conversations SET avatar_url = $1 WHERE id = $2', [avatarUrl, conversationId]);
		} catch (e) {
			logger.debug('Failed to update conversation avatar_url in DB', e?.message);
		}

		// Emit conversation update to conversation room and to members' user rooms
		try {
			const io = req.app.get('io');
			if (io) {
				const payload = { conversationId, avatar: avatarUrl, avatar_url: avatarUrl, displayAvatar: avatarUrl };
				io.to(`conversation:${conversationId}`).emit('chat:conversation-updated', payload);
				// Also notify user rooms by looking up members
				try {
					const membersRes = await query('SELECT wallet_address AS wallet FROM conversation_members WHERE conversation_id = $1', [conversationId]);
					for (const m of membersRes.rows) {
						try { io.to(`user:${(m.wallet || '').toString().toLowerCase()}`).emit('chat:conversation-updated', payload); } catch (e) {}
					}
				} catch (e) { logger.debug('Failed to fetch conversation members for avatar emit', e?.message); }
			}
		} catch (e) { logger.debug('Failed to emit conversation avatar update', e?.message); }

		return res.json({ success: true, data: { avatar: avatarUrl, avatar_url: avatarUrl } });
	} catch (err) {
		logger.debug('Conversation avatar upload failed', err?.message || err);
		return res.status(500).json({ success: false, error: 'Failed to save avatar' });
	}
}));

