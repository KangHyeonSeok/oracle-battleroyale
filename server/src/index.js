require('dotenv').config();
const http = require('http');
const app = require('./app');
const { initWebSocket } = require('./ws/server');

const PORT = process.env.PORT || 3000;

const server = http.createServer(app);
initWebSocket(server);

server.listen(PORT, () => {
  console.log(`Oracle Battle Royale server running on port ${PORT}`);
});
