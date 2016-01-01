//
//  SVViewControllerBelowIOS7.h
//  SVPullToRefreshDemo
//
//  Created by KudoCC on 16/1/1.
//  Copyright © 2016年 https://github.com/kudocc. All rights reserved.
//

#import "SVBaseViewController.h"

@interface SVViewControllerBelowIOS7 : SVBaseViewController <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;

@end
