const http = require('http');

const server = http.createServer((req, res) => {
  res.end("Hello from DevOps Docker Project!");
});

server.listen(3001, () => {
  console.log("Server running on port 3000");
});
