# Moon HUB Admin Backend Server

A complete Node.js backend server for the Moon HUB admin communication system. This server allows admins to monitor and control script users remotely through HTTP API endpoints.

## 🚀 Features

- **Real-time User Monitoring**: Track all active script users with heartbeats
- **Remote Admin Control**: Send kill commands to users remotely
- **Secure API Endpoints**: Rate limiting, CORS, and security headers
- **Automatic Cleanup**: Remove inactive users and expired commands
- **Comprehensive Logging**: Track all admin actions and system events
- **Statistics Dashboard**: Monitor server performance and user counts

## 📋 Prerequisites

- Node.js 16.0.0 or higher
- npm or yarn package manager
- Git (for cloning the repository)

## 🛠️ Installation

### 1. Clone the Repository
```bash
git clone <your-github-repo-url>
cd moon-hub-admin-backend
```

### 2. Install Dependencies
```bash
npm install
```

### 3. Start the Server
```bash
# Production mode
npm start

# Development mode (with auto-restart)
npm run dev
```

The server will start on port 3000 by default. You can change this by setting the `PORT` environment variable.

## 🌐 API Endpoints

### Health Check
```
GET /api/health
```
Returns server status and basic information.

### Script User Heartbeat
```
POST /api/script/heartbeat
```
**Request Body:**
```json
{
  "username": "PlayerName",
  "userid": 123456789,
  "displayname": "DisplayName",
  "timestamp": 1703123456.789,
  "status": "active",
  "gameid": 123456789,
  "jobid": "job123"
}
```

### Admin User List
```
GET /api/admin/users
```
Returns list of all active script users.

### Admin Kill Command
```
POST /api/admin/kill
```
**Request Body:**
```json
{
  "target_userid": 123456789,
  "admin_userid": 987654321,
  "admin_username": "AdminName",
  "timestamp": 1703123456.789,
  "action": "kill"
}
```

### User Kill Command Check
```
GET /api/script/check_kill/{userid}
```
Check if a user has pending kill commands.

### Statistics
```
GET /api/stats
```
Returns server statistics and performance metrics.

## 🔧 Configuration

### Environment Variables
- `PORT`: Server port (default: 3000)
- `NODE_ENV`: Environment mode (development/production)

### Rate Limiting
- **Window**: 15 minutes
- **Max Requests**: 100 per IP per window
- **Endpoint**: `/api/`

### Timeouts
- **User Heartbeat**: 30 seconds
- **Kill Commands**: 60 seconds

## 📊 Data Storage

The server currently uses in-memory storage (Maps and Sets). For production use, consider implementing:

- **MongoDB**: For user data and commands
- **Redis**: For caching and real-time features
- **PostgreSQL**: For structured data and analytics

## 🚀 Deployment

### Render.com
1. Connect your GitHub repository
2. Set build command: `npm install`
3. Set start command: `npm start`
4. Set environment variables if needed

### Railway
1. Connect your GitHub repository
2. Railway will auto-detect Node.js
3. Deploy automatically on push

### Heroku
1. Create a new Heroku app
2. Connect your GitHub repository
3. Set buildpacks to Node.js
4. Deploy from main branch

### VPS/Server
1. Clone repository on your server
2. Install Node.js and npm
3. Run `npm install --production`
4. Use PM2 or systemd to manage the process

## 🔒 Security Features

- **Helmet.js**: Security headers
- **CORS**: Cross-origin resource sharing
- **Rate Limiting**: Prevent abuse
- **Input Validation**: Sanitize all inputs
- **Error Handling**: Secure error messages

## 📝 Logging

The server logs:
- All API requests
- Admin actions
- User connections/disconnections
- System errors
- Performance metrics

## 🧪 Testing

### Manual Testing
Use tools like Postman or curl to test endpoints:

```bash
# Health check
curl http://localhost:3000/api/health

# Send heartbeat
curl -X POST http://localhost:3000/api/script/heartbeat \
  -H "Content-Type: application/json" \
  -d '{"username":"TestUser","userid":123,"timestamp":1234567890}'

# Get user list
curl http://localhost:3000/api/admin/users
```

### Automated Testing
```bash
# Install test dependencies
npm install --save-dev jest supertest

# Run tests
npm test
```

## 📈 Monitoring

### Built-in Statistics
- Active user count
- Pending kill commands
- Server uptime
- Memory usage
- Request counts

### External Monitoring
- **Uptime Robot**: Monitor server availability
- **LogRocket**: Error tracking and performance
- **New Relic**: Application performance monitoring

## 🔧 Troubleshooting

### Common Issues

1. **Port Already in Use**
   ```bash
   # Find process using port 3000
   lsof -i :3000
   # Kill the process
   kill -9 <PID>
   ```

2. **Dependencies Not Found**
   ```bash
   # Clear npm cache
   npm cache clean --force
   # Reinstall dependencies
   rm -rf node_modules package-lock.json
   npm install
   ```

3. **Permission Denied**
   ```bash
   # Check file permissions
   ls -la
   # Fix permissions if needed
   chmod +x node.js
   ```

### Log Analysis
Check server logs for:
- Error messages
- Failed requests
- Performance issues
- Security alerts

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

- **Issues**: Create a GitHub issue
- **Discord**: Join our community server
- **Email**: Contact the development team

## 🔮 Future Features

- [ ] WebSocket support for real-time updates
- [ ] Database integration (MongoDB/PostgreSQL)
- [ ] User authentication and authorization
- [ ] Admin dashboard web interface
- [ ] Analytics and reporting
- [ ] Multi-server support
- [ ] Backup and recovery systems

---

**Made with ❤️ by the Moon HUB Team**
