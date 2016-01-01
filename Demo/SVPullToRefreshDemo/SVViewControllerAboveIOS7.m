//
//  SVViewControllerAboveIOS7.m
//  SVPullToRefreshDemo
//
//  Created by KudoCC on 16/1/1.
//  Copyright © 2016年 https://github.com/kudocc. All rights reserved.
//

#import "SVViewControllerAboveIOS7.h"
#import "SVPullToRefresh.h"

@implementation SVViewControllerAboveIOS7

static NSString *const identifier = @"identifier";

- (void)initView {
    self.edgesForExtendedLayout = UIRectEdgeAll;
    self.automaticallyAdjustsScrollViewInsets = NO;
    
    CGSize size = CGSizeMake(ScreenWidth, ScreenHeight);
    _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0.0, 0.0, size.width, size.height) style:UITableViewStylePlain];
    [self.view addSubview:_tableView];
    _tableView.contentInset = UIEdgeInsetsMake(StateBarHeight+NavigationBarHeight, 0.0, TabBarHeight, 0.0);
    _tableView.scrollIndicatorInsets = _tableView.contentInset;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.tableFooterView = [UIView new];
    [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:identifier];
    
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 20.0, 20.)];
    [_tableView addSubview:v];
    v.backgroundColor = [UIColor redColor];
    
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
        [_tableView.pullToRefreshViewTop performSelector:@selector(stopAnimating) withObject:nil afterDelay:3.0];
    } else {
        [_tableView.pullToRefreshViewBottom performSelector:@selector(stopAnimating) withObject:nil afterDelay:3.0];
    }
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
