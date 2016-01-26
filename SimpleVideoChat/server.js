var WebSocketServer = require('ws').Server,
    wss = new WebSocketServer({port: 3434});

/** broadcast message to all clients **/
wss.broadcast = function (data) {
  var i = 0, n = this.clients ? this.clients.length : 0, client = null;
  for (; i < n; i++) {
    client = this.clients[i];
    if (client.readyState === client.OPEN) {
      client.send(data);
    }
    else console.error('Error: the client state is ' + client.readyState);
  }
};

/** successful connection */
wss.on('connection', function (ws) {
  /** incomming message */
  ws.on('message', function (message) {
    /** broadcast message to all clients */
    wss.broadcast(message);
  });
});