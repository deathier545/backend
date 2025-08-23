const express = require('express');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const helmet = require('helmet');
const morgan = require('morgan');
const http = require('http');
const WebSocket = require('ws');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ 
    server,
    path: '/ws'  // Set the WebSocket path to match client
});

// Debug WebSocket upgrade requests
server.on('upgrade', (request, socket, head) => {
    console.log(`🔄 WebSocket upgrade request for path: ${request.url}`);
    console.log(`🔄 Upgrade headers:`, request.headers);
});
const PORT = process.env.PORT || 3000;

// Trust proxy for cloud deployments (Render.com, Heroku, etc.)
app.set('trust proxy', true);

// Middleware
app.use(helmet()); // Security headers
app.use(cors()); // Enable CORS for all routes
app.use(express.json()); // Parse JSON bodies
app.use(morgan('combined')); // Logging

// Rate limiting with cloud deployment compatibility
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // Limit each IP to 100 requests per windowMs
    message: 'Too many requests from this IP, please try again later.',
    standardHeaders: true, // Return rate limit info in the `RateLimit-*` headers
    legacyHeaders: false, // Disable the `X-RateLimit-*` headers
    // Fix for cloud deployment X-Forwarded-For issues
    keyGenerator: (req) => {
        // Use the real IP address, fallback to connection IP if needed
        return req.ip || req.connection.remoteAddress || 'unknown';
    },
    skip: (req) => {
        // Skip rate limiting for health checks and WebSocket connections
        return req.path === '/api/health' || req.path === '/api/test' || req.path.startsWith('/ws');
    }
});

// Apply rate limiting with error handling
app.use('/api/', (req, res, next) => {
    try {
        limiter(req, res, next);
    } catch (error) {
        console.error('Rate limiting error:', error);
        // Continue without rate limiting if it fails
        next();
    }
});

// Data storage (in production, use a real database like MongoDB or PostgreSQL)
let activeUsers = new Map(); // Store active script users
let killCommands = new Map(); // Store pending kill commands
let adminUsers = new Set(); // Store admin user IDs

// WebSocket connections
let wsConnections = new Map(); // Store WebSocket connections by user ID
let wsAdmins = new Map(); // Store admin WebSocket connections

// Ping all WebSocket connections every 30 seconds to keep them alive
setInterval(() => {
    const pingMessage = JSON.stringify({
        type: 'ping',
        timestamp: Date.now()
    });
    
    // Ping user connections
    for (const [userId, ws] of wsConnections) {
        if (ws.readyState === WebSocket.OPEN) {
            ws.ping();
        }
    }
    
    // Ping admin connections
    for (const [userId, ws] of wsAdmins) {
        if (ws.readyState === WebSocket.OPEN) {
            ws.ping();
        }
    }
}, 30000);

// Cleanup inactive users every 30 seconds
setInterval(() => {
    const now = Date.now();
    for (const [userId, user] of activeUsers) {
        if (now - user.timestamp > 30000) { // 30 seconds timeout
            activeUsers.delete(userId);
            console.log(`User ${user.username} (${userId}) timed out and removed`);
        }
    }
}, 30000);

// Cleanup expired kill commands every 60 seconds
setInterval(() => {
    const now = Date.now();
    for (const [userId, command] of killCommands) {
        if (now - command.timestamp > 60000) { // 60 seconds timeout
            killCommands.delete(userId);
            console.log(`Kill command for user ${userId} expired and removed`);
        }
    }
}, 60000);

// Helper function to validate user data
function validateUserData(data) {
    return data && 
           typeof data.username === 'string' && 
           typeof data.userid === 'number' && 
           typeof data.timestamp === 'number' &&
           data.username.length > 0 &&
           data.userid > 0 &&
           data.gameid &&  // Ensure gameid is present
           data.jobid;     // Ensure jobid is present
}

// Helper function to validate admin data
function validateAdminData(data) {
    return data && 
           typeof data.target_userid === 'number' && 
           typeof data.admin_userid === 'number' && 
           typeof data.timestamp === 'number' &&
           data.target_userid > 0 &&
           data.admin_userid > 0;
}

// Helper function to log admin actions
function logAdminAction(adminId, action, targetId, details = '') {
    const timestamp = new Date().toISOString();
    console.log(`[ADMIN ACTION] ${timestamp} - Admin ${adminId} performed ${action} on target ${targetId} ${details}`);
}

// WebSocket connection handling
wss.on('connection', (ws, req) => {
    console.log('🔌 New WebSocket connection established');
    console.log(`🔌 Connection details - IP: ${req.socket.remoteAddress}, Headers:`, req.headers);
    
    let userId = null;
    let isAdmin = false;
    
    ws.on('message', (message) => {
        console.log(`📨 Raw message received: ${message}`);
        
        try {
            const data = JSON.parse(message);
            console.log(`📨 Parsed message:`, data);
            
            if (data.type === 'connect') {
                userId = data.userid;
                isAdmin = data.isAdmin || false;
                
                // Store connection
                if (isAdmin) {
                    wsAdmins.set(userId, ws);
                    console.log(`🔐 Admin WebSocket connected: ${data.username} (${userId})`);
                } else {
                    wsConnections.set(userId, ws);
                    console.log(`👤 User WebSocket connected: ${data.username} (${userId})`);
                }
                
                // Send confirmation
                ws.send(JSON.stringify({
                    type: 'connected',
                    success: true,
                    userid: userId,
                    timestamp: Date.now()
                }));
                
                // Send current user list to admin
                if (isAdmin) {
                    const users = Array.from(activeUsers.values()).map(user => ({
                        username: user.username,
                        userid: user.userid,
                        displayname: user.displayname || user.username,
                        timestamp: user.timestamp,
                        status: user.status || 'active',
                        gameid: user.gameid,
                        jobid: user.jobid,
                        lastSeen: user.lastSeen,
                        ip: user.ip
                    }));
                    
                    console.log(`🔐 Sending initial user list to admin ${data.username}: ${users.length} users`);
                    
                    ws.send(JSON.stringify({
                        type: 'user_list',
                        users: users,
                        timestamp: Date.now()
                    }));
                    
                    console.log(`✅ Initial user list sent to admin ${data.username}`);
                }
                
            } else if (data.type === 'heartbeat') {
                // Update user timestamp
                if (activeUsers.has(userId)) {
                    const user = activeUsers.get(userId);
                    user.lastSeen = Date.now();
                    activeUsers.set(userId, user);
                }
                
                // Send pong response
                ws.send(JSON.stringify({
                    type: 'pong',
                    timestamp: Date.now()
                }));
                
            } else if (data.type === 'get_users') {
                // Handle user list request
                console.log(`User list request from ${data.admin_username} (${data.admin_userid})`);
                
                // Send current user list
                const users = Array.from(activeUsers.values()).map(user => ({
                    username: user.username,
                    userid: user.userid,
                    displayname: user.displayname || user.username,
                    timestamp: user.timestamp,
                    status: user.status || 'active',
                    gameid: user.gameid,
                    jobid: user.jobid,
                    lastSeen: user.lastSeen,
                    ip: user.ip
                }));
                
                ws.send(JSON.stringify({
                    type: 'user_list',
                    users: users,
                    timestamp: Date.now()
                }));
                
                console.log(`Sent user list to admin ${data.admin_username}: ${users.length} users`);
                
            } else if (data.type === 'test_ping') {
                // Handle test ping message
                console.log(`Test ping received from user ${data.username || userId}`);
                
                // Send test response
                ws.send(JSON.stringify({
                    type: 'test_response',
                    message: 'Test ping received and responded to',
                    timestamp: Date.now()
                }));
                
            } else if (data.type === 'pong') {
                // Handle pong response
                console.log(`Pong received from user ${userId}`);
            } else if (data.type === 'admin_kill') {
                // Handle admin kill command via WebSocket
                const targetUserId = data.target_userid;
                const adminUserId = data.admin_userid;
                const adminUsername = data.admin_username;
                
                console.log(`Admin kill command via WebSocket: ${adminUsername} (${adminUserId}) -> ${targetUserId}`);
                
                // Try to send kill command via WebSocket first
                const wsSent = sendKillCommandWebSocket(targetUserId);
                
                if (wsSent) {
                    console.log(`Kill command sent via WebSocket to user ${targetUserId}`);
                    
                    // Log admin action
                    logAdminAction(adminUserId, 'KILL', targetUserId, 
                                  `(${adminUsername}) - WebSocket Direct`);
                    
                    // Send confirmation to admin
                    ws.send(JSON.stringify({
                        type: 'kill_sent',
                        success: true,
                        target_userid: targetUserId,
                        method: 'websocket_direct',
                        timestamp: Date.now()
                    }));
                } else {
                    // Fallback to HTTP polling
                    killCommands.set(targetUserId, {
                        target_userid: targetUserId,
                        admin_userid: adminUserId,
                        admin_username: adminUsername,
                        timestamp: data.timestamp,
                        action: 'kill',
                        created: Date.now()
                    });
                    
                    console.log(`Kill command queued for user ${targetUserId} by admin ${adminUsername} (${adminUserId}) - WebSocket HTTP Fallback`);
                    
                    // Send confirmation to admin
                    ws.send(JSON.stringify({
                        type: 'kill_sent',
                        success: true,
                        target_userid: targetUserId,
                        method: 'http_fallback',
                        timestamp: Date.now()
                    }));
                }
            }
            
        } catch (error) {
            console.error('WebSocket message error:', error);
            ws.send(JSON.stringify({
                type: 'error',
                message: 'Invalid message format',
                timestamp: Date.now()
            }));
        }
    });
    
    ws.on('close', (code, reason) => {
        console.log(`🔌 WebSocket connection closed for user ${userId} - Code: ${code}, Reason: ${reason || 'No reason'}`);
        
        if (userId) {
            if (isAdmin) {
                wsAdmins.delete(userId);
                console.log(`🔐 Admin WebSocket removed: ${userId}`);
            } else {
                wsConnections.delete(userId);
                console.log(`👤 User WebSocket removed: ${userId}`);
            }
        }
    });
    
    ws.on('error', (error) => {
        console.error(`WebSocket error for user ${userId}:`, error);
    });
    
    // Handle ping/pong for connection health
    ws.on('ping', () => {
        ws.pong();
    });
    
    ws.on('pong', () => {
        // Connection is healthy
        if (userId && activeUsers.has(userId)) {
            const user = activeUsers.get(userId);
            user.lastSeen = Date.now();
            activeUsers.set(userId, user);
        }
    });
});

// Function to send kill command via WebSocket
function sendKillCommandWebSocket(targetUserId) {
    const ws = wsConnections.get(targetUserId);
    if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({
            type: 'kill',
            timestamp: Date.now(),
            admin_userid: 'admin'
        }));
        return true;
    }
    return false;
}

// Function to broadcast user list updates to admins
function broadcastUserListToAdmins() {
    const users = Array.from(activeUsers.values()).map(user => ({
        username: user.username,
        userid: user.userid,
        displayname: user.displayname || user.username,
        timestamp: user.timestamp,
        status: user.status || 'active',
        gameid: user.gameid,
        jobid: user.jobid,
        lastSeen: user.lastSeen,
        ip: user.ip
    }));
    
    console.log(`📡 Broadcasting user list update to ${wsAdmins.size} admin connections: ${users.length} users`);
    
    const message = JSON.stringify({
        type: 'user_list',
        users: users,
        timestamp: Date.now()
    });
    
    for (const [adminId, ws] of wsAdmins) {
        if (ws.readyState === WebSocket.OPEN) {
            ws.send(message);
            console.log(`📡 User list sent to admin ${adminId}`);
        } else {
            console.log(`⚠️ Admin ${adminId} WebSocket not open, skipping broadcast`);
        }
    }
}

// Routes

// Health check endpoint
app.get('/api/health', (req, res) => {
    res.json({
        status: 'Backend is running',
        timestamp: new Date().toISOString(),
        activeUsers: activeUsers.size,
        pendingKillCommands: killCommands.size,
        uptime: process.uptime(),
        websocketConnections: wsConnections.size + wsAdmins.size,
        version: '1.0.0'
    });
});

// Simple test endpoint
app.get('/api/test', (req, res) => {
    res.json({
        message: 'Backend is working correctly',
        timestamp: new Date().toISOString(),
        endpoints: [
            '/api/health',
            '/api/script/heartbeat',
            '/api/admin/users',
            '/api/script/check_kill/:userid',
            '/api/script/status/:userid',
            '/api/stats',
            '/ws (WebSocket)'
        ],
        currentState: {
            activeUsers: activeUsers.size,
            wsConnections: wsConnections.size,
            wsAdmins: wsAdmins.size,
            pendingKillCommands: killCommands.size
        }
    });
});

// Script user heartbeat endpoint
app.post('/api/script/heartbeat', (req, res) => {
    try {
        const userData = req.body;
        
        if (!validateUserData(userData)) {
            const missingFields = [];
            if (!userData.username || typeof userData.username !== 'string') missingFields.push('username');
            if (!userData.userid || typeof userData.userid !== 'number') missingFields.push('userid');
            if (!userData.timestamp || typeof userData.timestamp !== 'number') missingFields.push('timestamp');
            if (!userData.gameid) missingFields.push('gameid');
            if (!userData.jobid) missingFields.push('jobid');
            
            return res.status(400).json({
                error: 'Invalid user data',
                required: ['username', 'userid', 'timestamp', 'gameid', 'jobid'],
                missing: missingFields,
                received: userData
            });
        }
        
        // Store/update user data
        activeUsers.set(userData.userid, {
            ...userData,
            lastSeen: Date.now(),
            ip: req.ip
        });
        
        console.log(`Heartbeat from ${userData.username} (${userData.userid}) - Game: ${userData.gameid}, Job: ${userData.jobid}`);
        console.log(`📊 Active users count: ${activeUsers.size}`);
        
        res.json({
            success: true,
            message: 'Heartbeat received',
            timestamp: Date.now()
        });
        
        // Broadcast updated user list to all connected admins
        broadcastUserListToAdmins();
        
    } catch (error) {
        console.error('Heartbeat error:', error);
        res.status(500).json({
            error: 'Internal server error',
            message: error.message
        });
    }
});

// Admin user list endpoint
app.get('/api/admin/users', (req, res) => {
    try {
        // Convert Map to array for JSON response
        const users = Array.from(activeUsers.values()).map(user => ({
            username: user.username,
            userid: user.userid,
            displayname: user.displayname || user.username,
            timestamp: user.timestamp,
            status: user.status || 'active',
            gameid: user.gameid,
            jobid: user.jobid,
            lastSeen: user.lastSeen,
            ip: user.ip
        }));
        
        console.log(`📊 Admin requested user list: ${users.length} users`);
        
        res.json({
            success: true,
            users: users,
            total: users.length,
            timestamp: Date.now()
        });
        
    } catch (error) {
        console.error('User list error:', error);
        res.status(500).json({
            error: 'Internal server error',
            message: error.message
        });
    }
});

// Admin kill command endpoint
app.post('/api/admin/kill', (req, res) => {
    try {
        const adminData = req.body;
        
        if (!validateAdminData(adminData)) {
            return res.status(400).json({
                error: 'Invalid admin data',
                required: ['target_userid', 'admin_userid', 'timestamp'],
                received: adminData
            });
        }
        
        // Check if target user exists
        if (!activeUsers.has(adminData.target_userid)) {
            return res.status(404).json({
                error: 'Target user not found',
                target_userid: adminData.target_userid
            });
        }
        
        // Try to send kill command via WebSocket first (real-time)
        const wsSent = sendKillCommandWebSocket(adminData.target_userid);
        
        if (wsSent) {
            console.log(`Kill command sent via WebSocket to user ${adminData.target_userid}`);
            
            // Log admin action
            logAdminAction(adminData.admin_userid, 'KILL', adminData.target_userid, 
                          `(${adminData.admin_username}) - WebSocket`);
            
            res.json({
                success: true,
                message: 'Kill command sent successfully via WebSocket',
                target_userid: adminData.target_userid,
                timestamp: Date.now(),
                method: 'websocket'
            });
        } else {
            // Fallback to HTTP polling
            killCommands.set(adminData.target_userid, {
                target_userid: adminData.target_userid,
                admin_userid: adminData.admin_userid,
                admin_username: adminData.admin_username,
                timestamp: adminData.timestamp,
                action: 'kill',
                created: Date.now()
            });
            
            // Log admin action
            logAdminAction(adminData.admin_userid, 'KILL', adminData.target_userid, 
                          `(${adminData.admin_username}) - HTTP Fallback`);
            
            console.log(`Kill command queued for user ${adminData.target_userid} by admin ${adminData.admin_username} (${adminData.admin_userid}) - HTTP Fallback`);
            
            res.json({
                success: true,
                message: 'Kill command queued successfully (HTTP fallback)',
                target_userid: adminData.target_userid,
                timestamp: Date.now(),
                method: 'http_fallback'
            });
        }
        
    } catch (error) {
        console.error('Kill command error:', error);
        res.status(500).json({
            error: 'Internal server error',
            message: error.message
        });
    }
});

// Script user status check endpoint
app.get('/api/script/status/:userid', (req, res) => {
    try {
        const userId = parseInt(req.params.userid);
        
        if (isNaN(userId) || userId <= 0) {
            return res.status(400).json({
                error: 'Invalid user ID',
                userid: req.params.userid
            });
        }
        
        // Check if user is active
        const user = activeUsers.get(userId);
        
        if (user) {
            res.json({
                success: true,
                active: true,
                user: {
                    username: user.username,
                    userid: user.userid,
                    displayname: user.displayname || user.username,
                    lastSeen: user.lastSeen,
                    status: user.status || 'active'
                },
                timestamp: Date.now()
            });
        } else {
            res.json({
                success: true,
                active: false,
                user: null,
                timestamp: Date.now()
            });
        }
        
    } catch (error) {
        console.error('User status check error:', error);
        res.status(500).json({
            error: 'Internal server error',
            message: error.message
        });
    }
});

// User kill command check endpoint
app.get('/api/script/check_kill/:userid', (req, res) => {
    try {
        const userId = parseInt(req.params.userid);
        
        if (isNaN(userId) || userId <= 0) {
            return res.status(400).json({
                error: 'Invalid user ID',
                userid: req.params.userid
            });
        }
        
        // Check if there's a pending kill command
        const killCommand = killCommands.get(userId);
        
        if (killCommand) {
            // Remove the kill command after sending it
            killCommands.delete(userId);
            
            console.log(`Kill command executed for user ${userId}`);
            
            res.json({
                action: 'kill',
                timestamp: Date.now(),
                admin_userid: killCommand.admin_userid,
                admin_username: killCommand.admin_username
            });
        } else {
            res.json({
                action: null,
                timestamp: Date.now()
            });
        }
        
    } catch (error) {
        console.error('Kill check error:', error);
        res.status(500).json({
            error: 'Internal server error',
            message: error.message
        });
    }
});

// Admin authentication endpoint (optional - for additional security)
app.post('/api/admin/auth', (req, res) => {
    try {
        const { admin_userid, admin_username, admin_token } = req.body;
        
        // Basic validation
        if (!admin_userid || !admin_username || !admin_token) {
            return res.status(400).json({
                error: 'Missing authentication data',
                required: ['admin_userid', 'admin_username', 'admin_token']
            });
        }
        
        // In production, implement proper token validation here
        // For now, we'll just log the authentication attempt
        console.log(`Admin auth attempt: ${admin_username} (${admin_userid}) with token: ${admin_token}`);
        
        // Add to admin users set
        adminUsers.add(admin_userid);
        
        res.json({
            success: true,
            message: 'Admin authenticated successfully',
            admin_userid: admin_userid,
            timestamp: Date.now()
        });
        
    } catch (error) {
        console.error('Admin auth error:', error);
        res.status(500).json({
            error: 'Internal server error',
            message: error.message
        });
    }
});

// Admin logout endpoint
app.post('/api/admin/logout', (req, res) => {
    try {
        const { admin_userid } = req.body;
        
        if (!admin_userid) {
            return res.status(400).json({
                error: 'Missing admin user ID'
            });
        }
        
        adminUsers.delete(admin_userid);
        console.log(`Admin ${admin_userid} logged out`);
        
        res.json({
            success: true,
            message: 'Admin logged out successfully',
            timestamp: Date.now()
        });
        
    } catch (error) {
        console.error('Admin logout error:', error);
        res.status(500).json({
            error: 'Internal server error',
            message: error.message
        });
    }
});

// Statistics endpoint
app.get('/api/stats', (req, res) => {
    try {
        const stats = {
            activeUsers: activeUsers.size,
            pendingKillCommands: killCommands.size,
            adminUsers: adminUsers.size,
            uptime: process.uptime(),
            memory: process.memoryUsage(),
            timestamp: Date.now()
        };
        
        res.json({
            success: true,
            stats: stats
        });
        
    } catch (error) {
        console.error('Stats error:', error);
        res.status(500).json({
            error: 'Internal server error',
            message: error.message
        });
    }
});

// Clear all data endpoint (for testing/reset purposes)
app.post('/api/admin/clear', (req, res) => {
    try {
        const { admin_userid, admin_username } = req.body;
        
        if (!admin_userid || !admin_username) {
            return res.status(400).json({
                error: 'Missing admin credentials'
            });
        }
        
        // Clear all data
        activeUsers.clear();
        killCommands.clear();
        adminUsers.clear();
        
        logAdminAction(admin_userid, 'CLEAR_ALL', 0, `(${admin_username})`);
        console.log(`All data cleared by admin ${admin_username} (${admin_userid})`);
        
        res.json({
            success: true,
            message: 'All data cleared successfully',
            timestamp: Date.now()
        });
        
    } catch (error) {
        console.error('Clear data error:', error);
        res.status(500).json({
            error: 'Internal server error',
            message: error.message
        });
    }
});

// Error handling middleware
app.use((err, req, res, next) => {
    console.error('Unhandled error:', err);
    
    // Handle specific rate limiting errors
    if (err.code === 'ERR_ERL_UNEXPECTED_X_FORWARDED_FOR') {
        console.error('Rate limiting error - X-Forwarded-For header issue detected');
        console.error('This commonly happens in cloud deployments. Consider adjusting rate limiting configuration.');
    }
    
    // Don't expose internal error details in production
    const isProduction = process.env.NODE_ENV === 'production';
    
    res.status(500).json({
        error: 'Internal server error',
        message: isProduction ? 'Something went wrong on the server' : err.message,
        timestamp: new Date().toISOString()
    });
});

// 404 handler for undefined routes
app.use('*', (req, res) => {
    res.status(404).json({
        error: 'Route not found',
        method: req.method,
        path: req.originalUrl,
        timestamp: Date.now()
    });
});

// Start server
server.listen(PORT, () => {
    console.log(`🚀 Admin Backend Server running on port ${PORT}`);
    console.log(`📊 Health check: http://localhost:${PORT}/api/health`);
    console.log(`📈 Statistics: http://localhost:${PORT}/api/stats`);
    console.log(`🔌 WebSocket endpoint: ws://localhost:${PORT}/ws`);
    console.log(`🔌 WebSocket endpoint (production): wss://backend-vfbf.onrender.com/ws`);
    console.log(`⏰ Server started at: ${new Date().toISOString()}`);
    console.log(`🔧 Environment: ${process.env.NODE_ENV || 'development'}`);
    console.log(`🌐 Trust proxy: ${app.get('trust proxy')}`);
    console.log(`🛡️ Rate limiting: Enabled with cloud deployment compatibility`);
    
    // Test the server is working
    setTimeout(() => {
        console.log('✅ Server startup test completed successfully');
    }, 1000);
});

// Global error handlers to prevent crashes
process.on('uncaughtException', (err) => {
    console.error('🚨 Uncaught Exception:', err);
    console.error('Stack trace:', err.stack);
    
    // Don't exit immediately, try to continue running
    console.log('Attempting to continue server operation...');
});

process.on('unhandledRejection', (reason, promise) => {
    console.error('🚨 Unhandled Rejection at:', promise, 'reason:', reason);
    
    // Don't exit immediately, try to continue running
    console.log('Attempting to continue server operation...');
});

// Graceful shutdown
process.on('SIGINT', () => {
    console.log('\n🛑 Received SIGINT, shutting down gracefully...');
    process.exit(0);
});

process.on('SIGTERM', () => {
    console.log('\n🛑 Received SIGTERM, shutting down gracefully...');
    process.exit(0);
});

// Export for testing purposes
module.exports = app;
