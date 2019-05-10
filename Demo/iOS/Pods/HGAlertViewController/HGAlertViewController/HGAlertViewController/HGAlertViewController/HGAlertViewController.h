//
//  HGAlertViewController.h
//  RAC-ReactiveCocoa
//
//  Created by 胡志辉 on 2018/7/24.
//  Copyright © 2018年 胡志辉. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface HGAlertViewController : UIAlertController
-(HGAlertViewController * (^)(NSString *actionName,void(^)(UIAlertAction *action)))addAction;
- (HGAlertViewController *(^)(NSString *placeHolder,void(^)(UITextField *textField)))addInput;
@end
