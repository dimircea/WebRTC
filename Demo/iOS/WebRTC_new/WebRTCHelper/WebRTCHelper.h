//
//  WebRTCHelper.h
//  WebRTC_new
//
//  Created by 胡志辉 on 2018/9/4.
//  Copyright © 2018年 Mr.hu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebRTC/WebRTC.h>
#import <SocketRocket/SocketRocket.h>

//@import SocketIO;

typedef enum : NSUInteger {
    WebSocketConnectSuccess = 0,
    WebSocketConnectField,
    WebSocketConnectClosed,
} WebSocketConnectState;

@protocol WebRTCHelperDelegate;
@protocol WebRTCHelperFrindDelegate;

@interface WebRTCHelper : NSObject

/**
 * 单例
 */
+(instancetype)shareInstance;

/*注释*/
@property (nonatomic,weak) id<WebRTCHelperDelegate> delegate;
/*注释*/
@property (nonatomic,weak) id<WebRTCHelperFrindDelegate> friendDelegate;

/**
 * 与服务器建立连接
 * @param server 服务器地址
 * @param port 端口号
 * @param room 房间号
 */
-(void)connectServer:(NSString *)server port:(NSString *)port room:(NSString *)room;
/**
 * 切换摄像头
 */
-(void)swichCamera;
/**
 * 是否显示本地视频
 */
-(void)showLocaolCamera;
/**
 * 退出房间
 */
-(void)exitRoom;

@end

@protocol WebRTCHelperDelegate <NSObject>
@optional
/**
 * 获取到发送信令消息
 * @param webRTCHelper 本类
 * @param message 消息内容
 */
-(void)webRTCHelper:(WebRTCHelper *)webRTCHelper receiveMessage:(NSString *)message;
/**
 * 获取本地的localVideoStream数据
 * @param webRTCHelper 本类
 * @param steam 视频流
 * @param userId 用户标识
 */
-(void)webRTCHelper:(WebRTCHelper *)webRTCHelper setLocalStream:(RTCMediaStream *)steam userId:(NSString *)userId;
/**
 * 获取远程的remoteVideoStream数据
 * @param webRTCHelper 本类
 * @param stream 视频流
 * @param userId 用户标识
 */
-(void)webRTCHelper:(WebRTCHelper *)webRTCHelper addRemoteStream:(RTCMediaStream *)stream userId:(NSString *)userId;
/**
 * 某个用户退出后，关闭用户的连接
 * @param webRTCHelper 本类
 * @param userId 用户标识
 */
- (void)webRTCHelper:(WebRTCHelper *)webRTCHelper closeWithUserId:(NSString *)userId;

/**
 * 获取socket连接状态
 * @param webRTCHelper 本类
 * @param connectState 连接状态，分为
 WebSocketConnectSuccess 成功,
 WebSocketConnectField, 失败
 WebSocketConnectClosed 关闭
 */
-(void)webRTCHelper:(WebRTCHelper *)webRTCHelper socketConnectState:(WebSocketConnectState)connectState;
-(void)webRTCHelper:(WebRTCHelper *)webRTCHelper capturerSession:(AVCaptureSession *)captureSession;
@end

@protocol WebRTCHelperFrindDelegate <NSObject>
@optional
/**
 * 获取房间内所有的用户（除了自己）
 * @param friendList 用户列表
 */
-(void)webRTCHelper:(WebRTCHelper *)webRTCHelper gotFriendList:(NSArray *)friendList;
/**
 * 获取新加入的用户信息
 * @param friendId 新用户的id
 */
-(void)webRTCHelper:(WebRTCHelper *)webRTCHelper gotNewFriend:(NSString *)friendId;
/**
 * 获取离开房间用户的信息
 * @param friendId 离开用户的ID
 */
-(void)webRTCHelper:(WebRTCHelper *)webRTCHelper removeFriend:(NSString *)friendId;
@end


















