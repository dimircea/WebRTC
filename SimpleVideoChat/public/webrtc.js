/** browser dependent definition are aligned to one and the same standard name **/
navigator.getUserMedia = navigator.mediaDevices.getUserMedia || navigator.getUserMedia || navigator.mozGetUserMedia || navigator.webkitGetUserMedia;
// window.RTCPeerConnection = window.RTCPeerConnection || window.mozRTCPeerConnection || window.webkitRTCPeerConnection;
// window.RTCIceCandidate = window.RTCIceCandidate || window.mozRTCIceCandidate || window.webkitRTCIceCandidate;
// window.RTCSessionDescription = window.RTCSessionDescription || window.mozRTCSessionDescription || window.webkitRTCSessionDescription;
window.SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition || window.mozSpeechRecognition 
  || window.msSpeechRecognition || window.oSpeechRecognition;

Array.prototype.remove = function(val) {
  var index = this.indexOf(val);
  if (index > -1) {
  this.splice(index, 1);
  }
};

var config = {
  wssHost: 'wss://172.17.16.158'
  // wssHost: 'wss://172.18.0.48'
  // wssHost: 'wss://192.168.31.111'
  // wssHost: 'wss://example.com/myWebSocket'
};
var localVideoElem = null, 
  remoteVideoElem = null, 
  localVideoStream = null,
  remoteVideoStream = null;
  videoCallButton = null, 
  endCallButton = null;
var peerConn = null,
  wsc = null,
  peerConnCfg = {
    // debug: 3,
    'iceServers': 
    // [{'url': 'stun:stun.services.mozilla.com'}, 
    //  {'url': 'stun:stun.l.google.com:19302'}]
    [
      // {'urls': 'stun:stun.voxgratia.org'}, 
      // {'urls': 'stun:stunserver.org'}
      // {'urls': 'stun:172.17.16.158:3478'}
      {'urls': 'stun:172.16.134.8:3478'},
      {'urls': 'stun:172.16.134.8:3478'}
  ]
  };
var _roomId = null
var _connectionMap = {}  //存储房间内每个用户对应的连接
var _streamsMap = {};   //存储房间内每个用户对应的流

var signal = null;

function initWebsocket() {
  wsc = new WebSocket(config.wssHost);
  // console.error(navigator.mediaDevices.getUserMedia)

  videoCallButton.removeAttribute("disabled");
  videoCallButton.addEventListener("click", initiateCall);
  endCallButton.addEventListener("click", function (evt) {
    wsc.send(JSON.stringify({"closeConnection": true }));
    endCall()
  });

  var DEBUG = true
  wsc.onopen = function(evt) {
    console.log("成功连接")
    console.log(evt)

    if(DEBUG) {
      _roomId = document.getElementById("roomID").value
      joinRoom(_roomId)
    } else {

    }

  };
  wsc.onclose = function(evt) {
    console.error("关闭连接")
  }

  wsc.onmessage = function (evt) {
    console.error("收到消息");
    console.error(evt.data)
    signal = JSON.parse(evt.data);

    if(DEBUG) {
      didReceiveMessage(signal);
    } else {
      if (!peerConn) {
        console.error("应答");
        // document.getElementById("agreeButton").removeAttribute("disabled");
        answerCall();
      } else {
        handleSignal();
      }
    }
  };
}

var _connections = []
var _userId = ""
function getLocalStream(callback) {

  if(null == callback || undefined == callback) {
    callback = function() {

    }
  }

  if (null == localVideoStream) {
    createLocalStream(callback);
  } else {
    callback()
  }
}
function joinRoom(roomId) {
  var message = {
    "eventName": "_join",
    "data": {"room": roomId}
  }
  wsc.send(JSON.stringify(message))
}
// 根据收到信令做相应处理
function didReceiveMessage(message) {
  var eventName = signal["eventName"];
  var data = signal["data"];
  if ("_peers" == eventName) {
    console.error("_peers")
    var connections = data["connections"]
    _connections = _connections.concat(connections)
    _userId = data["you"]

    getLocalStream(function() {
      createPeerConnections();
      addStreams();
      createOffers();
    });
    // 刷新页面待实现
  } //接收到新加入的人发了ICE候选，（即经过ICEServer而获取到的地址）
  else if ("_ice_candidate" == eventName) {
    var userId = data["socketId"];
    var sdpMid = data["sdpMid"];
    var sdpMLineIndex = data["sdpMLineIndex"];
    var sdp = data["sdp"];

    var candidateInit = {
                          "candidate":sdp,
                          "sdpMLineIndex":sdpMLineIndex,
                          "sdpMid":sdpMid
                        }
    var candidate = new RTCIceCandidate(candidateInit);
    var peerConnection = _connectionMap[userId];
    console.error(candidate)
    console.error(peerConnection)
    peerConnection.addIceCandidate(candidate).then(function() {
      console.error("添加ice备选地址成功")
    }).catch(function(e) {
      console.error(e);
    });
  } //其他新人加入房间的信息
  else if ("_new_peer" == eventName) {
    var userId = data["socketId"];
    var peerConnection = createPeerConnection(userId)

    getLocalStream(function() {
      console.error("_new_peer添加addStream")
      peerConnection.addStream(localVideoStream)  //添加本地数据流
      _connections.push(userId)
      _connectionMap[userId] = peerConnection

      //更新相关业务，待实现
    })

  }//有人离开房间的事件
  else if ("_remove_peer" == eventName) {
    var userId = data["socketId"];
    closePeerConnection(userId)
    //有人离开后待实现
  } //新加入的人发了offer
  else if ("_offer" == eventName) {
    console.error("收到_offer")
    console.error(data)
    console.error(_connectionMap)

    var sdpDic = data["sdp"]
    var sdp = sdpDic["sdp"]
    var userId = data["socketId"]
    var peerConnection = _connectionMap[userId]
    var remoteSdp = new RTCSessionDescription({
      "type":"offer",
      "sdp":sdp
    })
    peerConnection.setRemoteDescription(remoteSdp).then(function(){
      setSessionDescriptionWithPeerConnection(peerConnection)
    })
  }//回应offer
  else if ("_answer" == eventName) {
    var sdpDic = data["sdp"]
    var sdp = sdpDic["sdp"]
    var userId = data["socketId"]
    var peerConnection = _connectionMap[userId]
    var remoteSdp = new RTCSessionDescription({
      "type":"answer",
      "sdp":sdp
    })
    peerConnection.setRemoteDescription(remoteSdp).then(function(){
      setSessionDescriptionWithPeerConnection(peerConnection)
    })
  }
}
// 创建本地视频流
function createLocalStream(callback) {
  // var constraints = { audio: true, video: { width: 1280, height: 720 } }; 
  var constraints = { audio: true, video: true }; 
  navigator.mediaDevices.getUserMedia(constraints)
  .then(function(stream) {
    console.error("开启本地视频")
    localVideoStream = stream;
    localVideo.srcObject = localVideoStream;
    callback()
  })
  .catch(function(err) { console.log(err.name + ": " + err.message); }); // 总是在最后检查错误
}
// 为每个连接添加视频流
function addStreams() {
  Object.values(_connectionMap).forEach(function(peerConnecnt){
    peerConnecnt.addStream(localVideoStream);
  })
}
// 为所有连接创建offer
function createOffers() {
  Object.values(_connectionMap).forEach(function(peerConnecnt){
    createOffer(peerConnecnt)
  })
}
//批量创建PeerConnection连接
function createPeerConnections() {
  _connections.forEach(function(userId) {
    var peerConnecnt = createPeerConnection(userId);
    _connectionMap[userId] = peerConnecnt;
  })
}
// 创建PeerConnection连接
function createPeerConnection(userId) {
  // console.error("构造peerConn");
  var peerConnection = new RTCPeerConnection(peerConnCfg);
  // send any ice candidates to the other peer
  peerConnection.onicecandidate = gotICECandidate
  // once remote stream arrives, show it in the remote video element
  peerConnection.onaddstream = didAddStream
  peerConnection.oniceconnectionstatechange = didChangeIceConnectionState
  return peerConnection;
}
// 根据对应连接创建对应的offer
function createOffer(peerConnecnt) {
  peerConnecnt.createOffer({}).then(function (offer) {
    console.error("设置本地标识符1");
    console.error(offer);

    var off = new RTCSessionDescription(offer);
    return peerConnecnt.setLocalDescription(new RTCSessionDescription(off)).then(function(){
        setSessionDescriptionWithPeerConnection(peerConnecnt)
    })
  }).then(function (error) { 
    // console.log(error);
  });
}
// 根据peerconnect连接获取对应的userId 
function getKeyFromConnectionDic(peerConnection) {
  var stockId = null;
  Object.keys(_connectionMap).forEach(function(userId) {
    var tConnect = _connectionMap[userId];
    if (tConnect == peerConnection) {
      stockId = userId;
    }
  });
  return stockId
}
function setSessionDescriptionWithPeerConnection(peerConnection) {

  console.error("设置sdp")
  console.error(peerConnection.signalingState)
  console.error(peerConnection)

  var userId = getKeyFromConnectionDic(peerConnection);
  if("have-remote-offer" == peerConnection.signalingState) {

    peerConnection.createAnswer({}).then(function(answer) {
      var ans = new RTCSessionDescription(answer);
      console.error(ans)
      console.error("设置LocalDescription")
      return peerConnection.setLocalDescription(answer).then(function(){
          setSessionDescriptionWithPeerConnection(peerConnection)
      });
    })
    .then(function() {
      // Send the answer to the remote peer through the signaling server.
    })
  } //判断连接状态为本地发送offer
  else if ("have-local-offer" == peerConnection.signalingState) {
    var type = peerConnection.localDescription.type
    var sdp = peerConnection.localDescription.sdp
    if( "answer" == type) { //响应者,发送自己的answer
      var requestParmas = {
                            "eventName": "_answer",
                            "data": {
                              "sdp": {
                                "type":type,
                                "sdp":sdp,
                              },
                              "socketId":userId,
                              "roomId":_roomId
                            }
                            };
      console.error("发送answer___have-local-offer")
      wsc.send(JSON.stringify(requestParmas))
    }//发送者,发送自己的offer
    else if ("offer" == type) {
      var requestParmas = {
        "eventName": "_offer",
        "data": {
          "sdp": {
            "type":type,
            "sdp":sdp
          },
          "socketId":userId,
          "roomId":_roomId
        }
      };
      wsc.send(JSON.stringify(requestParmas))
    }
  }
  else if ("stable" == peerConnection.signalingState) {
    var type = peerConnection.localDescription.type
    var sdp = peerConnection.localDescription.sdp
    if ("answer" == type) {
      var requestParmas = {
        "eventName": "_answer",
        "data": {
          "sdp": {
            "type":type,
            "sdp":sdp
          },
          "socketId":userId,
          "roomId":_roomId
        }
      };
      console.error("发送answer___stable")
      wsc.send(JSON.stringify(requestParmas))
    }
  }
}

// 第二部分ICE相关响应
// 获取到新的candidate
function gotICECandidate(evt) {
  if (!evt || !evt.candidate) return;
  
  console.error(this)
  var userId = getKeyFromConnectionDic(this);

  var candidate = evt.candidate;
  var requestParmas = {
    "eventName": "_ice_candidate",
    "data": {
      "socketId": userId,
      "sdpMid":candidate.sdpMid,
      "sdpMLineIndex":candidate.sdpMLineIndex,
      "sdp":candidate.candidate,
      "roomId":_roomId
    }
  };
  console.error(requestParmas)
  wsc.send(JSON.stringify(requestParmas))
};
// 连接状态变化
function didChangeIceConnectionState(evt){
  console.error("状态变化");
  console.error(evt);
}
function didAddStream(evt) {
  console.error("获取新的远程视频流");
  console.error(evt.stream);
  console.error(localVideoStream);

  var userId = getKeyFromConnectionDic(this);

  _streamsMap[userId] = evt.stream
  // remoteVideo.srcObject = evt.stream;
  // remoteVideo.srcObject = localVideoStream;

  // document.getElementById('div-video').innerHTML = "";
  // var str='';
  // _connections.forEach(function(userId) {
  //   str += "<video class='video-remote' id='" + userId +"' autoplay muted style='width:300px;height:200px;background-color: red;margin: 4px;'></video>"; //拼接str
  // })

  // document.getElementById('div-video').innerHTML = str;
  // var videoDoms = document.querySelectorAll(".video-remote")
  // console.log("获取dom")
  // console.log(_streamsMap)
  // console.log(videoDoms)

  // videoDoms.forEach(function(videoElement) {
  //   console.error(videoElement)
  //   var stream = _streamsMap[videoElement.id]
  //   videoElement.srcObject = stream;
  // })
  reloadRemoteView()

}
// 刷新远程画面 
function reloadRemoteView () {
  document.getElementById('div-video').innerHTML = "";
  var str='';
  _connections.forEach(function(userId) {
    str += "<video class='video-remote' id='" + userId +"' autoplay muted style='width:300px;height:200px;background-color: red;margin: 4px;'></video>"; //拼接str
  })

  document.getElementById('div-video').innerHTML = str;
  var videoDoms = document.querySelectorAll(".video-remote")
  console.log("获取dom")
  console.log(_streamsMap)
  console.log(videoDoms)

  videoDoms.forEach(function(videoElement) {
    console.error(videoElement)
    var stream = _streamsMap[videoElement.id]
    videoElement.srcObject = stream;
  })
}
// 关闭指定连接
function closePeerConnection(userId) {
  var peerConnection = _connectionMap[userId]
  if (null != peerConnection && undefined != peerConnection) {
    peerConnection.close()
  }
  _connections.remove(userId)
  delete _connectionMap[userId]
  delete _streamsMap[userId]

  reloadRemoteView()
}
// 退出房间
function exitRoom() {
  localVideoStream = null;
  _connections.forEach(function(userId) {
    closePeerConnection(userId)
  })
  wsc.close()
}

function pageReady() {
  // check browser WebRTC availability 
  // console.error(navigator.mediaDevices.getUserMedia)
  document.getElementById("connectButton").addEventListener("click", initWebsocket);
  // document.getElementById("agreeButton").addEventListener("click", agreeConversation);

  if(navigator.getUserMedia) {
    videoCallButton = document.getElementById("videoCallButton");
    endCallButton = document.getElementById("endCallButton");
    localVideo = document.getElementById('localVideo');
    remoteVideo = document.getElementById('remoteVideo');
  } else {
    alert("Sorry, your browser does not support WebRTC!")
  }
};

function prepareCall() {
  console.error("构造peerConn");
  peerConn = new RTCPeerConnection(peerConnCfg);
  // send any ice candidates to the other peer
  peerConn.onicecandidate = onIceCandidateHandler;
  // once remote stream arrives, show it in the remote video element
  peerConn.onaddstream = onAddStreamHandler;
};

// run start(true) to initiate a call
function initiateCall() {
  prepareCall();
  // get the local stream, show it in the local video element and send it
  // navigator.getUserMedia({ "audio": true, "video": true }, function (stream) {
  //   localVideoStream = stream;
  //   // localVideo.src = URL.createObjectURL(localVideoStream);
  //   localVideo.srcObject = localVideoStream;

  //   peerConn.addStream(localVideoStream);
  //   createAndSendOffer();
  // }, function(error) { console.log(error);});


  var constraints = { audio: true, video: { width: 1280, height: 720 } }; 
  navigator.mediaDevices.getUserMedia(constraints)
  .then(function(stream) {
    console.error("开启本地视频")
    localVideoStream = stream;
    // localVideo.src = URL.createObjectURL(localVideoStream);
    localVideo.srcObject = localVideoStream;

    setTimeout(function(){
      createAndSendOffer();
    }, 300)
    peerConn.addStream(localVideoStream);
  })
  .catch(function(err) { console.log(err.name + ": " + err.message); }); // 总是在最后检查错误

};

function handleSignal() {
  console.error(signal);
  if (signal.sdp) {
    console.log("Received SDP from remote peer.");
    peerConn.setRemoteDescription(new RTCSessionDescription(signal.sdp));
  }
  else if (signal.candidate) {
    console.log("Received ICECandidate from remote peer.");
    peerConn.addIceCandidate(new RTCIceCandidate(signal.candidate));
  } else if ( signal.closeConnection){
    console.log("Received 'close call' signal from remote peer.");
    endCall();
  }
}

function agreeConversation() {
  // navigator.getUserMedia({ "audio": true, "video": true }, function (stream) {
    // localVideoStream = stream;
    // localVideo.src = URL.createObjectURL(localVideoStream);
    localVideo.srcObject = localVideoStream;
    remoteVideo.srcObject = remoteVideoStream;
    // peerConn.addStream(localVideoStream);
    // createAndSendAnswer();
  // }, function(error) { console.log(error);});
}

function answerCall() {
  console.error("同意");
  prepareCall();
  handleSignal();

  // get the local stream, show it in the local video element and send it
  // navigator.getUserMedia({ "audio": true, "video": true }, function (stream) {
  //   localVideoStream = stream;
  //   // localVideo.src = URL.createObjectURL(localVideoStream);
  //   localVideo.srcObject = localVideoStream;
  //   peerConn.addStream(localVideoStream);
  //   createAndSendAnswer();
  // }, function(error) { console.log(error);});
  //  navigator.getUserMedia({ "audio": true, "video": true }, function (stream) {
  //   localVideoStream = stream;
  //   // localVideo.src = URL.createObjectURL(localVideoStream);
  //   localVideo.srcObject = localVideoStream;
  //   peerConn.addStream(localVideoStream);
  //   createAndSendAnswer();
  // }, function(error) { console.log(error);});

  var constraints = { audio: true, video: { width: 1280, height: 720 } }; 
  navigator.mediaDevices.getUserMedia(constraints)
  .then(function(stream) {
    localVideoStream = stream;
    // localVideo.src = URL.createObjectURL(localVideoStream);
    localVideo.srcObject = localVideoStream;

    setTimeout(function(){
      createAndSendAnswer();
    }, 300)
    peerConn.addStream(localVideoStream);
    // createAndSendAnswer();
  })
  .catch(function(err) { console.log(err.name + ": " + err.message); }); // 总是在最后检查错误

};

function createAndSendOffer() {
  peerConn.createOffer({}).then(function (offer) {
    console.error("设置本地标识符");
    console.error(offer);

    var off = new RTCSessionDescription(offer);
    wsc.send(JSON.stringify({"sdp": off }));
    return peerConn.setLocalDescription(new RTCSessionDescription(off))
  }).then(function (error) { 
    console.log(error);
  });
};

function createAndSendAnswer() {
  console.error("响应")
  peerConn.createAnswer({}).then(function(answer) {
    var ans = new RTCSessionDescription(answer);
    wsc.send(JSON.stringify({"sdp": ans }));
    return peerConn.setLocalDescription(answer);
  })
  .then(function() {
    // Send the answer to the remote peer through the signaling server.
  })
};

function onIceCandidateHandler(evt) {
  if (!evt || !evt.candidate) return;
  wsc.send(JSON.stringify({"candidate": evt.candidate }));
};

function onAddStreamHandler(evt) {
  console.error("获取远程推流")
  videoCallButton.setAttribute("disabled", true);
  endCallButton.removeAttribute("disabled"); 
  // set remote video stream as source for remote video HTML5 element
  // remoteVideo.src = URL.createObjectURL(evt.stream);
  remoteVideo.srcObject = evt.stream;
  // remoteVideo.pause();
  // remoteVideoStream = evt.stream;

};

function endCall() {
  peerConn.close();
  peerConn = null;
  videoCallButton.removeAttribute("disabled");
  endCallButton.setAttribute("disabled", true);

  if (localVideoStream) {
    localVideoStream.getTracks().forEach(function (track) {
      track.stop();
    });
    localVideo.srcObject = null;
  }
  // if (remoteVideo) remoteVideo.src = "";
  if (remoteVideo) remoteVideo.srcObject = null;
};