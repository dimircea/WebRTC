Array.prototype.remove = function(val) {
  var index = this.indexOf(val);
  if (index > -1) {
  this.splice(index, 1);
  }
};

const WebSocketServer = require('ws').Server,
  express = require('express'),
  https = require('https'),
  app = express(),
  fs = require('fs'),
  uuid = require('uuid'); //生成UUID

const pkey = fs.readFileSync('./ssl/key.pem'),
  pcert = fs.readFileSync('./ssl/cert.pem'),
  options = {key: pkey, cert: pcert, passphrase: '123456789'},
  _uuidclientMap = {},
  _roomUserIdMap = {};  //用于保存每个房间内有多少个用户
var wss = null, sslSrv = null;

var separator = "__"  //连接符：用于生成userId时，连接后面的roomId

// use express static to deliver resources HTML, CSS, JS, etc)
// from the public folder 
app.use(express.static('public'));

app.use(function(req, res, next) {
  if(req.headers['x-forwarded-proto']==='http') {
    return res.redirect(['https://', req.get('Host'), req.url].join(''));
  }
  next();
});

// start server (listen on port 443 - SSL)
sslSrv = https.createServer(options, app).listen(443);
console.log("The HTTPS server is up and running");

// create the WebSocket server
wss = new WebSocketServer({server: sslSrv});  
console.log("WebSocket Secure server is up and running.");

var DEBUG = true
/** successful connection */
wss.on('connection', function (client) {


  console.log("new user was connected.");
  // console.log(client)
  /** incomming message */
  // wss.broadcast(JSON.stringify({message:"A new WebSocket client was connected."}), client);

  client.on('message', function (message) {
    /** broadcast message to all clients */
    // console.log(JSON.stringify(message));
    // console.error(message)
    console.error(client == this)

    if(DEBUG) {
      handleMessage(client, message)
    } else {
      wss.broadcast(message, client);
    }

  });
  client.on("close", function(code, reaseon) {
    var socketId = userIdForClient(client)
    console.error(socketId + "离开了房间")
    console.error("原因：" + reaseon + "   代码：" + code)

    var roomId = socketId.split(separator).pop()
    console.error("房间号：" + roomId);
    delete _uuidclientMap[socketId];
    var connections = _roomUserIdMap[roomId];

    var response = {"eventName": "_remove_peer",
      "data": {
        "socketId":socketId
      }
    };
    wss.broadcastInRoom(roomId, socketId, JSON.stringify(response))

    connections.remove(socketId);
    console.error(connections);

  })
});

  function handleMessage(client, message) {
    var requestParams = JSON.parse(message);
    var data = requestParams["data"]
    if("_join" == requestParams.eventName) {

      // var userId = uuid.v1();


      Object.values(_uuidclientMap).forEach(function(cont) {
        if (cont == client) {
          console.error("连接覆盖")
        } else {
          console.error("连接未覆盖")
        }
      })

      var roomId = requestParams["data"]["room"];

      var userId = uuid.v1() + separator + roomId;

      var connections = _roomUserIdMap[roomId] || [];
      _roomUserIdMap[roomId] = connections
      _uuidclientMap[userId] = client;
      console.error(userId + "加入房间")
      var response = {"eventName": "_peers",
                      "data": {
                        "connections": connections,
                        "you":userId
                      }
                    };      
      client.send(JSON.stringify(response))
      connections.push(userId)
      console.error(connections)

      if(connections.length > 0) {
        response = {"eventName": "_new_peer",
          "data": {
            "socketId":userId
          }
        }; 
        wss.broadcastInRoom(roomId, userId, JSON.stringify(response))
      }
 
    } 
    else if("_answer" == requestParams.eventName){
      var userId = data["socketId"]
      var roomId = data["roomId"]
      var receiveClient = _uuidclientMap[userId]
      var socketId = userIdForClient(client)
      data["socketId"] = socketId

      console.error("_answer原始id__" + userId)
      console.error("_answer原始id__" + userId)

      if (receiveClient.readyState === receiveClient.OPEN)  {
        receiveClient.send(JSON.stringify(requestParams));
      } else {
        console.error('Error: the client state is ' + client.readyState)
      }
    }
    else if("_offer" == requestParams.eventName){
      var userId = data["socketId"]
      var roomId = data["roomId"]
      var receiveClient = _uuidclientMap[userId]
      console.error(_uuidclientMap)
      
      var socketId = userIdForClient(client)
      data["socketId"] = socketId

      console.error("_answer原始id__" + userId)
      console.error("_answer原始id__" + socketId)

      if (receiveClient.readyState === client.OPEN)  {
        receiveClient.send(JSON.stringify(requestParams));
      } else {
        console.error('Error: the client state is ' + client.readyState)
      }
    } 
    else {
      console.error("分发消息")
      // console.error(requestParams)

      var userId = data["socketId"]
      var roomId = data["roomId"]
      // data["socketId"]
      // var client = _uuidclientMap[userId]
      // client.send(message);
      var socketId = userIdForClient(client)
      data["socketId"] = socketId
      wss.broadcastInRoom(roomId, socketId, JSON.stringify(requestParams))
    }
  };


  function userIdForClient(client) {
    var socketId = null;
    Object.keys(_uuidclientMap).forEach(function(userId) {
      var tclient = _uuidclientMap[userId]
      if(tclient == client) {
        socketId = userId
      }
    });
    return socketId
  }

  wss.broadcastInRoom = function (roomId, senderUserId, message) {

    console.log("给" + roomId + "号房间其他成员发送所有信息");
    // console.log(Object.values(_uuidclientMap).length)
    // console.log(senderUserId)

    var connections = _roomUserIdMap[roomId]

    console.log(connections)

    connections.forEach(function(userId) {
      var client = _uuidclientMap[userId]
      if (null != client && undefined != client && senderUserId != userId) {
        // console.log(userId)

        if (client.readyState === client.OPEN)  {
          client.send(message);
        } else {
          console.error('Error: the client state is ' + client.readyState)
        }
      }

    })
  };



wss.on('close',function(client){
  //正常关闭连接
  console.log('A new WebSocket client was offline.');
});
// broadcasting the message to all WebSocket clients.
wss.broadcast = function (data, exclude) {
  var i = 0, n = this.clients ? this.clients.length : 0, client = null;
  if (n < 1) return;
  console.log("Broadcasting message to all " + n + " WebSocket clients.");
  for (; i < n; i++) {
    client = this.clients[i];
    // don't send the message to the sender...
    if (client === exclude) continue;
    if (client.readyState === client.OPEN) client.send(data);
    else console.error('Error: the client state is ' + client.readyState);
  }
};