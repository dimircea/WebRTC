//
//  ChatViewController.m
//  WebRTC_new
//
//  Created by 胡志辉 on 2018/9/4.
//  Copyright © 2018年 Mr.hu. All rights reserved.
//

#import "ChatViewController.h"
#import <WebRTC/WebRTC.h>
#import "WebRTCHelper.h"
#import <HGAlertViewController/HGAlertViewController.h>

#define kWidth [UIScreen mainScreen].bounds.size.width
#define kHeight [UIScreen mainScreen].bounds.size.height

@interface ChatCell:UICollectionViewCell
/*注释*/
@property (nonatomic,strong)  RTCEAGLVideoView *videoView;
/*注释*/
@property (nonatomic, weak) RTCVideoTrack *track;
/*注释*/
@property (nonatomic,strong) CALayer *baseLayer;
@end

@implementation ChatCell


- (instancetype)init
{
    self = [super init];
    if (self) {
        self.videoView = [[RTCEAGLVideoView alloc] initWithFrame:CGRectMake(0, 0, (kWidth-40)/3, (kWidth-40)/3 + 50)];
        [self.contentView addSubview:self.videoView];
    }
    return self;
}
- (instancetype)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self) {
        self.contentView.layer.borderColor = [UIColor whiteColor].CGColor;
        self.contentView.layer.borderWidth = 1;
        self.videoView = [[RTCEAGLVideoView alloc] initWithFrame:CGRectMake(0, 0, (kWidth-40)/3, (kWidth-40)/3 + 50)];
        [self.contentView addSubview:self.videoView];
    }
    return self;
}

- (void)setTrack:(RTCVideoTrack *)track{
    if (track != nil) {
        self.contentView.layer.mask = nil;

        [_track removeRenderer:self.videoView]; //移除原来的渲染
        [track addRenderer:self.videoView];
    }else{
        [self setShaperLayer];

        NSLog(@"");
    }

    _track = track;
}


-(void)setShaperLayer{
    //高亮状态下的imageView
    UIImageView * highlightImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 50, 50)];
    highlightImageView.center = self.contentView.center;
    highlightImageView.image = [UIImage imageNamed:@"voice_ highlight"];
    //默认状态下的imageView
    UIImageView * defaultImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 50, 50)];
    defaultImageView.image = [UIImage imageNamed:@"voice_default"];
    //先添加highlightImageView,在添加defaultImageview
    defaultImageView.center = self.contentView.center;
//    [self.contentView addSubview:defaultImageView];
//    [self.contentView addSubview:highlightImageView];
    [self.contentView insertSubview:defaultImageView atIndex:0];
    [self.contentView insertSubview:highlightImageView atIndex:1];

    self.baseLayer = nil;
    if (self.baseLayer == nil) {
        self.baseLayer = [CALayer layer];
        self.baseLayer.frame = highlightImageView.bounds;
    }
    
    //创建左边layer
    CAShapeLayer * leftLayer = [CAShapeLayer layer];
    leftLayer.fillColor = [UIColor greenColor].CGColor;
    leftLayer.position = CGPointMake(-25, 25);
    leftLayer.bounds = highlightImageView.bounds;
    leftLayer.path = [UIBezierPath bezierPathWithRect:CGRectMake(0, 0, 50,50)].CGPath;
    [self.baseLayer addSublayer:leftLayer];
    
    //左边动画
    CABasicAnimation * leftAnimation = [CABasicAnimation animationWithKeyPath:@"position"];
    leftAnimation.fromValue = [NSValue valueWithCGPoint:CGPointMake(-25, 25)];
    leftAnimation.toValue = [NSValue valueWithCGPoint:CGPointMake(5, 25)];
    leftAnimation.duration = 1.0;
    leftAnimation.repeatCount = MAXFLOAT;
    [leftLayer addAnimation:leftAnimation forKey:@"noVoiceLeftAnimation"];
    

    //创建右边layer
    CAShapeLayer * rightLayer = [CAShapeLayer layer];
//    rightLayer.strokeColor = [UIColor greenColor].CGColor;
    rightLayer.bounds = highlightImageView.bounds;
    rightLayer.position = CGPointMake(75, 25);
    rightLayer.fillColor = [UIColor greenColor].CGColor;
    rightLayer.path = [UIBezierPath bezierPathWithRect:CGRectMake(0, 0, 50, 50)].CGPath;
    [self.baseLayer addSublayer:rightLayer];
    //动画
    CABasicAnimation * rightAnimation = [CABasicAnimation animationWithKeyPath:@"position"];
    rightAnimation.duration = 1.0;
    rightAnimation.fromValue = [NSValue valueWithCGPoint:CGPointMake(75, 25)];
    rightAnimation.toValue = [NSValue valueWithCGPoint:CGPointMake(45, 25)];
    rightAnimation.repeatCount = MAXFLOAT;
    [rightLayer addAnimation:rightAnimation forKey:@"noVoiceRightAnimation"];
    
    
    highlightImageView.layer.mask = self.baseLayer;
    
    
}

@end


@interface ChatViewController ()<UICollectionViewDelegate,UICollectionViewDataSource,WebRTCHelperDelegate,WebRTCHelperFrindDelegate>
{
    RTCMediaStream * _localSteam;
    RTCVideoTrack *_track;
}
@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
/*保存远端视频流*/
@property (nonatomic,strong) NSMutableDictionary *videoTracks;
/*房间内其他用户*/
@property (nonatomic,strong) NSMutableArray *members;
//显示本地视频的view
@property (weak, nonatomic) IBOutlet RTCCameraPreviewView *localVideoView;

@end

@implementation ChatViewController

/*注释*/
- (NSMutableArray *)members
{
    if(!_members){
        _members = [NSMutableArray array];
    }
    return _members;
}

/*注释*/
- (NSMutableDictionary *)videoTracks
{
    if(!_videoTracks){
        _videoTracks = [NSMutableDictionary dictionary];
    }
    return _videoTracks;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    NSLog(@"uid = %@",[[[UIDevice currentDevice] identifierForVendor] UUIDString]);
    [WebRTCHelper shareInstance].delegate = self;
    [WebRTCHelper shareInstance].friendDelegate = self;
    
    UICollectionViewFlowLayout * layout = [[UICollectionViewFlowLayout alloc] init];
    layout.minimumLineSpacing = 10;
    layout.minimumInteritemSpacing = 10;
    layout.itemSize = CGSizeMake((kWidth-40)/3, (kWidth-40)/3+50);
    self.collectionView.collectionViewLayout = layout;
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    [self.collectionView registerClass:[ChatCell class] forCellWithReuseIdentifier:@"chatCell"];
    
//    [self connect];

}

#pragma mark -按钮点击操作
/**
 * 关闭按钮
 */
- (IBAction)closeChatBtnClick:(UIButton *)sender {
    [[WebRTCHelper shareInstance] exitRoom];
    [self.navigationController popViewControllerAnimated:YES];
}

/**
 * 摄像头转换（前后摄像头）
 */
- (IBAction)swithVideoBtnClick:(UIButton *)sender {
    [[WebRTCHelper shareInstance] showLocaolCamera];
}

/**
 * 语音是否开启
 */
- (IBAction)swichAudioBtnClick:(UIButton *)sender {
    NSLog(@"");
}

- (void)reloadRemoteView {
//    [self.videoTracks.allValues enumerateObjectsUsingBlock:^(RTCVideoTrack *track, NSUInteger idx, BOOL * _Nonnull stop) {
//
//    }];
    [self.collectionView reloadData];
}

/**
 * 连接服务器
 */
-(void)connect{
    [[WebRTCHelper shareInstance] connectServer:@"192.168.30.179" port:@"3000" room:@"100"];
//    [[WebRTCHelper shareInstance] connectServer:@"115.236.101.203" port:@"18080" room:@"100"];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    return self.members.count;
}
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath{
    ChatCell * cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"chatCell" forIndexPath:indexPath];
    NSString * userId = [self.members objectAtIndex:indexPath.item];
    RTCVideoTrack * track = [self.videoTracks objectForKey:userId];
    cell.track = track;
    return cell;
}

#pragma mark -WebRTCHelperFrindDelegate
- (void)webRTCHelper:(WebRTCHelper *)webRTCHelper gotFriendList:(NSArray *)friendList{
    [self.members removeAllObjects];
    [self.members addObjectsFromArray:friendList];
    [_collectionView reloadData];
}

- (void)webRTCHelper:(WebRTCHelper *)webRTCHelper gotNewFriend:(NSString *)friendId{
    [self.members addObject:friendId];
    [_collectionView reloadData];
}

- (void)webRTCHelper:(WebRTCHelper *)webRTCHelper removeFriend:(NSString *)friendId{
    [self.members removeObject:friendId];
    [_collectionView reloadData];
    if (self.members.count == 0) {
        [[WebRTCHelper shareInstance] exitRoom];
        [self.navigationController popViewControllerAnimated:YES];
    }
}

#pragma mark -WebRTCHelperDelegate
- (void)webRTCHelper:(WebRTCHelper *)webRTCHelper receiveMessage:(NSString *)message{
    NSLog(@"messaga = %@",message);
    
}

/**
 * 旧版本获取本地视频流的代理，在这个代理里面会获取到RTCVideoTrack类，然后添加到RTCEAGLVideoView类型的localVideoView上面
 */
- (void)webRTCHelper:(WebRTCHelper *)webRTCHelper setLocalStream:(RTCMediaStream *)steam userId:(NSString *)userId{
    if (steam) {
        _localSteam = steam;
        _track = [_localSteam.videoTracks lastObject];

//        [track addRenderer:self.localVideoView];
//        [track addRenderer:self.glVideoView];
    }
    
}
/**
 * 新版获取本地视频流的方法
 * @param captureSession RTCCameraPreviewView类的参数，通过设置这个，就可以达到显示本地视频的功能
 */
- (void)webRTCHelper:(WebRTCHelper *)webRTCHelper capturerSession:(AVCaptureSession *)captureSession{
    self.localVideoView.captureSession = captureSession;
}

/**
 * 获取远端视频流的方法，主要是获取到RTCVideoTrack类型的数据，然后保存起来，在刷新列表的时候，添加到对应item里面的RTCEAGLVideoView类型的view上面
 */
- (void)webRTCHelper:(WebRTCHelper *)webRTCHelper addRemoteStream:(RTCMediaStream *)stream userId:(NSString *)userId{
    RTCVideoTrack * track = [stream.videoTracks lastObject];
    if (track != nil) {
        [self.videoTracks setObject:track forKey:userId];
//        [track addRenderer:self.localVideoView];
    }
        [self reloadRemoteView];
}

- (void)webRTCHelper:(WebRTCHelper *)webRTCHelper closeWithUserId:(NSString *)userId{
    [self.videoTracks removeObjectForKey:userId];
    if (self.videoTracks.count >= self.members.count) {
        [self reloadRemoteView];
    }
}

- (void)webRTCHelper:(WebRTCHelper *)webRTCHelper socketConnectState:(WebSocketConnectState)connectState{
    if (connectState == WebSocketConnectField) {
        HGAlertViewController * alert = [HGAlertViewController alertControllerWithTitle:@"提示" message:@"连接socket失败" preferredStyle:(UIAlertControllerStyleAlert)];
        alert.addAction(@"取消",^(UIAlertAction *alertAction){
            [[WebRTCHelper shareInstance] exitRoom];
            [self.navigationController popViewControllerAnimated:YES];
        }).addAction(@"确定",^(UIAlertAction *alertAction){
            [[WebRTCHelper shareInstance] exitRoom];
            [self.navigationController popViewControllerAnimated:YES];
        });
        [self presentViewController:alert animated:YES completion:nil];
    }
}


@end
