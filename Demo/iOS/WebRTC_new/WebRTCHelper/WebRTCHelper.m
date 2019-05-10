//
//  WebRTCHelper.m
//  WebRTC_new
//
//  Created by 胡志辉 on 2018/9/4.
//  Copyright © 2018年 Mr.hu. All rights reserved.
//

#import "WebRTCHelper.h"

#define kAPPID  @"1234567890abcdefg"
#define kDeviceUUID [[[UIDevice currentDevice] identifierForVendor] UUIDString]

//google提供的
//static NSString *const RTCSTUNServerURL = @"stun:stun.l.google.com:19302";
//static NSString *const RTCSTUNServerURL2 = @"stun:23.21.150.121";
//static NSString *const RTCSTUNServerURL = @"115.236.101.203:18080";
//static NSString *const RTCSTUNServerURL2 = @"115.236.101.203:18080";
//static NSString *const RTCSTUNServerURL = @"stun:172.17.16.158:3478";
//static NSString *const RTCSTUNServerURL2 = @"stun:172.17.16.158:3478";
static NSString *const RTCSTUNServerURL = @"stun:172.16.134.8:3478";
static NSString *const RTCSTUNServerURL2 = @"stun:172.16.134.8:3478";


@interface WebRTCHelper()<RTCPeerConnectionDelegate,RTCVideoCapturerDelegate,SRWebSocketDelegate>
{
    SRWebSocket *_socket;
    NSString *_server;
    NSString *_room;
    
    RTCPeerConnectionFactory *_factory;
    RTCMediaStream *_localStream;
    
    NSString *_myId;
    NSMutableDictionary *_connectionDic;
    NSMutableArray *_connectionIdArray;
    
//    Role _role;
    NSString * _connectId;
    NSMutableArray *ICEServers;
    //判断是显示前摄像头还是显示后摄像头（yes为前摄像头。false为后摄像头）
    BOOL _usingFrontCamera;
    //是否显示我的视频流（默认为yes，显示；no为不显示）
    BOOL _usingCamera;
}

@property (strong, nonatomic) RTCCameraVideoCapturer *capturer;

@end

@implementation WebRTCHelper

static WebRTCHelper * instance = nil;

+(instancetype)shareInstance{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[[self class] alloc] init];
        [instance initData];
    });
    return instance;
}

-(void)initData{
    _connectionDic = [NSMutableDictionary dictionary];
    _connectionIdArray = [NSMutableArray array];
    _usingFrontCamera = YES;
    _usingCamera = YES;
}


#pragma mark -提供给外部的方法

/**
 * 与服务器进行连接
 */
- (void)connectServer:(NSString *)server port:(NSString *)port room:(NSString *)room{
    _server = server;
    _room = room;
//    NSString * string = @"wss://115.236.101.203:18443/socket.io/?EIO=3&transport=websocket&sid=f49dfe45-ff90-4d79-979d-24366f738be0";
//    NSURL * url = [NSURL URLWithString:string];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"wss://%@:%@",server,port]] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:20];
//  NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:10];
    _socket = [[SRWebSocket alloc] initWithURLRequest:request];
    _socket.delegate = self;
    [_socket open];
//    _socketManager = [[SocketManager alloc] initWithSocketURL:url config:@{@"log": @YES, @"compress": @YES}];
//    SocketIOClient * socketClient = _socketManager.defaultSocket;
//    [socketClient on:@"connect" callback:^(NSArray * data, SocketAckEmitter * ack) {
//        NSLog(@"connection");
//    }];
    
//    NSString * string = @"http://115.236.101.203:18800/token";
//    string = [NSString stringWithFormat:@"%@?appid=%@&uid=%@",string,kAPPID,kDeviceUUID];
//    NSURL * url = [NSURL URLWithString:string];
//    RTCLog(@"Joining room:%@ on room server.", room);
//    NSMutableURLRequest * urlRequest = [NSMutableURLRequest requestWithURL:url];
//    urlRequest.HTTPMethod = @"POST";
//    [[NSURLConnection rac_sendAsynchronousRequest:urlRequest] subscribeNext:^(RACTwoTuple<NSURLResponse *,NSData *> * _Nullable x) {
//        NSString * str = [[NSString alloc] initWithData:[x second] encoding:NSUTF8StringEncoding];
//        [self joinRoom:room];
//        NSLog(@"%@",str);
//    }];
    
}



/**
 *  加入房间
 *
 *  @param room 房间号
 */
- (void)joinRoom:(NSString *)room
{
    //如果socket是打开状态
    if (_socket.readyState == SR_OPEN)
    {
        //初始化加入房间的类型参数 room房间号
        NSDictionary *dic = @{@"eventName": @"_join", @"data": @{@"room": room}};
        
        //得到json的data
        NSData *data = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:nil];
        //发送加入房间的数据
        [_socket send:data];
    }
}
/**
 *  退出房间
 */
- (void)exitRoom
{
    _localStream = nil;
    self.capturer = nil;
    [_connectionIdArray enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self closePeerConnection:obj];
    }];
    [_socket close];
    [self initData];
}

/**
 * 切换摄像头
 */
- (void)swichCamera{
    _usingFrontCamera = !_usingFrontCamera;

    //创建本地流
    [self createLocalStream:^{
    }];
}
/**
 * 是否显示本地摄像头
 */
- (void)showLocaolCamera{
    _usingCamera = !_usingCamera;
    //如果为空，则创建点对点工厂
    if (!_factory)
    {
        //设置SSL传输
        [RTCPeerConnectionFactory initialize];
        _factory = [[RTCPeerConnectionFactory alloc] init];
    }

    __weak typeof(&*self) wself = self;
    //创建本地流
    [self createLocalStream:^{
        //创建连接
        [wself createPeerConnections];

        //添加
        [wself addStreams];
        [wself createOffers];
    }];

}

#pragma mark -内部方法
/**
 *  关闭peerConnection
 *
 *  @param connectionId <#connectionId description#>
 */
- (void)closePeerConnection:(NSString *)connectionId
{
    RTCPeerConnection *peerConnection = [_connectionDic objectForKey:connectionId];
    if (peerConnection)
    {
        [peerConnection close];
    }
    [_connectionIdArray removeObject:connectionId];
    [_connectionDic removeObjectForKey:connectionId];
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self->_delegate respondsToSelector:@selector(webRTCHelper:closeWithUserId:)])
        {
            [self->_delegate webRTCHelper:self closeWithUserId:connectionId];
        }
    });
}


/**
 *  创建点对点连接
 *
 *  @param connectionId connectionId description
 *
 *  @return <#return value description#>
 */
- (RTCPeerConnection *)createPeerConnection:(NSString *)connectionId
{
    //如果点对点工厂为空
    if (!_factory)
    {
        //先初始化工厂
        _factory = [[RTCPeerConnectionFactory alloc] init];
    }
    
    //得到ICEServer
    if (!ICEServers) {
        ICEServers = [NSMutableArray array];
        [ICEServers addObject:[self defaultSTUNServer]];
    }
    
    //用工厂来创建连接
    RTCConfiguration *configuration = [[RTCConfiguration alloc] init];
    configuration.iceServers = ICEServers;
    RTCPeerConnection *connection = [_factory peerConnectionWithConfiguration:configuration constraints:[self creatPeerConnectionConstraint] delegate:self];
    
    return connection;
}

- (RTCMediaConstraints *)creatPeerConnectionConstraint
{
    RTCMediaConstraints *constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:@{kRTCMediaConstraintsOfferToReceiveAudio:kRTCMediaConstraintsValueTrue,kRTCMediaConstraintsOfferToReceiveVideo:kRTCMediaConstraintsValueTrue} optionalConstraints:nil];
    return constraints;
}

//初始化STUN Server （ICE Server）
- (RTCIceServer *)defaultSTUNServer{
//    return [[RTCIceServer alloc] initWithURLStrings:@[RTCSTUNServerURL,RTCSTUNServerURL2]];
    return [[RTCIceServer alloc] initWithURLStrings:@[RTCSTUNServerURL,RTCSTUNServerURL2]];

}



/**
 *  为所有连接添加流
 */
- (void)addStreams
{
    //给每一个点对点连接，都加上本地流
    [_connectionDic enumerateKeysAndObjectsUsingBlock:^(NSString *key, RTCPeerConnection *obj, BOOL * _Nonnull stop) {

        //创建本地流
        [self createLocalStream:^{
            [obj addStream:self->_localStream];
        }];
    }];
}
/**
 *  创建所有连接
 */
- (void)createPeerConnections
{
    //从我们的连接数组里快速遍历
    [_connectionIdArray enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        //根据连接ID去初始化 RTCPeerConnection 连接对象
        RTCPeerConnection *connection = [self createPeerConnection:obj];
        
        //设置这个ID对应的 RTCPeerConnection对象
        [self->_connectionDic setObject:connection forKey:obj];
    }];
}


/**
 * 创建本地视频流
 */
-(void)createLocalStream:(void(^)(void))callback {

    callback = callback ? :^(void){};

    if (!_localStream) {
        _localStream = [_factory mediaStreamWithStreamId:@"ARDAMS"];
        //音频
        RTCAudioTrack * audioTrack = [_factory audioTrackWithTrackId:@"ARDAMSa0"];
        [_localStream addAudioTrack:audioTrack];
        NSArray<AVCaptureDevice *> *captureDevices = [RTCCameraVideoCapturer captureDevices];
        AVCaptureDevicePosition position = _usingFrontCamera ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack;
        AVCaptureDevice * device = captureDevices[0];
        for (AVCaptureDevice *obj in captureDevices) {
            if (obj.position == position) {
                device = obj;
                break;
            }
        }

        //检测摄像头权限
        AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
        if(authStatus == AVAuthorizationStatusRestricted || authStatus == AVAuthorizationStatusDenied)
        {
            NSLog(@"相机访问受限");
            if ([_delegate respondsToSelector:@selector(webRTCHelper:setLocalStream:userId:)])
            {

                [_delegate webRTCHelper:self setLocalStream:nil userId:_myId];
            }
        }
        else
        {
            if (device)
            {
                RTCVideoSource *videoSource = [_factory videoSource];
                RTCCameraVideoCapturer * capture = [[RTCCameraVideoCapturer alloc] initWithDelegate:videoSource];
                NSArray *formats = [RTCCameraVideoCapturer supportedFormatsForDevice:device];
                AVCaptureDeviceFormat * format = [formats objectAtIndex:3];
                CGFloat fps = MIN([[format videoSupportedFrameRateRanges] firstObject].maxFrameRate, 30);
                RTCVideoTrack *videoTrack = [_factory videoTrackWithSource:videoSource trackId:@"ARDAMSv0"];
                __weak RTCCameraVideoCapturer *weakCapture = capture;
                __weak RTCMediaStream * weakStream = _localStream;
                __weak NSString * weakMyId = _myId;
                self.capturer = capture;
                [weakCapture startCaptureWithDevice:device format:format fps:fps completionHandler:^(NSError * error) {
                    NSLog(@"11111111");
                    [weakStream addVideoTrack:videoTrack];
                    if ([self->_delegate respondsToSelector:@selector(webRTCHelper:setLocalStream:userId:)])
                    {
                        [self->_delegate webRTCHelper:self setLocalStream:weakStream userId:weakMyId];
                        [self->_delegate webRTCHelper:self capturerSession:weakCapture.captureSession];
                    }

                    callback();
                }];
                //            [videoSource adaptOutputFormatToWidth:640 height:480 fps:30];

            }
            else
            {
                NSLog(@"该设备不能打开摄像头");
                if ([_delegate respondsToSelector:@selector(webRTCHelper:setLocalStream:userId:)])
                {
                    [_delegate webRTCHelper:self setLocalStream:nil userId:_myId];
                }
            }
        }
    } else {
        callback();
    }
}

/**
 *  视频的相关约束
 */
- (RTCMediaConstraints *)localVideoConstraints
{
    NSDictionary *mandatory = @{kRTCMediaConstraintsMaxWidth:@640,kRTCMediaConstraintsMinWidth:@640,kRTCMediaConstraintsMaxHeight:@480,kRTCMediaConstraintsMinHeight:@480,kRTCMediaConstraintsMinFrameRate:@15};
    RTCMediaConstraints *constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:mandatory optionalConstraints:nil];
    return constraints;
}

/**
 * 创建offer
 */
-(void)createOffer:(RTCPeerConnection *)peerConnection{
    if (peerConnection == nil) {
        peerConnection = [self createPeerConnection:nil];
    }
    [peerConnection offerForConstraints:[self offerOranswerConstraint] completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
        if (error == nil) {
            __weak RTCPeerConnection * weakPeerConnction = peerConnection;
            [weakPeerConnction setLocalDescription:sdp completionHandler:^(NSError * _Nullable error) {
                if (error == nil) {
                    [self setSessionDescriptionWithPeerConnection:weakPeerConnction];
                }
            }];
        }
    }];

}
/**
 *  为所有连接创建offer
 */
- (void)createOffers
{
    //给每一个点对点连接，都去创建offer
    [_connectionDic enumerateKeysAndObjectsUsingBlock:^(NSString *key, RTCPeerConnection *obj, BOOL * _Nonnull stop) {
        [self createOffer:obj];
    }];
}

/**
 *  设置offer/answer的约束
 */
- (RTCMediaConstraints *)offerOranswerConstraint
{
    NSMutableDictionary * dic = [@{kRTCMediaConstraintsOfferToReceiveAudio:kRTCMediaConstraintsValueTrue,kRTCMediaConstraintsOfferToReceiveVideo:kRTCMediaConstraintsValueTrue} mutableCopy];
    [dic setObject:(_usingCamera ? kRTCMediaConstraintsValueTrue : kRTCMediaConstraintsValueFalse) forKey:kRTCMediaConstraintsOfferToReceiveVideo];
    RTCMediaConstraints *constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:dic optionalConstraints:nil];
    return constraints;
}

// Called when setting a local or remote description.
//当一个远程或者本地的SDP被设置就会调用
- (void)setSessionDescriptionWithPeerConnection:(RTCPeerConnection *)peerConnection
{
    NSLog(@"%s",__func__);
    NSString *currentId = [self getKeyFromConnectionDic:peerConnection];
    
    //判断，当前连接状态为，收到了远程点发来的offer，这个是进入房间的时候，尚且没人，来人就调到这里
    if (peerConnection.signalingState == RTCSignalingStateHaveRemoteOffer)
    {
        //创建一个answer,会把自己的SDP信息返回出去
        [peerConnection answerForConstraints:[self offerOranswerConstraint] completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
            __weak RTCPeerConnection *obj = peerConnection;
            [peerConnection setLocalDescription:sdp completionHandler:^(NSError * _Nullable error) {
                [self setSessionDescriptionWithPeerConnection:obj];
            }];
        }];
    }
    //判断连接状态为本地发送offer
    else if (peerConnection.signalingState == RTCSignalingStateHaveLocalOffer)
    {
        if (peerConnection.localDescription.type == RTCSdpTypeAnswer)
        {
            NSDictionary *dic = @{@"eventName": @"_answer", @"data": @{@"sdp": @{@"type": @"answer", @"sdp": peerConnection.localDescription.sdp}, @"socketId": currentId, @"roomId": _room}};
            NSData *data = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:nil];
            [_socket send:data];
        }
        //发送者,发送自己的offer
        else if(peerConnection.localDescription.type == RTCSdpTypeOffer)
        {
            NSDictionary *dic = @{@"eventName": @"_offer", @"data": @{@"sdp": @{@"type": @"offer", @"sdp": peerConnection.localDescription.sdp}, @"socketId": currentId, @"roomId": _room}};
            NSData *data = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:nil];
            [_socket send:data];
        }
    }
    else if (peerConnection.signalingState == RTCSignalingStateStable)
    {
        if (peerConnection.localDescription.type == RTCSdpTypeAnswer)
        {
            NSDictionary *dic = @{@"eventName": @"_answer", @"data": @{@"sdp": @{@"type": @"answer", @"sdp": peerConnection.localDescription.sdp}, @"socketId": currentId, @"roomId": _room}};
            NSData *data = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:nil];
            [_socket send:data];
        }
    }
    
}


#pragma mark RTCPeerConnectionDelegate
/**获取远程视频流*/
- (void)peerConnection:(nonnull RTCPeerConnection *)peerConnection didAddStream:(nonnull RTCMediaStream *)stream {
    NSString * userId = [self getKeyFromConnectionDic:peerConnection];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self->_delegate respondsToSelector:@selector(webRTCHelper:addRemoteStream:userId:)]) {
            [self->_delegate webRTCHelper:self addRemoteStream:stream userId:userId];
        }
    });
}
/**RTCIceConnectionState 状态变化*/
- (void)peerConnection:(nonnull RTCPeerConnection *)peerConnection didChangeIceConnectionState:(RTCIceConnectionState)newState {
    NSLog(@"%s",__func__);
    NSString * connectId = [self getKeyFromConnectionDic:peerConnection];
    if (newState == RTCIceConnectionStateDisconnected) {
        //断开connection的连接
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self->_delegate respondsToSelector:@selector(webRTCHelper:closeWithUserId:)]) {
                [self->_delegate webRTCHelper:self closeWithUserId:connectId];
            }
            [self closePeerConnection:connectId];
        });
    }
}
/**获取到新的candidate*/
- (void)peerConnection:(RTCPeerConnection *)peerConnection didGenerateIceCandidate:(RTCIceCandidate *)candidate{
    NSLog(@"%s",__func__);
    
    NSString *currentId = [self getKeyFromConnectionDic: peerConnection];
    
    NSDictionary *dic = @{@"eventName": @"_ice_candidate", @"data": @{@"sdpMid":candidate.sdpMid,@"sdpMLineIndex": [NSNumber numberWithInteger:candidate.sdpMLineIndex], @"sdp": candidate.sdp, @"socketId": currentId, @"roomId": _room}};
    NSData *data = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:nil];
    [_socket send:data];
}

/**删除某个视频流*/
- (void)peerConnection:(nonnull RTCPeerConnection *)peerConnection didRemoveStream:(nonnull RTCMediaStream *)stream {
    NSLog(@"%s",__func__);
}

- (void)peerConnectionShouldNegotiate:(RTCPeerConnection *)peerConnection{
    NSLog(@"%s,line = %d object = %@",__FUNCTION__,__LINE__,peerConnection);
}

- (void)peerConnection:(nonnull RTCPeerConnection *)peerConnection didRemoveIceCandidates:(nonnull NSArray<RTCIceCandidate *> *)candidates {
    NSLog(@"%s,line = %d object = %@",__FUNCTION__,__LINE__,candidates);
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeSignalingState:(RTCSignalingState)stateChanged{
    NSLog(@"stateChanged = %ld",(long)stateChanged);
}
- (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeIceGatheringState:(RTCIceGatheringState)newState{
    NSLog(@"newState = %ld",newState);
}


#pragma mark -消息相关
-(void)peerConnection:(RTCPeerConnection *)peerConnection didOpenDataChannel:(RTCDataChannel *)dataChannel{
    
}

#pragma mark -视频分辨率代理
- (void)capturer:(nonnull RTCVideoCapturer *)capturer didCaptureVideoFrame:(nonnull RTCVideoFrame *)frame {
    
}



#pragma mark WebSocketDelegate
- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message{
    NSLog(@"收到服务器消息:%@",message);
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:[message dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil];
    NSString *eventName = dic[@"eventName"];
    
    //1.发送加入房间后的反馈
    if ([eventName isEqualToString:@"_peers"])
    {
        //得到data
        NSDictionary *dataDic = dic[@"data"];
        //得到所有的连接
        NSArray *connections = dataDic[@"connections"];
        //加到连接数组中去
        [_connectionIdArray addObjectsFromArray:connections];
        
        //拿到给自己分配的ID
        _myId = dataDic[@"you"];
   
        
        //如果为空，则创建点对点工厂
        if (!_factory)
        {
            //设置SSL传输
            [RTCPeerConnectionFactory initialize];
            _factory = [[RTCPeerConnectionFactory alloc] init];
        }

        //创建本地流
        [self createLocalStream:^{
            //创建连接
            [self createPeerConnections];

            //添加
            [self addStreams];
            [self createOffers];
            //获取房间内所有用户的代理回调
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([self->_friendDelegate respondsToSelector:@selector(webRTCHelper:gotFriendList:)]) {
                    [self->_friendDelegate webRTCHelper:self gotFriendList:connections];
                }
            });
        }];
    }
    //4.接收到新加入的人发了ICE候选，（即经过ICEServer而获取到的地址）
    else if ([eventName isEqualToString:@"_ice_candidate"])
    {
        NSDictionary *dataDic = dic[@"data"];
        NSString *socketId = dataDic[@"socketId"];
        NSString *sdpMid = dataDic[@"sdpMid"];
        int sdpMLineIndex = [dataDic[@"sdpMLineIndex"] intValue];
        NSString *sdp = dataDic[@"sdp"];
        //生成远端网络地址对象
        RTCIceCandidate *candidate = [[RTCIceCandidate alloc] initWithSdp:sdp sdpMLineIndex:sdpMLineIndex sdpMid:sdpMid];;
        //拿到当前对应的点对点连接
        RTCPeerConnection *peerConnection = [_connectionDic objectForKey:socketId];
        //添加到点对点连接中
        [peerConnection addIceCandidate:candidate];
    }
    //2.其他新人加入房间的信息
    else if ([eventName isEqualToString:@"_new_peer"])
    {
        NSDictionary *dataDic = dic[@"data"];
        //拿到新人的ID
        NSString *socketId = dataDic[@"socketId"];
        
        //再去创建一个连接
        RTCPeerConnection *peerConnection = [self createPeerConnection:socketId];

        [self createLocalStream:^{
            //把本地流加到连接中去
            [peerConnection addStream:_localStream];
            //连接ID新加一个
            [_connectionIdArray addObject:socketId];
            //并且设置到Dic中去
            [_connectionDic setObject:peerConnection forKey:socketId];

            dispatch_async(dispatch_get_main_queue(), ^{
                //设置新加入用户代理
                if ([_friendDelegate respondsToSelector:@selector(webRTCHelper:gotNewFriend:)]) {
                    [_friendDelegate webRTCHelper:self gotNewFriend:socketId];
                }
            });
        }];
    }
    //有人离开房间的事件
    else if ([eventName isEqualToString:@"_remove_peer"])
    {
        //得到socketId，关闭这个peerConnection
        NSDictionary *dataDic = dic[@"data"];
        NSString *socketId = dataDic[@"socketId"];
        [self closePeerConnection:socketId];
        
        //设置关闭某个用户聊天代理回调
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self->_delegate respondsToSelector:@selector(webRTCHelper:closeWithUserId:)])
            {
                [self->_delegate webRTCHelper:self closeWithUserId:socketId];
            }
            //设置退出房间用户代理回调
            if ([self->_friendDelegate respondsToSelector:@selector(webRTCHelper:removeFriend:)]) {
                [self->_friendDelegate webRTCHelper:self removeFriend:socketId];
            }
        });
        
    }
    //这个新加入的人发了个offer
    else if ([eventName isEqualToString:@"_offer"])
    {
        NSDictionary *dataDic = dic[@"data"];
        NSDictionary *sdpDic = dataDic[@"sdp"];
        //拿到SDP
        NSString *sdp = sdpDic[@"sdp"];
        NSString *socketId = dataDic[@"socketId"];
        
        //拿到这个点对点的连接
        RTCPeerConnection *peerConnection = [_connectionDic objectForKey:socketId];
        //根据类型和SDP 生成SDP描述对象
        RTCSessionDescription *remoteSdp = [[RTCSessionDescription alloc] initWithType:RTCSdpTypeOffer sdp:sdp];
        //设置给这个点对点连接
        __weak RTCPeerConnection *weakPeerConnection = peerConnection;
        [weakPeerConnection setRemoteDescription:remoteSdp completionHandler:^(NSError * _Nullable error) {
            [self setSessionDescriptionWithPeerConnection:weakPeerConnection];
        }];
        
        //设置当前角色状态为被呼叫，（被发offer）
        //        _role = RoleCallee;
    }
    //回应offer
    else if ([eventName isEqualToString:@"_answer"])
    {
        NSDictionary *dataDic = dic[@"data"];
        NSDictionary *sdpDic = dataDic[@"sdp"];
        NSString *sdp = sdpDic[@"sdp"];
        //        NSString *type = sdpDic[@"type"];
        NSString *socketId = dataDic[@"socketId"];
        RTCPeerConnection *peerConnection = [_connectionDic objectForKey:socketId];
        RTCSessionDescription *remoteSdp = [[RTCSessionDescription alloc] initWithType:RTCSdpTypeAnswer sdp:sdp];
        __weak RTCPeerConnection * weakPeerConnection = peerConnection;
        [weakPeerConnection setRemoteDescription:remoteSdp completionHandler:^(NSError * _Nullable error) {
            [self setSessionDescriptionWithPeerConnection:weakPeerConnection];
        }];
    }
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket{
    NSLog(@"socket连接成功");
    [self joinRoom:_room];
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self->_delegate respondsToSelector:@selector(webRTCHelper:socketConnectState:)]) {
            [self->_delegate webRTCHelper:self socketConnectState:WebSocketConnectSuccess];
        }
    });
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error{
    NSLog(@"socket连接失败");
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self->_delegate respondsToSelector:@selector(webRTCHelper:socketConnectState:)]) {
            [self->_delegate webRTCHelper:self socketConnectState:WebSocketConnectSuccess];
        }
    });
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean{
    NSLog(@"socket关闭。code = %ld,reason = %@",code,reason);
}

- (NSString *)getKeyFromConnectionDic:(RTCPeerConnection *)peerConnection
{
    //find socketid by pc
    static NSString *socketId;
    [_connectionDic enumerateKeysAndObjectsUsingBlock:^(NSString *key, RTCPeerConnection *obj, BOOL * _Nonnull stop) {
        if ([obj isEqual:peerConnection])
        {
            NSLog(@"%@",key);
            socketId = key;
        }
    }];
    return socketId;
}


@end
