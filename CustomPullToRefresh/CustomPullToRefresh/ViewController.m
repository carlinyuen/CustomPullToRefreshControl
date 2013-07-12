//
//  ViewController.m
//  CustomPullToRefresh
//
//  Created by Carlin on 7/12/13.
//  Copyright (c) 2013 Carlin. All rights reserved.
//

#import "ViewController.h"

	#define IMG_REFRESH_ICON @"icn_refresh.png"

	#define NUM_PAGES 6

	/** Create UIColor form hex code color value */
	#define UIColorFromHex(hex) [UIColor colorWithRed:((float)((hex & 0xFF000000) >> 24))/255.0 green:((float)((hex & 0xFF0000) >> 16))/255.0 blue:((float)((hex & 0xFF00) >> 8))/255.0 alpha:((float)(hex & 0xFF))/255.0]

	/** Generate random float in range */
	#define randomf(rangeStart, rangeEnd) ((((float) (arc4random() % ((unsigned)RAND_MAX + 1)) / RAND_MAX) * (rangeEnd - rangeStart)) + rangeStart)

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
	
	// Setup scrollview
	self.scrollView.backgroundColor = [UIColor whiteColor];
	self.scrollView.directionalLockEnabled = true;
		
	// Pull to refresh control
	self.refreshIV = [[UIImageView alloc] initWithImage:[UIImage imageNamed:IMG_REFRESH_ICON]];
	self.refreshControl = [[CustomPullToRefreshControl alloc]
		initInScrollView:self.scrollView
		activityIndicatorView:self.refreshIV];
	self.refreshControl.backgroundColor = [UIColor clearColor];
	self.refreshControl.tintColor = UIColorFromHex(0xF7931AFF);
	self.refreshControl.strokeColor = UIColorFromHex(0xFFB452FF);
	self.refreshControl.pullView = [[UIImageView alloc] initWithImage:self.refreshIV.image];
	self.refreshControl.drawDiskWhenPulling = true;
	self.refreshControl.enableDiskDripEffect = true;
	self.refreshControl.stickToTopWhenRefreshing = true;
	self.refreshControl.scrollUpToCancel = true;
	self.refreshControl.refreshStyle = CustomPullToRefreshSpin;
	self.refreshControl.refreshEasing = CustomPullToRefreshMomentum;
    [self.refreshControl addTarget:self action:@selector(pulledToRefresh:)
		forControlEvents:UIControlEventValueChanged];
    [self.refreshControl addTarget:self action:@selector(cancelledRefresh:)
		forControlEvents:UIControlEventTouchCancel];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



#pragma mark - CustomPullToRefreshControl

/** @brief Pull to refresh was canceled */
- (void)cancelledRefresh:(id)sender
{
	// Do something
}

/** @brief Pull to refresh initiated */
- (void)pulledToRefresh:(id)sender
{
	// Animate refreshIV while loading
	CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform"];
	CATransform3D transform = self.refreshIV.layer.transform;
	transform.m34 = -1/500;
	transform = CATransform3DRotate(transform, M_PI, 0, 1, 0);
	animation.autoreverses = true;
	animation.toValue = [NSValue valueWithCATransform3D:transform];
	animation.duration = 0.3;
	animation.repeatCount = HUGE_VALF;
	[self.refreshIV.layer addAnimation:animation forKey:@"rotate"];

	// End refreshing after some time
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^(void){
			[self.refreshControl endRefreshing];
		});
}


@end
