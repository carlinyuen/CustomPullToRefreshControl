/**
	@file	CustomPullToRefreshControl.h
	@author	Carlin
	@date	6/17/13
	@brief	Forked off ODRefreshControl by Fabio Ritrovato on 6/13/12. 
*/


#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

// Enum for refresh style animation on pullView
typedef enum {
	CustomPullToRefreshNone,
	CustomPullToRefreshSpin,
	CustomPullToRefreshRotate,
} CustomPullToRefreshStyle;

// Enum for animation easing on pullView
typedef enum {
	CustomPullToRefreshLinear,
	CustomPullToRefreshMomentum,
	CustomPullToRefreshContinuous
} CustomPullToRefreshEasing;


@interface CustomPullToRefreshControl : UIControl

	/** Refresh status */
	@property (nonatomic, readonly) BOOL refreshing;

	/** UIView in place of arrow in pull to refresh */
	@property (nonatomic, strong) UIView* pullView;

	/** Refresh animation on custom pullView */
	@property (nonatomic, assign) CustomPullToRefreshStyle refreshStyle;
	@property (nonatomic, assign) CustomPullToRefreshEasing refreshEasing;

	/** Customizable colors */
	@property (nonatomic, strong) UIColor *tintColor;
	@property (nonatomic, strong) UIColor *strokeColor;
	@property (nonatomic, strong) UIColor *shadowColor;

	/** Draw the disk behind the arrow / pullview */
	@property (nonatomic, assign) BOOL drawDiskWhenPulling;

	/** Draw the drippy effect on pull to refresh, if disabled, 
		pullView / arrow will be right above top of ScrollView */
	@property (nonatomic, assign) BOOL enableDiskDripEffect;

	/** Stick activityview to top of screen when refreshing */
	@property (nonatomic, assign) BOOL stickToTopWhenRefreshing;

	/** Enable scroll up to cancel, will emit a UIControlEventTouchCancel
		on cancel, which a viewcontroller should addTarget for */
	@property (nonatomic, assign) BOOL scrollUpToCancel;

	/** Customizing native activity indicator */
	@property (nonatomic, assign) UIActivityIndicatorViewStyle activityIndicatorViewStyle;
	@property (nonatomic, strong) UIColor *activityIndicatorViewColor; // iOS5 or more

	/** init method */
	- (id)initInScrollView:(UIScrollView *)scrollView;

	/** use custom activity indicator */
	- (id)initInScrollView:(UIScrollView *)scrollView activityIndicatorView:(UIView *)activity;

	/** Tells the control that a refresh operation was started programmatically, need to manually set contentoffset on scrollview to show the control */
	- (void)beginRefreshing;

	/** Tells the control the refresh operation has ended and to hide the control */
	- (void)endRefreshing;

@end
