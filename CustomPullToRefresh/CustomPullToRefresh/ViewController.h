//
//  ViewController.h
//  CustomPullToRefresh
//
//  Created by Carlin on 7/12/13.
//  Copyright (c) 2013 Carlin. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "CustomPullToRefreshControl.h"

@interface ViewController : UIViewController
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (nonatomic, strong) CustomPullToRefreshControl* refreshControl;
@property (nonatomic, strong) UIImageView* refreshIV;
@end
