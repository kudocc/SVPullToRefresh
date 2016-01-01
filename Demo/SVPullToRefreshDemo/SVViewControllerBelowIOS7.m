//
//  SVViewControllerBelowIOS7.m
//  SVPullToRefreshDemo
//
//  Created by KudoCC on 16/1/1.
//  Copyright © 2016年 https://github.com/kudocc. All rights reserved.
//

#import "SVViewControllerBelowIOS7.h"
#import "SVPullToRefresh.h"

@implementation SVViewControllerBelowIOS7

static NSString *const identifier = @"identifier";

- (void)initView {
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.automaticallyAdjustsScrollViewInsets = NO;
    
    CGSize size = CGSizeMake(ScreenWidth, ScreenHeight-StateBarHeight-NavigationBarHeight-TabBarHeight);
    _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0.0, 0.0, size.width, size.height) style:UITableViewStylePlain];
    [self.view addSubview:_tableView];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.tableFooterView = [UIView new];
    [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:identifier];
    
    __weak typeof(self) wself = self;
    [_tableView addPullToRefreshWithActionHandler:^{
        [wself loadData:YES];
    } position:SVPullToRefreshPositionTop];
    
    [_tableView addPullToRefreshWithActionHandler:^{
        [wself loadData:NO];
    } position:SVPullToRefreshPositionBottom];
}

- (void)loadData:(BOOL)refresh {
    if (refresh) {
        [self performSelector:@selector(delay) withObject:nil afterDelay:5.0];
    } else {
        [_tableView.pullToRefreshViewBottom performSelector:@selector(stopAnimating) withObject:nil afterDelay:5.0];
    }
}

- (void)delay {
    [_tableView.pullToRefreshViewTop stopAnimating];
//    [_tableView performSelector:@selector(triggerPullToRefreshTop) withObject:nil afterDelay:0.0];
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44.0;
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
#if ContentFillScreen
    return 20;
#else
    return 4;
#endif
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier forIndexPath:indexPath];
    cell.textLabel.text = [NSString stringWithFormat:@"%ld", (long)indexPath.row];
    return cell;
}

@end
