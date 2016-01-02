//
// UIScrollView+SVPullToRefresh.m
//
// Created by Sam Vermette on 23.04.12.
// Copyright (c) 2012 samvermette.com. All rights reserved.
//
// https://github.com/samvermette/SVPullToRefresh
//

#import <QuartzCore/QuartzCore.h>
#import "UIScrollView+SVPullToRefresh.h"
#import "SVPullToRefreshCustomViewProtocol.h"

//fequal() and fequalzro() from http://stackoverflow.com/a/1614761/184130
#define fequal(a,b) (fabs((a) - (b)) < FLT_EPSILON)
#define fequalzero(a) (fabs(a) < FLT_EPSILON)

CGFloat const SVPullToRefreshViewHeight = 60;

@interface SVPullToRefreshArrow : UIView

@property (nonatomic, strong) UIColor *arrowColor;

@end


@interface SVPullToRefreshView ()

@property (nonatomic, copy) void (^pullToRefreshActionHandler)(void);

@property (nonatomic, strong) SVPullToRefreshArrow *arrow;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicatorView;
@property (nonatomic, strong, readwrite) UILabel *titleLabel;
@property (nonatomic, strong, readwrite) UILabel *subtitleLabel;
@property (nonatomic, readwrite) SVPullToRefreshState state;
@property (nonatomic, readwrite) SVPullToRefreshPosition position;

@property (nonatomic, strong) NSMutableArray *titles;
@property (nonatomic, strong) NSMutableArray *subtitles;
@property (nonatomic, strong) NSMutableArray *viewForState;

@property (nonatomic, weak) UIScrollView *scrollView;
@property (nonatomic, readwrite) CGFloat originalTopInset;
@property (nonatomic, readwrite) CGFloat originalBottomInset;

@property (nonatomic, assign) BOOL wasTriggeredByUser;
@property (nonatomic, assign) BOOL showsPullToRefresh;
@property (nonatomic, assign) BOOL showsDateLabel;
@property(nonatomic, assign) BOOL isObserving;

- (void)resetScrollViewContentInset;
- (void)setScrollViewContentInsetForLoading;
- (void)setScrollViewContentInset:(UIEdgeInsets)insets;
- (void)rotateArrow:(float)degrees hide:(BOOL)hide;

@end



#pragma mark - UIScrollView (SVPullToRefresh)
#import <objc/runtime.h>

static char UIScrollViewPullToRefreshViewTop;
static char UIScrollViewPullToRefreshViewBottom;

@implementation UIScrollView (SVPullToRefresh)

@dynamic showsPullToRefreshTop, showsPullToRefreshBottom, pullToRefreshViewTop, pullToRefreshViewBottom;

- (CGFloat)originalYOfPosition:(SVPullToRefreshPosition)position {
    if (position == SVPullToRefreshPositionTop) {
        return -SVPullToRefreshViewHeight;
    } else {
        if (self.contentSize.height < self.frame.size.height - self.contentInset.top - self.contentInset.bottom) {
            return self.frame.size.height - self.contentInset.top - self.contentInset.bottom;
        } else {
            return self.contentSize.height;
        }
    }
}

- (void)addPullToRefreshWithActionHandler:(void (^)(void))actionHandler position:(SVPullToRefreshPosition)position {
    BOOL createNew = NO;
    if (position == SVPullToRefreshPositionTop) {
        createNew = self.pullToRefreshViewTop == nil;
    } else {
        createNew = self.pullToRefreshViewBottom == nil;
    }
    if(createNew) {
        CGFloat yOrigin = [self originalYOfPosition:position];
        SVPullToRefreshView *view = [[SVPullToRefreshView alloc] initWithFrame:CGRectMake(0, yOrigin, self.bounds.size.width, SVPullToRefreshViewHeight)];
        view.pullToRefreshActionHandler = actionHandler;
        view.scrollView = self;
        [self addSubview:view];
        view.originalTopInset = self.contentInset.top;
        view.originalBottomInset = self.contentInset.bottom;
        view.position = position;
        if (position == SVPullToRefreshPositionTop) {
            self.pullToRefreshViewTop = view;
            self.showsPullToRefreshTop = YES;
        } else {
            self.pullToRefreshViewBottom = view;
            self.showsPullToRefreshBottom = YES;
        }
    }
}

- (void)triggerPullToRefreshTop {
    self.pullToRefreshViewTop.state = SVPullToRefreshStateTriggered;
    [self.pullToRefreshViewTop startAnimating];
}

- (void)triggerPullToRefreshBottom {
    self.pullToRefreshViewBottom.state = SVPullToRefreshStateTriggered;
    [self.pullToRefreshViewBottom startAnimating];
}

- (void)setPullToRefreshViewTop:(SVPullToRefreshView *)pullToRefreshView {
    [self willChangeValueForKey:@"SVPullToRefreshViewTop"];
    objc_setAssociatedObject(self, &UIScrollViewPullToRefreshViewTop,
                             pullToRefreshView,
                             OBJC_ASSOCIATION_ASSIGN);
    [self didChangeValueForKey:@"SVPullToRefreshViewTop"];
}

- (void)setPullToRefreshViewBottom:(SVPullToRefreshView *)pullToRefreshView {
    [self willChangeValueForKey:@"SVPullToRefreshViewBottom"];
    objc_setAssociatedObject(self, &UIScrollViewPullToRefreshViewBottom,
                             pullToRefreshView,
                             OBJC_ASSOCIATION_ASSIGN);
    [self didChangeValueForKey:@"SVPullToRefreshViewBottom"];
}

- (SVPullToRefreshView *)pullToRefreshViewTop {
    return objc_getAssociatedObject(self, &UIScrollViewPullToRefreshViewTop);
}

- (SVPullToRefreshView *)pullToRefreshViewBottom {
    return objc_getAssociatedObject(self, &UIScrollViewPullToRefreshViewBottom);
}

- (void)setShowsPullToRefreshTop:(BOOL)showsPullToRefreshTop {
    [self setShowsPullToRefresh:showsPullToRefreshTop refreshView:self.pullToRefreshViewTop];
}

- (void)setShowsPullToRefreshBottom:(BOOL)showsPullToRefreshBottom {
    [self setShowsPullToRefresh:showsPullToRefreshBottom refreshView:self.pullToRefreshViewBottom];
}

- (void)setShowsPullToRefresh:(BOOL)showsPullToRefresh refreshView:(SVPullToRefreshView *)pullToRefreshView {
    pullToRefreshView.hidden = !showsPullToRefresh;
    
    if(!showsPullToRefresh) {
        if (pullToRefreshView.isObserving) {
            [self removeObserver:pullToRefreshView forKeyPath:@"contentOffset"];
            [self removeObserver:pullToRefreshView forKeyPath:@"contentSize"];
            [self removeObserver:pullToRefreshView forKeyPath:@"frame"];
            [pullToRefreshView resetScrollViewContentInset];
            pullToRefreshView.isObserving = NO;
        }
    }
    else {
        if (!pullToRefreshView.isObserving) {
            [self addObserver:pullToRefreshView forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:nil];
            [self addObserver:pullToRefreshView forKeyPath:@"contentSize" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:nil];
            [self addObserver:pullToRefreshView forKeyPath:@"frame" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:nil];
            pullToRefreshView.isObserving = YES;
            
            CGFloat yOrigin = [self originalYOfPosition:pullToRefreshView.position];
            pullToRefreshView.frame = CGRectMake(0, yOrigin, self.bounds.size.width, SVPullToRefreshViewHeight);
        }
    }
}

- (BOOL)showsPullToRefreshTop {
    return !self.pullToRefreshViewTop.hidden;
}

- (BOOL)showsPullToRefreshBottom {
    return !self.pullToRefreshViewBottom.hidden;
}

@end

#pragma mark - SVPullToRefresh
@implementation SVPullToRefreshView

// public properties
@synthesize pullToRefreshActionHandler, arrowColor, textColor, activityIndicatorViewColor, activityIndicatorViewStyle, lastUpdatedDate, dateFormatter;

@synthesize state = _state;
@synthesize scrollView = _scrollView;
@synthesize showsPullToRefresh = _showsPullToRefresh;
@synthesize arrow = _arrow;
@synthesize activityIndicatorView = _activityIndicatorView;

@synthesize titleLabel = _titleLabel;
@synthesize dateLabel = _dateLabel;


- (id)initWithFrame:(CGRect)frame {
    if(self = [super initWithFrame:frame]) {
        
        // default styling values
        self.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
        self.textColor = [UIColor darkGrayColor];
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.state = SVPullToRefreshStateStopped;
        self.showsDateLabel = NO;
        
        self.titles = [NSMutableArray arrayWithObjects:NSLocalizedString(@"Pull to refresh...",),
                             NSLocalizedString(@"Release to refresh...",),
                             NSLocalizedString(@"Loading...",),
                                nil];
        
        self.subtitles = [NSMutableArray arrayWithObjects:@"", @"", @"", @"", nil];
        self.viewForState = [NSMutableArray arrayWithObjects:@"", @"", @"", @"", nil];
        self.wasTriggeredByUser = YES;
    }
    
    return self;
}

- (void)willMoveToSuperview:(UIView *)newSuperview {
    if (self.superview && newSuperview == nil) {
        //use self.superview, not self.scrollView. Why self.scrollView == nil here?
        UIScrollView *scrollView = (UIScrollView *)self.superview;
        if (self.isObserving) {
            //If enter this branch, it is the moment just before "SVPullToRefreshView's dealloc", so remove observer here
            [scrollView removeObserver:self forKeyPath:@"contentOffset"];
            [scrollView removeObserver:self forKeyPath:@"contentSize"];
            [scrollView removeObserver:self forKeyPath:@"frame"];
            self.isObserving = NO;
        }
    }
}

- (void)layoutSubviews {
    
    UIView<SVPullToRefreshCustomViewProtocol> *customView = [self.viewForState objectAtIndex:self.state];
    BOOL hasCustomView = [customView isKindOfClass:[UIView class]];
    if(hasCustomView) {
        [self addSubview:customView];
        CGRect viewBounds = [customView bounds];
        CGPoint origin = CGPointMake(roundf((self.bounds.size.width-viewBounds.size.width)/2), roundf((self.bounds.size.height-viewBounds.size.height)/2));
        [customView setFrame:CGRectMake(origin.x, origin.y, viewBounds.size.width, viewBounds.size.height)];
    }
    else {
        CGFloat leftViewWidth = MAX(self.arrow.bounds.size.width,self.activityIndicatorView.bounds.size.width);
        
        CGFloat margin = 10;
        CGFloat marginY = 2;
        CGFloat labelMaxWidth = self.bounds.size.width - margin - leftViewWidth;
        
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_7_0
        CGRect titleRect = [self.titleLabel.text boundingRectWithSize:CGSizeMake(labelMaxWidth,self.titleLabel.font.lineHeight)
                                                              options:NSStringDrawingUsesLineFragmentOrigin
                                                           attributes:@{NSFontAttributeName:self.titleLabel.font}
                                                              context:nil];
        CGSize titleSize = titleRect.size;
        CGRect subtitleRect = [self.subtitleLabel.text boundingRectWithSize:CGSizeMake(labelMaxWidth,self.subtitleLabel.font.lineHeight)
                                                                    options:NSStringDrawingUsesLineFragmentOrigin
                                                                 attributes:@{NSFontAttributeName:self.subtitleLabel.font}
                                                                    context:nil];
        CGSize subtitleSize = subtitleRect.size;
#else
        CGSize titleSize = [self.titleLabel.text sizeWithFont:self.titleLabel.font
                                            constrainedToSize:CGSizeMake(labelMaxWidth,self.titleLabel.font.lineHeight)
                                                lineBreakMode:self.titleLabel.lineBreakMode];
        
        
        CGSize subtitleSize = [self.subtitleLabel.text sizeWithFont:self.subtitleLabel.font
                                                  constrainedToSize:CGSizeMake(labelMaxWidth,self.subtitleLabel.font.lineHeight)
                                                      lineBreakMode:self.subtitleLabel.lineBreakMode];
#endif
        
        CGFloat maxLabelWidth = MAX(titleSize.width,subtitleSize.width);
        
        CGFloat totalMaxWidth;
        if (maxLabelWidth) {
        	totalMaxWidth = leftViewWidth + margin + maxLabelWidth;
        } else {
        	totalMaxWidth = leftViewWidth + maxLabelWidth;
        }
        
        CGFloat labelX = (self.bounds.size.width / 2) - (totalMaxWidth / 2) + leftViewWidth + margin;
        
        if(subtitleSize.height > 0){
            CGFloat totalHeight = titleSize.height + subtitleSize.height + marginY;
            CGFloat minY = (self.bounds.size.height / 2)  - (totalHeight / 2);
            
            CGFloat titleY = minY;
            self.titleLabel.frame = CGRectIntegral(CGRectMake(labelX, titleY, titleSize.width, titleSize.height));
            self.subtitleLabel.frame = CGRectIntegral(CGRectMake(labelX, titleY + titleSize.height + marginY, subtitleSize.width, subtitleSize.height));
        }else{
            CGFloat totalHeight = titleSize.height;
            CGFloat minY = (self.bounds.size.height / 2)  - (totalHeight / 2);
            
            CGFloat titleY = minY;
            self.titleLabel.frame = CGRectIntegral(CGRectMake(labelX, titleY, titleSize.width, titleSize.height));
            self.subtitleLabel.frame = CGRectIntegral(CGRectMake(labelX, titleY + titleSize.height + marginY, subtitleSize.width, subtitleSize.height));
        }
        
        CGFloat arrowX = (self.bounds.size.width / 2) - (totalMaxWidth / 2) + (leftViewWidth - self.arrow.bounds.size.width) / 2;
        self.arrow.frame = CGRectMake(arrowX,
                                      (self.bounds.size.height / 2) - (self.arrow.bounds.size.height / 2),
                                      self.arrow.bounds.size.width,
                                      self.arrow.bounds.size.height);
        self.activityIndicatorView.center = self.arrow.center;
    }
}

- (void)setPosition:(SVPullToRefreshPosition)position {
    _position = position;
    if (_position == SVPullToRefreshPositionTop) {
        self.arrow.layer.transform = CATransform3DMakeRotation(0.0, 0, 0, 1);
    } else {
        self.arrow.layer.transform = CATransform3DMakeRotation(M_PI, 0, 0, 1);
    }
    // set titles
    if (position == SVPullToRefreshPositionTop) {
        [self setTitle:@"下拉我即可加载新内容" forState:SVPullToRefreshStateStopped];
        [self setTitle:@"放开我立即刷新" forState:SVPullToRefreshStateTriggered];
        [self setTitle:@"加载中" forState:SVPullToRefreshStateLoading];
    } else {
        [self setTitle:@"加载更多" forState:SVPullToRefreshStateStopped];
        [self setTitle:@"放开我加载更多" forState:SVPullToRefreshStateTriggered];
        [self setTitle:@"加载中" forState:SVPullToRefreshStateLoading];
    }
}

#pragma mark - Scroll View

- (void)resetScrollViewContentInset {
    UIEdgeInsets currentInsets = self.scrollView.contentInset;
    switch (self.position) {
        case SVPullToRefreshPositionTop:
            currentInsets.top = self.originalTopInset;
            break;
        case SVPullToRefreshPositionBottom:
            currentInsets.bottom = self.originalBottomInset;
//            currentInsets.top = self.originalTopInset;
            break;
    }
    [self setScrollViewContentInset:currentInsets];
}

- (void)setScrollViewContentInsetForLoading {
    CGFloat offset = MAX(self.scrollView.contentOffset.y * -1, 0);
    UIEdgeInsets currentInsets = self.scrollView.contentInset;
    switch (self.position) {
        case SVPullToRefreshPositionTop:
            currentInsets.top = MIN(offset, self.originalTopInset + self.bounds.size.height);
            break;
        case SVPullToRefreshPositionBottom:
            currentInsets.bottom = MIN(offset, self.originalBottomInset + self.bounds.size.height);
            break;
    }
    [self setScrollViewContentInset:currentInsets];
}

- (void)setScrollViewContentInset:(UIEdgeInsets)contentInset {
    [UIView animateWithDuration:0.3
                          delay:0
                        options:UIViewAnimationOptionAllowUserInteraction|UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                         self.scrollView.contentInset = contentInset;
                     }
                     completion:NULL];
}

#pragma mark - Observing

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    NSValue *valueOld = [change valueForKey:NSKeyValueChangeOldKey];
    NSValue *valueNew = [change valueForKey:NSKeyValueChangeNewKey];
    if ([valueOld isEqualToValue:valueNew]) {
        return;
    }
    
    if([keyPath isEqualToString:@"contentOffset"])
        [self scrollViewDidScroll:[[change valueForKey:NSKeyValueChangeNewKey] CGPointValue]];
    else if([keyPath isEqualToString:@"contentSize"]) {
        [self layoutSubviews];
        
        CGFloat yOrigin = [self.scrollView originalYOfPosition:self.position];
        self.frame = CGRectMake(0, yOrigin, self.bounds.size.width, SVPullToRefreshViewHeight);
    }
    else if([keyPath isEqualToString:@"frame"])
        [self layoutSubviews];
}

- (void)scrollViewDidScroll:(CGPoint)contentOffset {
//    NSString *type = _position == SVPullToRefreshPositionTop ? @"SVPullToRefreshPositionTop" : @"SVPullToRefreshPositionBottom";
//    NSLog(@"type:%@, self frame:%@, scrollView bounds:%@, offset:%@, contentInset:%@", type, NSStringFromCGRect(self.frame), NSStringFromCGRect(self.scrollView.bounds), NSStringFromCGPoint(contentOffset), NSStringFromUIEdgeInsets(self.scrollView.contentInset));
    
    if(self.state != SVPullToRefreshStateLoading) {
        CGFloat scrollOffsetThreshold = 0;
        // keep the contentOffsetY of "the moment when self will show"
        CGFloat selfWillShowContentOffsetY = 0.0;
        switch (self.position) {
            case SVPullToRefreshPositionTop:
                selfWillShowContentOffsetY = -self.originalTopInset;
                // if `contentOff.y` is less than `scrollOffsetThreshold`, trigger.
                scrollOffsetThreshold = selfWillShowContentOffsetY - SVPullToRefreshViewHeight;
                break;
            case SVPullToRefreshPositionBottom:
                if (self.scrollView.contentSize.height < self.scrollView.frame.size.height - self.scrollView.contentInset.top - self.scrollView.contentInset.bottom) {
                    selfWillShowContentOffsetY = -self.originalTopInset;
                } else {
                    selfWillShowContentOffsetY = -self.originalTopInset + self.scrollView.contentSize.height - (self.scrollView.frame.size.height - self.scrollView.contentInset.top - self.scrollView.contentInset.bottom);
                }
                // if `contentOff.y` is more than `scrollOffsetThreshold`, trigger.
                scrollOffsetThreshold = selfWillShowContentOffsetY + SVPullToRefreshViewHeight;
                break;
        }
        
        if (!self.scrollView.isDragging && self.state == SVPullToRefreshStateTriggered)
            self.state = SVPullToRefreshStateLoading;
        else {
            if (self.position == SVPullToRefreshPositionTop) {
                if (contentOffset.y < scrollOffsetThreshold && self.scrollView.isDragging && self.state == SVPullToRefreshStateStopped)
                    self.state = SVPullToRefreshStateTriggered;
                else if(contentOffset.y >= scrollOffsetThreshold && self.state != SVPullToRefreshStateStopped)
                    self.state = SVPullToRefreshStateStopped;
            } else {
                if (contentOffset.y > scrollOffsetThreshold && self.scrollView.isDragging && self.state == SVPullToRefreshStateStopped)
                    self.state = SVPullToRefreshStateTriggered;
                else if (contentOffset.y <= scrollOffsetThreshold && self.state != SVPullToRefreshStateStopped)
                    self.state = SVPullToRefreshStateStopped;
            }
        }
    } else {
        CGFloat offset;
        UIEdgeInsets contentInset;
        switch (self.position) {
            case SVPullToRefreshPositionTop:
                offset = MAX(self.scrollView.contentOffset.y * -1, 0.0f);
                offset = MIN(offset, self.originalTopInset + self.bounds.size.height);
                contentInset = self.scrollView.contentInset;
                self.scrollView.contentInset = UIEdgeInsetsMake(offset, contentInset.left, contentInset.bottom, contentInset.right);
                break;
            case SVPullToRefreshPositionBottom:
                if (self.scrollView.contentSize.height >= self.scrollView.bounds.size.height) {
                    CGFloat insetBottom = self.originalBottomInset + self.bounds.size.height;
                    CGFloat maxOffset = self.scrollView.contentSize.height - self.scrollView.bounds.size.height + insetBottom;
                    offset = MAX(maxOffset - self.scrollView.contentOffset.y, 0);
                    offset = MIN(insetBottom, offset);
                    CGFloat newInsetBottom = insetBottom - offset;
                    contentInset = self.scrollView.contentInset;
                    self.scrollView.contentInset = UIEdgeInsetsMake(contentInset.top, contentInset.left, newInsetBottom, contentInset.right);
                } else if (self.wasTriggeredByUser) {
                    // 不可以像上面那样(self.scrollView.contentSize.height >= self.scrollView.bounds.size.height)微调contentInset
                    // 因为在此时的情况下，使contentInset.bottom值减小会导致contentOffset移动，从而使scrollView滑动不上去(contentOffset.y > 0)
                    offset = self.originalBottomInset + self.bounds.size.height;
                    offset += self.scrollView.bounds.size.height-self.scrollView.contentSize.height;
                    contentInset = self.scrollView.contentInset;
                    self.scrollView.contentInset = UIEdgeInsetsMake(contentInset.top, contentInset.left, offset, contentInset.right);
                }
                break;
        }
    }
}

#pragma mark - Getters

- (SVPullToRefreshArrow *)arrow {
    if(!_arrow) {
		_arrow = [[SVPullToRefreshArrow alloc]initWithFrame:CGRectMake(0, self.bounds.size.height-54, 22, 48)];
        _arrow.backgroundColor = [UIColor clearColor];
		[self addSubview:_arrow];
    }
    return _arrow;
}

- (UIActivityIndicatorView *)activityIndicatorView {
    if(!_activityIndicatorView) {
        _activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        _activityIndicatorView.hidesWhenStopped = YES;
        [self addSubview:_activityIndicatorView];
    }
    return _activityIndicatorView;
}

- (UILabel *)titleLabel {
    if(!_titleLabel) {
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 210, 20)];
        _titleLabel.text = [self.titles objectAtIndex:SVPullToRefreshStateStopped];
        _titleLabel.font = [UIFont boldSystemFontOfSize:14];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.textColor = textColor;
        [self addSubview:_titleLabel];
    }
    return _titleLabel;
}

- (UILabel *)subtitleLabel {
    if(!_subtitleLabel) {
        _subtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 210, 20)];
        _subtitleLabel.font = [UIFont systemFontOfSize:12];
        _subtitleLabel.backgroundColor = [UIColor clearColor];
        _subtitleLabel.textColor = textColor;
        [self addSubview:_subtitleLabel];
    }
    return _subtitleLabel;
}

- (UILabel *)dateLabel {
    return self.showsDateLabel ? self.subtitleLabel : nil;
}

- (NSDateFormatter *)dateFormatter {
    if(!dateFormatter) {
        dateFormatter = [[NSDateFormatter alloc] init];
		[dateFormatter setDateStyle:NSDateFormatterShortStyle];
		[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
		dateFormatter.locale = [NSLocale currentLocale];
    }
    return dateFormatter;
}

- (UIColor *)textColor {
    return self.titleLabel.textColor;
}

- (UIColor *)activityIndicatorViewColor {
    return self.activityIndicatorView.color;
}

- (UIActivityIndicatorViewStyle)activityIndicatorViewStyle {
    return self.activityIndicatorView.activityIndicatorViewStyle;
}

#pragma mark - Setters

- (void)setTitle:(NSString *)title forState:(SVPullToRefreshState)state {
    if(!title)
        title = @"";
    
    if(state == SVPullToRefreshStateAll)
        [self.titles replaceObjectsInRange:NSMakeRange(0, 3) withObjectsFromArray:@[title, title, title]];
    else
        [self.titles replaceObjectAtIndex:state withObject:title];
    
    if (self.state == state) {
        self.titleLabel.text = [self.titles objectAtIndex:self.state];
        [self setNeedsLayout];
    }
}

- (void)setSubtitle:(NSString *)subtitle forState:(SVPullToRefreshState)state {
    if(!subtitle)
        subtitle = @"";
    
    if(state == SVPullToRefreshStateAll)
        [self.subtitles replaceObjectsInRange:NSMakeRange(0, 3) withObjectsFromArray:@[subtitle, subtitle, subtitle]];
    else
        [self.subtitles replaceObjectAtIndex:state withObject:subtitle];
    
    if (self.state == state) {
        self.subtitleLabel.text = subtitle.length > 0 ? subtitle : nil;
        [self setNeedsLayout];
    }
}

- (void)setCustomView:(UIView<SVPullToRefreshCustomViewProtocol> *)view forState:(SVPullToRefreshState)state {
    id viewPlaceholder = view;
    
    if(!viewPlaceholder)
        viewPlaceholder = @"";
    
    if(state == SVPullToRefreshStateAll)
        [self.viewForState replaceObjectsInRange:NSMakeRange(0, 3) withObjectsFromArray:@[viewPlaceholder, viewPlaceholder, viewPlaceholder]];
    else
        [self.viewForState replaceObjectAtIndex:state withObject:viewPlaceholder];
    
    [self setNeedsLayout];
}

- (void)setTextColor:(UIColor *)newTextColor {
    textColor = newTextColor;
    self.titleLabel.textColor = newTextColor;
	self.subtitleLabel.textColor = newTextColor;
}

- (void)setActivityIndicatorViewColor:(UIColor *)color {
    self.activityIndicatorView.color = color;
}

- (void)setActivityIndicatorViewStyle:(UIActivityIndicatorViewStyle)viewStyle {
    self.activityIndicatorView.activityIndicatorViewStyle = viewStyle;
}

- (void)setLastUpdatedDate:(NSDate *)newLastUpdatedDate {
    self.showsDateLabel = YES;
    self.dateLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Last Updated: %@",), newLastUpdatedDate?[self.dateFormatter stringFromDate:newLastUpdatedDate]:NSLocalizedString(@"Never",)];
}

- (void)setDateFormatter:(NSDateFormatter *)newDateFormatter {
	dateFormatter = newDateFormatter;
    self.dateLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Last Updated: %@",), self.lastUpdatedDate?[newDateFormatter stringFromDate:self.lastUpdatedDate]:NSLocalizedString(@"Never",)];
}

#pragma mark -

- (void)startAnimating {
    CGFloat scrollHeight = _scrollView.contentSize.height;
    CGFloat top = _scrollView.contentInset.top;
    CGFloat bottom = _scrollView.contentInset.bottom;
    CGFloat offsetY = _scrollView.contentOffset.y;
    CGFloat contentHeight = _scrollView.contentSize.height;
    switch (self.position) {
        case SVPullToRefreshPositionTop:
            if (offsetY + top < 0) {
                // user is pulling down
                self.wasTriggeredByUser = YES;
            } else {
                [self.scrollView setContentOffset:CGPointMake(self.scrollView.contentOffset.x, -top-self.frame.size.height)
                                         animated:YES];
                self.wasTriggeredByUser = NO;
            }
            break;
        case SVPullToRefreshPositionBottom:
            if ((contentHeight + bottom >= scrollHeight &&
                 offsetY > contentHeight + bottom - scrollHeight) ||
                (contentHeight + bottom <= scrollHeight - top &&
                 offsetY > -top) ||
                (contentHeight + bottom > scrollHeight - top &&
                 offsetY > scrollHeight - top - (contentHeight + bottom))) {
                    // user is pulling up
                    self.wasTriggeredByUser = YES;
                } else {
                    CGFloat offsetYTo = 0.0;
                    bottom += self.frame.size.height;
                    if (contentHeight + bottom >= scrollHeight) {
                        offsetYTo = contentHeight + bottom - scrollHeight;
                    } else if (contentHeight + bottom <= scrollHeight - top) {
                        offsetYTo = -top;
                    } else {
                        offsetYTo = scrollHeight - top - (contentHeight + bottom);
                    }
                    [self.scrollView setContentOffset:(CGPoint){.y = offsetYTo} animated:YES];
                    self.wasTriggeredByUser = NO;
                }
            break;
    }
    
    self.state = SVPullToRefreshStateLoading;
}

- (void)stopAnimating {
    self.state = SVPullToRefreshStateStopped;
    
    switch (self.position) {
        case SVPullToRefreshPositionTop:
            if(!self.wasTriggeredByUser) {
                [self.scrollView setContentOffset:CGPointMake(self.scrollView.contentOffset.x, -self.originalTopInset) animated:YES];
            }
            break;
        case SVPullToRefreshPositionBottom:
            if(!self.wasTriggeredByUser) {
                [self.scrollView setContentOffset:CGPointMake(self.scrollView.contentOffset.x, self.scrollView.contentSize.height - self.scrollView.bounds.size.height + self.originalBottomInset) animated:YES];
            }
            break;
    }
}

NSString *stringState(SVPullToRefreshState state) {
    if (state == SVPullToRefreshStateAll) {
        return @"SVPullToRefreshStateAll";
    } else if (state == SVPullToRefreshStateLoading) {
        return @"SVPullToRefreshStateLoading";
    } else if (state == SVPullToRefreshStateStopped) {
        return @"SVPullToRefreshStateStopped";
    } else if (state == SVPullToRefreshStateTriggered) {
        return @"SVPullToRefreshStateTriggered";
    }
    return @"nothing";
}

- (void)setState:(SVPullToRefreshState)newState {
    
    if(_state == newState)
        return;
    
    SVPullToRefreshState previousState = _state;
    _state = newState;
//    NSLog(@"%@:%@", NSStringFromSelector(_cmd), stringState(newState));
    UIView<SVPullToRefreshCustomViewProtocol> *customView = [self.viewForState objectAtIndex:_state];
    BOOL hasCustomView = [customView isKindOfClass:[UIView class]];
    
    self.titleLabel.hidden = hasCustomView;
    self.subtitleLabel.hidden = hasCustomView;
    self.arrow.hidden = hasCustomView;
    
    switch (newState) {
        case SVPullToRefreshStateAll:
        case SVPullToRefreshStateStopped: {
            UIEdgeInsets currentInsets = self.scrollView.contentInset;
            switch (self.position) {
                case SVPullToRefreshPositionTop:
                    currentInsets.top = self.originalTopInset;
                    break;
                case SVPullToRefreshPositionBottom:
                    currentInsets.bottom = self.originalBottomInset;
//                    currentInsets.top = self.originalTopInset;
                    break;
            }
            [UIView animateWithDuration:0.3
                                  delay:0
                                options:UIViewAnimationOptionAllowUserInteraction|UIViewAnimationOptionBeginFromCurrentState
                             animations:^{
                                 self.scrollView.contentInset = currentInsets;
                             }
                             completion:^(BOOL finished) {
                                 if (self.state != SVPullToRefreshStateAll &&
                                     self.state != SVPullToRefreshStateStopped) {
                                     return;
                                 }
                                 for(id otherView in self.viewForState) {
                                     if([otherView isKindOfClass:[UIView class]])
                                         [otherView removeFromSuperview];
                                 }
                                 if (hasCustomView) {
                                     [self addSubview:customView];
                                     if ([customView respondsToSelector:@selector(customViewShouldStopAnimating)])
                                         [customView customViewShouldStopAnimating];
                                 } else {
                                     self.arrow.alpha = 1;
                                     [self.activityIndicatorView stopAnimating];
                                     switch (self.position) {
                                         case SVPullToRefreshPositionTop:
                                             [self rotateArrow:0 hide:NO];
                                             break;
                                         case SVPullToRefreshPositionBottom:
                                             [self rotateArrow:(float)M_PI hide:NO];
                                             break;
                                     }
                                     self.titleLabel.text = [self.titles objectAtIndex:self.state];
                                     NSString *subtitle = [self.subtitles objectAtIndex:self.state];
                                     self.subtitleLabel.text = subtitle.length > 0 ? subtitle : nil;
                                 }
                                 [self setNeedsLayout];
                                 [self layoutIfNeeded];
                             }];
        }
            break;
            
        case SVPullToRefreshStateTriggered:
            for(id otherView in self.viewForState) {
                if([otherView isKindOfClass:[UIView class]])
                    [otherView removeFromSuperview];
            }
            if (!hasCustomView) {
                [self.activityIndicatorView stopAnimating];
                self.titleLabel.text = [self.titles objectAtIndex:self.state];
                NSString *subtitle = [self.subtitles objectAtIndex:self.state];
                self.subtitleLabel.text = subtitle.length > 0 ? subtitle : nil;
                
                switch (self.position) {
                    case SVPullToRefreshPositionTop:
                        [self rotateArrow:(float)M_PI hide:NO];
                        break;
                    case SVPullToRefreshPositionBottom:
                        [self rotateArrow:0 hide:NO];
                        break;
                }
            }
            
            [self setNeedsLayout];
            [self layoutIfNeeded];
            break;
            
        case SVPullToRefreshStateLoading:
            for(id otherView in self.viewForState) {
                if([otherView isKindOfClass:[UIView class]])
                    [otherView removeFromSuperview];
            }
            if (hasCustomView) {
                if ([customView respondsToSelector:@selector(customViewShouldBeginAnimating)])
                    [customView customViewShouldBeginAnimating];
            } else {
                self.titleLabel.text = [self.titles objectAtIndex:self.state];
                NSString *subtitle = [self.subtitles objectAtIndex:self.state];
                self.subtitleLabel.text = subtitle.length > 0 ? subtitle : nil;
                
                [self.activityIndicatorView startAnimating];
                switch (self.position) {
                    case SVPullToRefreshPositionTop:
                        [self rotateArrow:0 hide:YES];
                        break;
                    case SVPullToRefreshPositionBottom:
                        [self rotateArrow:(float)M_PI hide:YES];
                        break;
                }
            }
            
            [self setNeedsLayout];
            [self layoutIfNeeded];
            [self setScrollViewContentInsetForLoading];
            
            if (previousState == SVPullToRefreshStateTriggered && pullToRefreshActionHandler)
                pullToRefreshActionHandler();
            
            break;
    }
}

- (void)rotateArrow:(float)degrees hide:(BOOL)hide {
    [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionAllowUserInteraction animations:^{
        self.arrow.layer.transform = CATransform3DMakeRotation(degrees, 0, 0, 1);
        self.arrow.layer.opacity = hide ? 0.0 : 1.0;
        //[self.arrow setNeedsDisplay];//ios 4
    } completion:NULL];
}

@end


#pragma mark - SVPullToRefreshArrow

@implementation SVPullToRefreshArrow
@synthesize arrowColor;

- (UIColor *)arrowColor {
	if (arrowColor) return arrowColor;
	return [UIColor grayColor]; // default Color
}

- (void)drawRect:(CGRect)rect {
	CGContextRef c = UIGraphicsGetCurrentContext();
	
	// the rects above the arrow
	CGContextAddRect(c, CGRectMake(5, 0, 12, 4)); // to-do: use dynamic points
	CGContextAddRect(c, CGRectMake(5, 6, 12, 4)); // currently fixed size: 22 x 48pt
	CGContextAddRect(c, CGRectMake(5, 12, 12, 4));
	CGContextAddRect(c, CGRectMake(5, 18, 12, 4));
	CGContextAddRect(c, CGRectMake(5, 24, 12, 4));
	CGContextAddRect(c, CGRectMake(5, 30, 12, 4));
	
	// the arrow
	CGContextMoveToPoint(c, 0, 34);
	CGContextAddLineToPoint(c, 11, 48);
	CGContextAddLineToPoint(c, 22, 34);
	CGContextAddLineToPoint(c, 0, 34);
	CGContextClosePath(c);
	
	CGContextSaveGState(c);
	CGContextClip(c);
	
	// Gradient Declaration
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGFloat alphaGradientLocations[] = {0, 0.8f};
    
	CGGradientRef alphaGradient = nil;
    if([[[UIDevice currentDevice] systemVersion]floatValue] >= 5){
        NSArray* alphaGradientColors = [NSArray arrayWithObjects:
                                        (id)[self.arrowColor colorWithAlphaComponent:0].CGColor,
                                        (id)[self.arrowColor colorWithAlphaComponent:1].CGColor,
                                        nil];
        alphaGradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)alphaGradientColors, alphaGradientLocations);
    }else{
        const CGFloat * components = CGColorGetComponents([self.arrowColor CGColor]);
        size_t numComponents = CGColorGetNumberOfComponents([self.arrowColor CGColor]);
        CGFloat colors[8];
        switch(numComponents){
            case 2:{
                colors[0] = colors[4] = components[0];
                colors[1] = colors[5] = components[0];
                colors[2] = colors[6] = components[0];
                break;
            }
            case 4:{
                colors[0] = colors[4] = components[0];
                colors[1] = colors[5] = components[1];
                colors[2] = colors[6] = components[2];
                break;
            }
        }
        colors[3] = 0;
        colors[7] = 1;
        alphaGradient = CGGradientCreateWithColorComponents(colorSpace,colors,alphaGradientLocations,2);
    }
	
	
	CGContextDrawLinearGradient(c, alphaGradient, CGPointZero, CGPointMake(0, rect.size.height), 0);
    
	CGContextRestoreGState(c);
	
	CGGradientRelease(alphaGradient);
	CGColorSpaceRelease(colorSpace);
}
@end
