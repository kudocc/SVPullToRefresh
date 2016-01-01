//
//  SVBaseViewController.h
//  SVPullToRefreshDemo
//
//  Created by KudoCC on 16/1/1.
//  Copyright © 2016年 https://github.com/kudocc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SVMacroDefine.h"

@interface SVBaseViewController : UIViewController

@end

@interface SVBaseViewController (override_method)

- (void)initView;
- (void)initData;

@end
