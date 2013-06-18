/**
	@file	CustomPullToRefreshControl.h
	@author	Carlin
	@date	6/17/13
	@brief	Forked off ODRefreshControl by Fabio Ritrovato on 6/13/12. 
*/


#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@interface CustomPullToRefreshControl : UIControl {

}

@property (nonatomic, readonly) BOOL refreshing;
@property (nonatomic, strong) UIColor *tintColor;
@property (nonatomic, strong) UIColor *strokeColor;
@property (nonatomic, strong) UIColor *shadowColor;
@property (nonatomic, strong) UIImageView* arrowView;
@property (nonatomic, assign) UIActivityIndicatorViewStyle activityIndicatorViewStyle;
@property (nonatomic, strong) UIColor *activityIndicatorViewColor; // iOS5 or more

- (id)initInScrollView:(UIScrollView *)scrollView;

// use custom activity indicator
- (id)initInScrollView:(UIScrollView *)scrollView activityIndicatorView:(UIView *)activity;

// Tells the control that a refresh operation was started programmatically
- (void)beginRefreshing;

// Tells the control the refresh operation has ended
- (void)endRefreshing;

@end
