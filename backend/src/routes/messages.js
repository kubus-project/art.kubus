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
const storageService = require('../services/storageService');

const router = express.Router();
const { normalizeAvatarUrl } = require('../utils/avatar');

const parseJsonField = (value, fallback = {}) => {
	if (!value && value !== 0) return { ...fallback };
	if (typeof value === 'object' && !Buffer.isBuffer(value)) return value;
	if (typeof value === 'string') {
		try {
			return JSON.parse(value);
		} catch (e) {
			return { ...fallback };
		}
	}
	return { ...fallback };
};

const buildAttachmentPayload = (file, uploaded) => ({
	filename: file.originalname || file.filename || 'attachment',
	bytes: typeof file.size === 'number' ? file.size : null,
	size: typeof file.size === 'number' ? file.size : null,
	mimeType: file.mimetype || 'application/octet-stream',
	url: uploaded?.url || null,
	ipfsCid: uploaded?.cid || null,
	storagePath: uploaded?.path || null,
});

const parseJsonArray = (value, fallback = []) => {
	if (!value && value !== 0) return [...fallback];
	if (Array.isArray(value)) return value;
	if (typeof value === 'string') {
		try {
			const parsed = JSON.parse(value);
			return Array.isArray(parsed) ? parsed : [...fallback];
		} catch (e) {
			return [...fallback];
		}
	}
	return [...fallback];
};

const ensureConversationMember = async (conversationId, wallet) => {
	if (!wallet) return false;
	const membership = await query(
		`SELECT 1 FROM conversation_members WHERE conversation_id = $1 AND wallet_address = $2 LIMIT 1`,
		[conversationId, wallet]
	);
	return membership?.rows?.length > 0;
};

const fetchReactionSummary = async (messageId) => {
	const summaryRes = await query(
		`SELECT COALESCE(json_agg(json_build_object(
			'emoji', emoji,
			'count', cnt,
			'reactors', reactors
		)), '[]'::json) AS reactions
		 FROM (
			SELECT emoji,
				COUNT(*) AS cnt,
				ARRAY_AGG(wallet_address) AS reactors
			FROM message_reactions
			WHERE message_id = $1
			GROUP BY emoji
		 ) agg`,
		[messageId]
	);
	const raw = summaryRes.rows?.[0]?.reactions;
	return parseJsonArray(raw, []);
};

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
				c.updated_at,
				c.is_group,
				c.created_by,
				COALESCE(cm.last_read, to_timestamp(0)) AS last_read_at,
				COALESCE((SELECT COUNT(*) FROM messages m WHERE m.conversation_id = c.id AND m.created_at > COALESCE(cm.last_read, to_timestamp(0))), 0) AS unread_count,
				(SELECT message FROM messages m WHERE m.conversation_id = c.id ORDER BY m.created_at DESC LIMIT 1) AS last_message,
				(SELECT created_at FROM messages m WHERE m.conversation_id = c.id ORDER BY m.created_at DESC LIMIT 1) AS last_message_at,
				(
					SELECT COALESCE(json_agg(cm2.wallet_address ORDER BY cm2.joined_at), '[]'::json)
					FROM conversation_members cm2
					WHERE cm2.conversation_id = c.id
				) AS member_wallets,
				(
					SELECT COALESCE(json_agg(json_build_object(
						'wallet', cm2.wallet_address,
						'display_name', COALESCE(p2.display_name, cm2.wallet_address),
						'avatar_url', p2.avatar_url
					) ORDER BY cm2.joined_at), '[]'::json)
					FROM conversation_members cm2
					LEFT JOIN profiles p2 ON p2.wallet_address = cm2.wallet_address
					WHERE cm2.conversation_id = c.id
				) AS member_profiles,
				(
					SELECT json_build_object(
						'wallet', cm3.wallet_address,
						'display_name', COALESCE(p3.display_name, cm3.wallet_address),
						'avatar_url', p3.avatar_url
					)
					FROM conversation_members cm3
					LEFT JOIN profiles p3 ON p3.wallet_address = cm3.wallet_address
					WHERE cm3.conversation_id = c.id
						AND cm3.wallet_address <> $1
					ORDER BY cm3.joined_at
					LIMIT 1
				) AS counterpart_profile,
				(SELECT COUNT(*) FROM conversation_members cm4 WHERE cm4.conversation_id = c.id) AS member_count
			     FROM conversations c
			 JOIN conversation_members cm ON cm.conversation_id = c.id
			 WHERE cm.wallet_address = $1
			 ORDER BY COALESCE((SELECT created_at FROM messages m WHERE m.conversation_id = c.id ORDER BY m.created_at DESC LIMIT 1), c.created_at) DESC
			 LIMIT 200`,
			 [wallet]
		);
		// normalize field names to expected client keys
		const rows = result.rows.map(r => {
			const memberWallets = parseJsonArray(r.member_wallets, [])
				.map(w => (w ?? '').toString())
				.filter(w => !!w);
			const memberProfilesRaw = parseJsonArray(r.member_profiles, []);
			const memberProfiles = memberProfilesRaw
				.map(profile => {
					const walletAddress = ((profile.wallet ?? profile.wallet_address ?? profile.walletAddress) ?? '').toString();
					if (!walletAddress) return null;
					const displayName = profile.display_name ?? profile.displayName ?? profile.name ?? walletAddress;
					const avatarUrl = normalizeAvatarUrl(profile.avatar_url ?? profile.avatarUrl, walletAddress) || null;
					return { wallet: walletAddress, displayName, avatarUrl };
				})
				.filter(Boolean);
			const counterpartRaw = parseJsonField(r.counterpart_profile);
			let counterpartProfile = null;
			if (counterpartRaw && Object.keys(counterpartRaw).length > 0) {
				const walletAddress = ((counterpartRaw.wallet ?? counterpartRaw.wallet_address ?? counterpartRaw.walletAddress) ?? '').toString();
				if (walletAddress) {
					counterpartProfile = {
						wallet: walletAddress,
						displayName: counterpartRaw.display_name ?? counterpartRaw.displayName ?? walletAddress,
						avatarUrl: normalizeAvatarUrl(counterpartRaw.avatar_url ?? counterpartRaw.avatarUrl, walletAddress) || null,
					};
				}
			}
			const memberCount = parseInt(r.member_count, 10) || memberProfiles.length || memberWallets.length;
			const otherProfile = counterpartProfile || memberProfiles.find(p => p.wallet !== wallet);
			const resolvedTitle = (r.title && r.title.trim().length > 0)
				? r.title
				: (r.is_group === true
					? 'Group chat'
					: (otherProfile?.displayName || memberWallets.find(w => w && w !== wallet) || 'Conversation'));
			const computedAvatar = normalizeAvatarUrl(r.avatar_url, r.id) || (r.is_group === true ? null : (otherProfile?.avatarUrl || null));
			return {
				id: r.id,
				title: resolvedTitle,
				raw_title: r.title,
				resolved_title: resolvedTitle,
				avatar: computedAvatar,
				avatar_url: computedAvatar,
				displayAvatar: computedAvatar,
				created_at: r.created_at,
				createdAt: r.created_at,
				updated_at: r.updated_at,
				updatedAt: r.updated_at,
				is_group: r.is_group === true,
				isGroup: r.is_group === true,
				created_by: r.created_by,
				createdBy: r.created_by,
				last_message: r.last_message,
				lastMessage: r.last_message,
				last_message_at: r.last_message_at,
				lastMessageAt: r.last_message_at,
				last_read_at: r.last_read_at,
				unreadCount: parseInt(r.unread_count, 10) || 0,
				unread_count: parseInt(r.unread_count, 10) || 0,
				member_wallets: memberWallets,
				memberWallets,
				member_profiles: memberProfiles,
				memberProfiles,
				member_count: memberCount,
				memberCount,
				counterpart_profile: counterpartProfile,
				counterpartProfile,
			};
		});
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
	const currentWallet = req.user?.walletAddress;

	try {
		// Get messages with reader counts
		const result = await query(
			`SELECT m.id,
					m.conversation_id,
					m.sender_wallet,
					m.message,
					m.created_at,
					COALESCE(m.data, '{}'::jsonb) AS data,
					m.reply_to_message_id,
					p.username AS sender_username,
					p.display_name AS sender_display_name,
					p.avatar_url AS sender_avatar,
					CASE WHEN reply.id IS NULL THEN NULL ELSE json_build_object(
						'messageId', reply.id,
						'senderWallet', reply.sender_wallet,
						'senderDisplayName', rp.display_name,
						'message', reply.message
					) END AS reply_preview,
					(
						SELECT COALESCE(json_agg(json_build_object(
							'emoji', emoji,
							'count', cnt,
							'reactors', reactors
						)), '[]'::json)
						FROM (
							SELECT emoji,
								COUNT(*) AS cnt,
								ARRAY_AGG(wallet_address) AS reactors
							FROM message_reactions mr
							WHERE mr.message_id = m.id
							GROUP BY emoji
						) agg
					) AS reactions,
					(
						SELECT COUNT(*) FROM conversation_members cm
						WHERE cm.conversation_id = m.conversation_id
						AND cm.last_read >= m.created_at
					) AS readers_count,
					CASE WHEN EXISTS (
						SELECT 1 FROM conversation_members cm
						WHERE cm.conversation_id = m.conversation_id
						AND cm.wallet_address = $4
						AND cm.last_read >= m.created_at
					) THEN true ELSE false END AS read_by_current
			 FROM messages m
			 LEFT JOIN profiles p ON p.wallet_address = m.sender_wallet
			 LEFT JOIN messages reply ON reply.id = m.reply_to_message_id
			 LEFT JOIN profiles rp ON rp.wallet_address = reply.sender_wallet
			 WHERE m.conversation_id = $1
			 ORDER BY m.created_at DESC
			 LIMIT $2 OFFSET $3`,
			[conversationId, limit, offset, currentWallet]
		);

		// Get readers list for each message
		const messagesWithReaders = await Promise.all(result.rows.map(async (r) => {
			let parsedData = null;
			if (r.data) {
				if (typeof r.data === 'string') {
					try { parsedData = JSON.parse(r.data); } catch (e) { parsedData = null; }
				} else {
					parsedData = r.data;
				}
			}
			let replyPreview = null;
			if (r.reply_preview) {
				if (typeof r.reply_preview === 'string') {
					try { replyPreview = JSON.parse(r.reply_preview); } catch (e) { replyPreview = null; }
				} else {
					replyPreview = r.reply_preview;
				}
			}
			let reactions = [];
			if (r.reactions) {
				if (typeof r.reactions === 'string') {
					try { reactions = JSON.parse(r.reactions) || []; } catch (e) { reactions = []; }
				} else if (Array.isArray(r.reactions)) {
					reactions = r.reactions;
				}
			}
			const readersRes = await query(
				`SELECT cm.wallet_address, cm.last_read AS read_at, p.display_name, p.avatar_url
				 FROM conversation_members cm
				 LEFT JOIN profiles p ON p.wallet_address = cm.wallet_address
				 WHERE cm.conversation_id = $1 AND cm.last_read >= $2`,
				[r.conversation_id, r.created_at]
			);

			return {
				id: r.id,
				conversation_id: r.conversation_id,
				conversationId: r.conversation_id,
				sender_wallet: r.sender_wallet,
				senderWallet: r.sender_wallet,
				message: r.message,
				created_at: r.created_at,
				createdAt: r.created_at,
				data: parsedData,
				reply_to_message_id: r.reply_to_message_id,
				replyToMessageId: r.reply_to_message_id,
				reply_preview: replyPreview,
				replyPreview: replyPreview,
				reactions: reactions,
				sender_username: r.sender_username,
				senderUsername: r.sender_username,
				sender_display_name: r.sender_display_name,
				senderDisplayName: r.sender_display_name,
				sender_avatar: normalizeAvatarUrl(r.sender_avatar, r.sender_wallet),
				senderAvatar: normalizeAvatarUrl(r.sender_avatar, r.sender_wallet),
				readers_count: parseInt(r.readers_count) || 0,
				readersCount: parseInt(r.readers_count) || 0,
				read_by_current: r.read_by_current === true,
				readByCurrent: r.read_by_current === true,
				readers: readersRes.rows.map(reader => ({
					wallet_address: reader.wallet_address,
					read_at: reader.read_at,
					displayName: reader.display_name,
					avatar_url: normalizeAvatarUrl(reader.avatar_url, reader.wallet_address)
				}))
			};
		}));

		res.json({ success: true, count: messagesWithReaders.length, data: messagesWithReaders });
	} catch (e) {
		logger.error('Messages GET failed:', e.message);
		res.json({ success: true, count: 0, data: [] });
	}
}));

// Post a message to a conversation
// Accept JSON and multipart/form-data (attachments)
router.post('/:conversationId/messages', verifyToken, upload.any(), asyncHandler(async (req, res) => {
	const { conversationId } = req.params;
	const sender = req.user?.walletAddress || 'unknown';

	let content = null;
	if (req.body) {
		content = req.body.content || req.body.message || req.body.body || req.body.text || req.body.messageBody || null;
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

	const bodyData = parseJsonField(req.body?.data);
	const metadataData = parseJsonField(req.body?.metadata);
	const dataPayload = { ...metadataData, ...bodyData };
	const attachments = [];
	let replyToMessageId = req.body?.replyTo || req.body?.reply_to || null;

	if (Array.isArray(req.files) && req.files.length > 0) {
		for (const file of req.files) {
			try {
				const uploaded = await storageService.uploadFile(file.buffer, file.originalname || `attachment_${Date.now()}`, {
					uploadFolder: `conversations/${conversationId}`,
					conversationId,
					senderWallet: sender,
					purpose: 'chat_message_attachment'
				});
				attachments.push(buildAttachmentPayload(file, uploaded));
			} catch (error) {
				logger.error('Failed to upload chat attachment', error?.message);
				return res.status(500).json({ success: false, error: 'Failed to upload attachment' });
			}
		}
	}

	if (attachments.length > 0) {
		dataPayload.attachments = attachments;
		if (attachments.length === 1) dataPayload.attachment = attachments[0];
		if (!content || content.trim().length === 0) {
			content = attachments.length === 1
				? `Attachment • ${attachments[0].filename || 'file'}`
				: `Shared ${attachments.length} attachments`;
		}
	}

	if (!replyToMessageId && dataPayload.replyTo) {
		const ref = dataPayload.replyTo;
		if (typeof ref === 'object') {
			replyToMessageId = ref.messageId || ref.message_id || ref.id || null;
		}
	}
	if (typeof replyToMessageId === 'object' && replyToMessageId !== null) {
		replyToMessageId = replyToMessageId.messageId || replyToMessageId.id || null;
	}
	if (replyToMessageId !== null && replyToMessageId !== undefined) {
		replyToMessageId = replyToMessageId.toString();
		if (replyToMessageId.trim().length === 0) replyToMessageId = null;
	}
	if (replyToMessageId) {
		try {
			const previewRes = await query(
				`SELECT m.id, m.message, m.sender_wallet, p.display_name
				 FROM messages m
				 LEFT JOIN profiles p ON p.wallet_address = m.sender_wallet
				 WHERE m.id = $1 AND m.conversation_id = $2
				 LIMIT 1`,
				[replyToMessageId, conversationId]
			);
			if (previewRes.rows.length === 0) {
				replyToMessageId = null;
				delete dataPayload.replyTo;
			} else {
				const row = previewRes.rows[0];
				dataPayload.replyTo = {
					messageId: row.id,
					senderWallet: row.sender_wallet,
					senderDisplayName: row.display_name || row.sender_wallet,
					message: row.message,
				};
			}
		} catch (e) {
			replyToMessageId = null;
			delete dataPayload.replyTo;
		}
	}

	const hasText = typeof content === 'string' && content.trim().length > 0;
	if (!hasText && attachments.length === 0) {
		try {
			logger.info('Messages POST received empty payload (no text or attachments). Body snapshot: ' + JSON.stringify(req.body || {}));
		} catch (e) {
			logger.info('Messages POST received empty payload. Body snapshot unavailable');
		}
		return res.status(400).json({ success: false, error: 'Message content or attachment is required' });
	}

	try {
		const insert = await query(
			`INSERT INTO messages (conversation_id, sender_wallet, message, data, reply_to_message_id)
			 VALUES ($1, $2, $3, $4::jsonb, $5) RETURNING id`,
			[conversationId, sender, content, JSON.stringify(dataPayload || {}), replyToMessageId]
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
					COALESCE(m.data, '{}'::jsonb) AS data,
					m.reply_to_message_id,
					p.username AS senderUsername,
					p.username AS sender_username,
					p.display_name AS senderDisplayName,
					p.display_name AS sender_display_name,
					p.avatar_url AS senderAvatar,
					p.avatar_url AS sender_avatar,
					CASE WHEN reply.id IS NULL THEN NULL ELSE json_build_object(
						'messageId', reply.id,
						'senderWallet', reply.sender_wallet,
						'senderDisplayName', rp.display_name,
						'message', reply.message
					) END AS reply_preview,
					(
						SELECT COALESCE(json_agg(json_build_object(
							'emoji', emoji,
							'count', cnt,
							'reactors', reactors
						)), '[]'::json)
						FROM (
							SELECT emoji,
								COUNT(*) AS cnt,
								ARRAY_AGG(wallet_address) AS reactors
							FROM message_reactions mr
							WHERE mr.message_id = m.id
							GROUP BY emoji
						) agg
					) AS reactions
			 FROM messages m
			 LEFT JOIN profiles p ON p.wallet_address = m.sender_wallet
			 LEFT JOIN messages reply ON reply.id = m.reply_to_message_id
			 LEFT JOIN profiles rp ON rp.wallet_address = reply.sender_wallet
			 WHERE m.id = $1`,
			[messageId]
		);

		const r = result.rows[0] || {};
		const normalizedData = typeof r.data === 'string' ? parseJsonField(r.data) : (r.data || {});
		let replyPreview = null;
		if (r.reply_preview) {
			if (typeof r.reply_preview === 'string') {
				try { replyPreview = JSON.parse(r.reply_preview); } catch (e) { replyPreview = null; }
			} else {
				replyPreview = r.reply_preview;
			}
		}
		let reactions = [];
		if (r.reactions) {
			if (typeof r.reactions === 'string') {
				try { reactions = JSON.parse(r.reactions) || []; } catch (e) { reactions = []; }
			} else if (Array.isArray(r.reactions)) {
				reactions = r.reactions;
			}
		}
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
			data: normalizedData,
			reply_to_message_id: r.reply_to_message_id,
			replyToMessageId: r.reply_to_message_id,
			reply_preview: replyPreview,
			replyPreview: replyPreview,
			reactions: reactions,
			senderUsername: r.senderUsername || r.sender_username || null,
			sender_username: r.sender_username || r.senderUsername || null,
			senderDisplayName: r.senderDisplayName || r.sender_display_name || null,
			sender_display_name: r.sender_display_name || r.senderDisplayName || null,
			senderAvatar: normalizeAvatarUrl(r.senderAvatar || r.sender_avatar, r.sender_wallet) || null,
			sender_avatar: normalizeAvatarUrl(r.senderAvatar || r.sender_avatar, r.sender_wallet) || null
		};

		const io = req.app.get('io');
		if (io) io.to(`conversation:${conversationId}`).emit('message:received', message);

		res.status(201).json({ success: true, data: message });
	} catch (e) {
		logger.debug('Messages POST fallback - DB insert failed, returning stub');
		const timestamp = new Date().toISOString();
		const stubData = dataPayload || {};
		const stub = {
			id: `msg_${Date.now()}`,
			conversation_id: conversationId,
			sender_wallet: sender,
			content,
			message: content,
			text: content,
			body: content,
			created_at: timestamp,
			createdAt: timestamp,
			data: stubData,
			reply_to_message_id: null,
			replyToMessageId: null,
			reply_preview: null,
			replyPreview: null,
			reactions: [],
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
			if (io) {
				const payload = { wallet, conversationId, last_read_at: new Date().toISOString() };
				logger.info(`Emitting conversation:member:read to conversation:${conversationId} payload=${JSON.stringify(payload)}`);
				io.to(`conversation:${conversationId}`).emit('conversation:member:read', payload);
			}

			// Also emit to each member's personal user room (lowercased) so clients
			// subscribed to user rooms receive the update even if they missed
			// the conversation room (race conditions on subscribe). This does
			// not change stored wallet casing.
			try {
				if (io) {
					const membersRes = await query('SELECT wallet_address AS wallet FROM conversation_members WHERE conversation_id = $1', [conversationId]);
					for (const m of membersRes.rows) {
						try {
							const room = `user:${(m.wallet || '').toString()}`;
							const payload = { wallet, conversationId, last_read_at: new Date().toISOString() };
							logger.info(`Emitting conversation:member:read to ${room} payload=${JSON.stringify(payload)}`);
							io.to(room).emit('conversation:member:read', payload);
						} catch (e) {}
					}
				}
			} catch (e) { logger.debug('Failed to emit conversation member read to user rooms', e?.message); }
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
			if (io) {
				// Standardized payload with both snake_case and camelCase fields
				const payload = {
					message_id: messageId,
					messageId: messageId,
					conversation_id: conversationId,
					conversationId: conversationId,
					reader: wallet,
					wallet: wallet,
					read_at: messageCreatedAt,
					last_read_at: messageCreatedAt
				};
				logger.info(`Emitting message:read to conversation:${conversationId}`);
				io.to(`conversation:${conversationId}`).emit('message:read', payload);

				// Also emit to each member's user room
				const membersRes = await query('SELECT wallet_address FROM conversation_members WHERE conversation_id = $1', [conversationId]);
				for (const m of membersRes.rows) {
					const room = `user:${m.wallet_address}`;
					io.to(room).emit('message:read', payload);
				}
			}
		} catch (e) {
			logger.debug('Failed to emit message read event', e?.message);
		}

		res.json({ success: true, message: 'Message marked as read', messageId, last_read_at: messageCreatedAt });
	} catch (e) {
		logger.debug('Mark message read fallback - DB update failed for', conversationId, messageId, e?.message);
		res.status(500).json({ success: false, error: 'Failed to mark message read' });
	}
}));

// Add or update a reaction on a message
router.post('/:conversationId/messages/:messageId/reactions', verifyToken, asyncHandler(async (req, res) => {
	const { conversationId, messageId } = req.params;
	const wallet = req.user?.walletAddress || null;
	const emoji = (req.body?.emoji || '').toString().trim();
	if (!wallet) return res.status(400).json({ success: false, error: 'Invalid user' });
	if (!emoji) return res.status(400).json({ success: false, error: 'Emoji is required' });

	if (!(await ensureConversationMember(conversationId, wallet))) {
		return res.status(403).json({ success: false, error: 'Not part of this conversation' });
	}

	const messageExists = await query('SELECT 1 FROM messages WHERE id = $1 AND conversation_id = $2 LIMIT 1', [messageId, conversationId]);
	if (!messageExists.rows || messageExists.rows.length === 0) {
		return res.status(404).json({ success: false, error: 'Message not found' });
	}

	await query(
		`INSERT INTO message_reactions (message_id, wallet_address, emoji)
		 VALUES ($1, $2, $3)
		 ON CONFLICT (message_id, wallet_address, emoji) DO NOTHING`,
		[messageId, wallet, emoji]
	);

	const reactions = await fetchReactionSummary(messageId);
	const payload = {
		conversationId,
		conversation_id: conversationId,
		messageId,
		message_id: messageId,
		emoji,
		wallet,
		action: 'added',
		reactions,
	};

	const io = req.app.get('io');
	if (io) {
		io.to(`conversation:${conversationId}`).emit('message:reaction', payload);
		try {
			const membersRes = await query('SELECT wallet_address FROM conversation_members WHERE conversation_id = $1', [conversationId]);
			for (const member of membersRes.rows) {
				const room = `user:${(member.wallet_address || '').toString()}`;
				io.to(room).emit('message:reaction', payload);
			}
		} catch (e) {
			logger.debug('Failed to emit reaction to user rooms', e?.message);
		}
	}

	return res.json({ success: true, data: payload });
}));

// Remove a reaction from a message
router.delete('/:conversationId/messages/:messageId/reactions', verifyToken, asyncHandler(async (req, res) => {
	const { conversationId, messageId } = req.params;
	const wallet = req.user?.walletAddress || null;
	const emoji = (req.body?.emoji || req.query?.emoji || '').toString().trim();
	if (!wallet) return res.status(400).json({ success: false, error: 'Invalid user' });
	if (!emoji) return res.status(400).json({ success: false, error: 'Emoji is required' });

	if (!(await ensureConversationMember(conversationId, wallet))) {
		return res.status(403).json({ success: false, error: 'Not part of this conversation' });
	}

	await query(
		`DELETE FROM message_reactions WHERE message_id = $1 AND wallet_address = $2 AND emoji = $3`,
		[messageId, wallet, emoji]
	);

	const reactions = await fetchReactionSummary(messageId);
	const payload = {
		conversationId,
		conversation_id: conversationId,
		messageId,
		message_id: messageId,
		emoji,
		wallet,
		action: 'removed',
		reactions,
	};

	const io = req.app.get('io');
	if (io) {
		io.to(`conversation:${conversationId}`).emit('message:reaction', payload);
		try {
			const membersRes = await query('SELECT wallet_address FROM conversation_members WHERE conversation_id = $1', [conversationId]);
			for (const member of membersRes.rows) {
				const room = `user:${(member.wallet_address || '').toString()}`;
				io.to(room).emit('message:reaction', payload);
			}
		} catch (e) {
			logger.debug('Failed to emit reaction removal to user rooms', e?.message);
		}
	}

	return res.json({ success: true, data: payload });
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

				// Normalize avatar URL per member before returning
				rows = rows.map(r => ({
					wallet_address: r.wallet_address,
					wallet: r.wallet,
					walletAddress: r.walletAddress,
					joined_at: r.joined_at,
					last_read_at: r.last_read_at,
					displayName: r.displayName,
					username: r.username,
					avatar_url: normalizeAvatarUrl(r.avatar_url, r.wallet_address) || null,
					avatar: normalizeAvatarUrl(r.avatar_url, r.wallet_address) || null,
				}));

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
							try { io2.to(`user:${(m.wallet || '').toString()}`).emit('chat:members-updated', { conversationId, members: members.rows }); } catch (e) {}
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
	const { title, members, isGroup } = req.body || {};
	const creator = req.user?.walletAddress || null;

	if (!creator) return res.status(400).json({ success: false, error: 'Invalid user' });

	// members should be an array of wallet addresses (strings)
	const membersArr = Array.isArray(members) ? members : [];
	const isGroupFlag = typeof isGroup === 'string'
		? isGroup.toLowerCase() === 'true'
		: isGroup === true;

	try {
		// create conversation
		const convInsert = await query(
			`INSERT INTO conversations (title, created_by, is_group) VALUES ($1, $2, $3) RETURNING id, title, created_at, is_group`,
			[title || null, creator, isGroupFlag]
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
						const conversationPayload = { ...conv, members: uniqueMembers, is_group: conv.is_group === true, isGroup: conv.is_group === true };
						for (const m of uniqueMembers) {
							try { io.to(`user:${(m || '').toString()}`).emit('chat:new-conversation', conversationPayload); } catch (e) { logger.debug('Failed to emit new conversation to user', m, e?.message); }
						}
					}
				} catch (e) { logger.debug('chat:new-conversation emit failed', e?.message); }

				// return created conversation with minimal members list
				res.status(201).json({ success: true, data: { ...conv, is_group: conv.is_group === true, isGroup: conv.is_group === true, members: uniqueMembers } });
	} catch (e) {
		logger.debug('Create conversation fallback - DB insert failed', e?.message);
		const stubId = `conv_${Date.now()}`;
		const uniqueMembers = Array.from(new Set([creator, ...membersArr]));
		res.status(201).json({ success: true, data: { id: stubId, title: title || null, created_at: new Date().toISOString(), is_group: isGroupFlag, isGroup: isGroupFlag, members: uniqueMembers } });
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
				const normalized = normalizeAvatarUrl(avatarUrl, conversationId);
				const payload = { conversationId, avatar: normalized, avatar_url: normalized, displayAvatar: normalized };
				io.to(`conversation:${conversationId}`).emit('chat:conversation-updated', payload);
				// Also notify user rooms by looking up members
				try {
					const membersRes = await query('SELECT wallet_address AS wallet FROM conversation_members WHERE conversation_id = $1', [conversationId]);
					for (const m of membersRes.rows) {
						try { io.to(`user:${(m.wallet || '').toString()}`).emit('chat:conversation-updated', payload); } catch (e) {}
					}
				} catch (e) { logger.debug('Failed to fetch conversation members for avatar emit', e?.message); }
			}
		} catch (e) { logger.debug('Failed to emit conversation avatar update', e?.message); }

		return res.json({ success: true, data: { avatar: normalized, avatar_url: normalized } });
	} catch (err) {
		logger.debug('Conversation avatar upload failed', err?.message || err);
		return res.status(500).json({ success: false, error: 'Failed to save avatar' });
	}
}));

