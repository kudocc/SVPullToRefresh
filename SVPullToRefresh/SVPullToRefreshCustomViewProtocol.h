//
//  SVPullToRefreshCustomViewProtocol.h
//  SVPullToRefreshDemo
//
//  Created by KudoCC on 15/8/22.
//  Copyright (c) 2015年 Home. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol SVPullToRefreshCustomViewProtocol <NSObject>
@optional
- (void)customViewShouldBeginAnimating;
- (void)customViewShouldStopAnimating;
@end
