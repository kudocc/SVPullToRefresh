//
//  SVViewController.m
//  SVPullToRefreshDemo
//
//  Created by Sam Vermette on 23.04.12.
//  Copyright (c) 2012 Home. All rights reserved.
//

#import "SVViewController.h"
#import "SVPullToRefresh.h"

@interface UIPullToRefreshCustomView : UIView <SVPullToRefreshCustomViewProtocol>
@property (nonatomic, strong) UIActivityIndicatorView *animateView;
@end

@implementation UIPullToRefreshCustomView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor grayColor];
        _animateView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        _animateView.center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
        [self addSubview:_animateView];
    }
    return self;
}

- (void)customViewShouldBeginAnimating {
    [_animateView startAnimating];
}

- (void)customViewShouldStopAnimating {
    [_animateView stopAnimating];
}

@end

@interface SVViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) NSMutableArray *dataSource;

@end

@implementation SVViewController

@synthesize tableView = tableView;

- (void)viewDidLoad {
    [super viewDidLoad];
//    self.automaticallyAdjustsScrollViewInsets = NO;
    NSLog(@"%@, %@", NSStringFromSelector(_cmd), NSStringFromCGRect(self.view.frame));
    tableView = [[UITableView alloc] initWithFrame:CGRectMake(0.0, 0.0, CGRectGetWidth(self.view.bounds), CGRectGetHeight(self.view.bounds)) style:UITableViewStylePlain];
    [self.view addSubview:tableView];
    tableView.delegate = self;
    tableView.dataSource = self;
    
    [self setupDataSource];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
//    [tableView triggerPullToRefreshTop];
}

- (void)viewDidLayoutSubviews {
    NSLog(@"%@, %@", NSStringFromSelector(_cmd), NSStringFromCGRect(self.view.frame));
    
    __weak SVViewController *weakSelf = self;
    // setup pull-to-refresh
    [self.tableView addPullToRefreshWithActionHandler:^{
        [weakSelf insertRowAtTop];
    } position:SVPullToRefreshPositionTop];
    
    UIPullToRefreshCustomView *customView = [[UIPullToRefreshCustomView alloc] initWithFrame:CGRectMake(0.0, 0.0, CGRectGetWidth(self.view.frame), SVPullToRefreshViewHeight)];
    [self.tableView.pullToRefreshViewTop setCustomView:customView
                                              forState:SVPullToRefreshStateLoading];
    [self.tableView addPullToRefreshWithActionHandler:^{
        [weakSelf insertRowAtBottom];
    } position:SVPullToRefreshPositionBottom];
    
    // setup infinite scrolling
//    [self.tableView addInfiniteScrollingWithActionHandler:^{
//        [weakSelf insertRowAtBottom];
//    }];
}

#pragma mark - Actions

- (void)setupDataSource {
    self.dataSource = [NSMutableArray array];
    for(int i=0; i<15; i++)
        [self.dataSource addObject:[NSDate dateWithTimeIntervalSinceNow:-(i*90)]];
}

- (void)insertRowAtTop {
    __weak SVViewController *weakSelf = self;

    int64_t delayInSeconds = 2.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [weakSelf.tableView beginUpdates];
        [weakSelf.dataSource insertObject:[NSDate date] atIndex:0];
        [weakSelf.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:0]] withRowAnimation:UITableViewRowAnimationBottom];
        [weakSelf.tableView endUpdates];
        [weakSelf.tableView.pullToRefreshViewTop stopAnimating];
    });
}


- (void)insertRowAtBottom {
    __weak SVViewController *weakSelf = self;

    int64_t delayInSeconds = 2.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [weakSelf.tableView beginUpdates];
        [weakSelf.dataSource addObject:[weakSelf.dataSource.lastObject dateByAddingTimeInterval:-90]];
        [weakSelf.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:weakSelf.dataSource.count-1 inSection:0]] withRowAnimation:UITableViewRowAnimationTop];
        [weakSelf.tableView endUpdates];
        
        [weakSelf.tableView.pullToRefreshViewBottom stopAnimating];
    });
}
#pragma mark -
#pragma mark UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.dataSource.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"Cell";
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:identifier];
    
    if (cell == nil)
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    
    NSDate *date = [self.dataSource objectAtIndex:indexPath.row];
    cell.textLabel.text = [NSDateFormatter localizedStringFromDate:date dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterMediumStyle];
    return cell;
}

@end
