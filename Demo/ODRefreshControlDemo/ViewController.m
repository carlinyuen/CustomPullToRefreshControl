//
//  ViewController.m
//  ODRefreshControlDemo
//
//  Created by Fabio Ritrovato on 7/4/12.
//  Copyright (c) 2012 orange in a day. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

#import "ViewController.h"
#import "ODRefreshControl.h"

	/** Create UIColor form hex code color value */
	#define UIColorFromHex(hex) [UIColor colorWithRed:((float)((hex & 0xFF0000) >> 16))/255.0 green:((float)((hex & 0xFF00) >> 8))/255.0 blue:((float)(hex & 0xFF))/255.0 alpha:1.0]

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
	self.imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"BC_Logo_.png"]];
	self.imageView.frame = CGRectMake(0, 0, 24, 24);
	
    ODRefreshControl *refreshControl = [[ODRefreshControl alloc] initInScrollView:self.tableView activityIndicatorView:self.imageView];
	
	refreshControl.tintColor = UIColorFromHex(0xF7931A);
	refreshControl.activityIndicatorViewColor = UIColorFromHex(0xFFB452);
	refreshControl.strokeColor = UIColorFromHex(0xFFB452);
	
	
	refreshControl.arrowView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"BC_Logo_.png"]];
    [refreshControl addTarget:self action:@selector(dropViewDidBeginRefreshing:) forControlEvents:UIControlEventValueChanged];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    } else {
        return YES;
    }
}

- (void)dropViewDidBeginRefreshing:(ODRefreshControl *)refreshControl
{
    double delayInSeconds = 3.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [refreshControl endRefreshing];
    });
	
	// Animate Image
	CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform"];
	
	CATransform3D transform = self.imageView.layer.transform;
	transform.m34 = -1/500;
	transform = CATransform3DRotate(transform, M_PI, 0, 1, 0);
	animation.autoreverses = true;
	animation.toValue = [NSValue valueWithCATransform3D:transform];
	
	animation.duration = 0.3;
	animation.repeatCount = HUGE_VALF;
	
	[self.imageView.layer addAnimation:animation forKey:@"rotate"];

}

@end
