const express = require('express');
const passport = require('passport');
const router = express.Router();

// Initiate Google OAuth flow
router.get('/google', passport.authenticate('google', {
  scope: ['profile', 'email'],
}));

// Google OAuth callback
router.get('/google/callback',
  passport.authenticate('google', { failureRedirect: '/auth/failure' }),
  (req, res) => {
    // Successful authentication — session cookie is set by express-session
    const redirectTo = process.env.CLIENT_ORIGIN || 'http://localhost:8080';
    res.redirect(`${redirectTo}/auth/success`);
  }
);

// Get current session user
router.get('/me', (req, res) => {
  if (!req.isAuthenticated()) {
    return res.status(401).json({ error: 'Not authenticated' });
  }
  const { id, email, display_name, avatar_url, constellation_points, created_at } = req.user;
  res.json({ id, email, displayName: display_name, avatarUrl: avatar_url, constellationPoints: constellation_points, createdAt: created_at });
});

// Logout
router.post('/logout', (req, res, next) => {
  req.logout((err) => {
    if (err) return next(err);
    req.session.destroy(() => {
      res.clearCookie('connect.sid');
      res.json({ message: 'Logged out' });
    });
  });
});

router.get('/failure', (req, res) => {
  res.status(401).json({ error: 'OAuth authentication failed' });
});

module.exports = router;
