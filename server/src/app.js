require('dotenv').config();
const express = require('express');
const session = require('express-session');
const passport = require('passport');
const cors = require('cors');
const { createClient } = require('redis');
const RedisStore = require('connect-redis').default;

require('./auth/passport');

const app = express();

// Redis client for session store + game state
const redisClient = createClient({
  socket: {
    host: process.env.REDIS_HOST || 'redis',
    port: parseInt(process.env.REDIS_PORT || '6379'),
  },
});

redisClient.connect().catch(console.error);

redisClient.on('error', (err) => console.error('Redis client error:', err));
redisClient.on('connect', () => {
  console.log('Connected to Redis');

  // Share redis client with game modules
  const { setRedisClient: wsSetRedis } = require('./ws/server');
  const { setRedisClient: routesSetRedis } = require('./game/match-routes');
  const turnScheduler = require('./game/turn-scheduler');

  const { setRedisClient: oracleSetRedis } = require('./oracle/routes');
  const { setRedisClient: spectateSetRedis } = require('./game/spectate-routes');

  wsSetRedis(redisClient);
  routesSetRedis(redisClient);
  oracleSetRedis(redisClient);
  spectateSetRedis(redisClient);
  turnScheduler.init(redisClient);

  // Wire redis into matchmaker (wss ref is set in initWebSocket)
  const { matchmaker } = require('./game/matchmaker');
  matchmaker._redisClient = redisClient;

  // Restore any in-progress matches after server restart
  turnScheduler.restoreActiveMatches().catch(console.error);
});

// Middleware
app.use(cors({
  origin: process.env.CLIENT_ORIGIN || 'http://localhost:8080',
  credentials: true,
}));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Session with Redis store
const sessionMiddleware = session({
  store: new RedisStore({ client: redisClient }),
  secret: process.env.SESSION_SECRET || 'dev_secret_change_me',
  resave: false,
  saveUninitialized: false,
  cookie: {
    secure: process.env.NODE_ENV === 'production',
    httpOnly: true,
    maxAge: 7 * 24 * 60 * 60 * 1000, // 7 days
  },
});

app.use(sessionMiddleware);
app.use(passport.initialize());
app.use(passport.session());

// Routes
app.use('/auth', require('./auth/routes'));
app.use('/characters', require('./characters/routes'));
app.use('/matches', require('./game/match-routes').router);
app.use('/oracle', require('./oracle/routes').router);
app.use('/spectate', require('./game/spectate-routes').router);
app.use('/leaderboard', require('./leaderboard/routes'));

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Root redirect to client
app.get('/', (req, res) => {
  const clientUrl = process.env.CLIENT_ORIGIN || 'https://oracle-battleroyale.vercel.app';
  res.redirect(302, clientUrl);
});

// Serve Godot web build static files if CLIENT_STATIC_DIR is set
if (process.env.CLIENT_STATIC_DIR) {
  const path = require('path');
  app.use((req, res, next) => {
    res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
    res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
    next();
  });
  app.use(require('express').static(process.env.CLIENT_STATIC_DIR));
}

module.exports = app;
module.exports.sessionMiddleware = sessionMiddleware;
