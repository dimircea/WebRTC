//
//  HGAlertViewController.m
//  RAC-ReactiveCocoa
//
//  Created by 胡志辉 on 2018/7/24.
//  Copyright © 2018年 胡志辉. All rights reserved.
//

#import "HGAlertViewController.h"

@interface HGAlertViewController ()

@end

@implementation HGAlertViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
//    UIAlertAction * action = [UIAlertAction actionWithTitle:@"" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
//        
//    }];
//    self.addAction(action);
}

-(HGAlertViewController *(^)( NSString *actionName,void(^)(UIAlertAction *action)))addAction{
    HGAlertViewController *(^addActionBlock)(NSString * actionName,void(^)(UIAlertAction *action)) = ^(NSString * actionName,void(^neibublock)(UIAlertAction *action)){
        UIAlertAction * action;
        if ([actionName isEqualToString:@"取消"] || [actionName isEqualToString:@"cancel"]) {
            action = [UIAlertAction actionWithTitle:actionName style:(UIAlertActionStyleCancel) handler:^(UIAlertAction * _Nonnull action) {
                if (neibublock) {
                    neibublock(action);
                }
            }];
        }else if ([actionName isEqualToString:@"重置"] || [actionName isEqualToString:@"reset"] || [actionName isEqualToString:@"reSet"]){
         
            action = [UIAlertAction actionWithTitle:actionName style:(UIAlertActionStyleDestructive) handler:^(UIAlertAction * _Nonnull action) {
                
                if (neibublock) {
                    neibublock(action);
                }
            }];
            
        }else{
            action = [UIAlertAction actionWithTitle:actionName style:(UIAlertActionStyleDefault) handler:^(UIAlertAction * _Nonnull action) {
                if (neibublock) {
                    neibublock(action);
                }
            }];
        }
        [self addAction:action];
        return self;
    };
    return addActionBlock;
}

- (HGAlertViewController *(^)(NSString *placeHolder, void (^)(UITextField *)))addInput{
    HGAlertViewController * (^inputBlock)(NSString *placeHolder,void (^)(UITextField *textField)) = ^(NSString * placeHolder,void(^neibublock)(UITextField * textField)){
        [self addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            textField.placeholder = placeHolder;
            if (neibublock) {
                neibublock(textField);
            }
        }];
        return self;
    };
    return inputBlock;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
