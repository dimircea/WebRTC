//
//  FriendListViewController.m
//  WebRTC_new
//
//  Created by 胡志辉 on 2018/9/5.
//  Copyright © 2018年 Mr.hu. All rights reserved.
//

#import "FriendListViewController.h"
#import <WebRTC/WebRTC.h>
#import "WebRTCHelper.h"

@interface FriendListViewController ()<UITableViewDelegate,UITableViewDataSource,WebRTCHelperFrindDelegate>
@property (weak, nonatomic) IBOutlet UITableView *tableView;

/*注释*/
@property (nonatomic,strong) NSMutableArray *members;


@end

@implementation FriendListViewController

/*注释*/
- (NSMutableArray *)members
{
    if(!_members){
        _members = [NSMutableArray array];
    }
    return _members;
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    self.navigationController.navigationBar.hidden = NO;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [WebRTCHelper shareInstance].friendDelegate = self;
    
    self.tableView.tableFooterView = [UIView new];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"friendListCell"];
    [self connect];
}

/**
 * 连接服务器
 */
- (void)connect{
    [[WebRTCHelper shareInstance] connectServer:@"192.168.30.186" port:@"3000" room:@"100"];
}


#pragma mark -UITableViewDelegate & UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return self.members.count;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"friendListCell" forIndexPath:indexPath];
    cell.textLabel.text = self.members[indexPath.row];
    return cell;
}

#pragma mark -WebRTCHelperFriendDelegate
//获取房间内所有用户的列表
- (void)webRTCHelper:(WebRTCHelper *)webRTCHelper gotFriendList:(NSArray *)friendList{
    [self.members removeAllObjects];
    [self.members addObjectsFromArray:friendList];
    [self.tableView reloadData];
}
//获取新加入房间的用户
- (void)webRTCHelper:(WebRTCHelper *)webRTCHelper gotNewFriend:(NSString *)friendId{
    [self.members addObject:friendId];
    [self.tableView reloadData];
}
//获取退出房间的用户
- (void)webRTCHelper:(WebRTCHelper *)webRTCHelper removeFriend:(NSString *)friendId{
    [self.members removeObject:friendId];
    [self.tableView reloadData];
}

@end
