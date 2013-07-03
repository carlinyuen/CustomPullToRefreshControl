/**
	@file	CustomPullToRefreshControl.m
	@author	Carlin
	@date	6/17/13
	@brief	Forked off ODRefreshControl by Fabio Ritrovato on 6/13/12. 
*/


#import "CustomPullToRefreshControl.h"

#define kTotalViewHeight    400
#define kOpenedViewHeight   54
#define kMinTopPadding      8
#define kMaxTopPadding      6
#define kMinTopRadius       12.5
#define kMaxTopRadius       16
#define kMinBottomRadius    3
#define kMaxBottomRadius    16
#define kMinBottomPadding   8
#define kMaxBottomPadding   6
#define kMinArrowSize       2
#define kMaxArrowSize       3
#define kMinArrowRadius     5
#define kMaxArrowRadius     7
#define kMaxDistance        64
#define kArrowViewSize     3.7

#define kContinuousAnimationDuration 0.5
#define kFadeAnimationDuration 0.3
#define kMomentumAnimationFriction 0.005
#define kMomentumAnimationAccelerationScale 0.003
#define kMomentumAnimationVelocityScale	0.1
#define kMomentumAnimationVelocityMax 3.14

#define kCancelRefreshDelay 1

@interface CustomPullToRefreshControl ()

	/** public refresh status */
	@property (nonatomic, readwrite) BOOL refreshing;

	/** ScrollView to add pull to refresh to */
	@property (nonatomic, assign) UIScrollView* scrollView;
	@property (nonatomic, assign) UIEdgeInsets originalContentInset;

	/** For drawing synced to redraw, for momentum animation */
	@property (nonatomic, strong) CADisplayLink* displayLink;

	/** Set delay for scroll up to cancel */
	@property (nonatomic, strong) NSTimer* cancelTimer;

	// For drawing
    @property (nonatomic, strong) CAShapeLayer* shapeLayer;
    @property (nonatomic, strong) CAShapeLayer* arrowLayer;
    @property (nonatomic, strong) CAShapeLayer* highlightLayer;
    @property (nonatomic, strong) UIView* activityIndicator;

	// For calculations
    @property (nonatomic, assign) BOOL canRefresh;
    @property (nonatomic, assign) BOOL ignoreInset;
    @property (nonatomic, assign) BOOL ignoreOffset;
    @property (nonatomic, assign) BOOL didSetInset;
    @property (nonatomic, assign) BOOL hasSectionHeaders;
    @property (nonatomic, assign) CGFloat lastOffset;

	// For momentum animation drawing 
	@property (nonatomic, assign) CGFloat acceleration;
	@property (nonatomic, assign) CGFloat velocity;
	@property (nonatomic, assign) CGFloat momentumLastOffset;

@end


#pragma mark - Implementation

@implementation CustomPullToRefreshControl

static inline CGFloat lerp(CGFloat a, CGFloat b, CGFloat p)
{
    return a + (b - a) * p;
}

- (id)initInScrollView:(UIScrollView *)scrollView {
    return [self initInScrollView:scrollView activityIndicatorView:nil];
}

- (id)initInScrollView:(UIScrollView *)scrollView activityIndicatorView:(UIView *)activity
{
    self = [super initWithFrame:CGRectMake(0, -(kTotalViewHeight + scrollView.contentInset.top), scrollView.frame.size.width, kTotalViewHeight)];
    
    if (self)
	{
        _scrollView = scrollView;
        _originalContentInset = scrollView.contentInset;
        
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [scrollView addSubview:self];
        [scrollView addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:nil];
        [scrollView addObserver:self forKeyPath:@"contentInset" options:NSKeyValueObservingOptionNew context:nil];
        
        _activityIndicator = activity ? activity : [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        _activityIndicator.center = CGPointMake(floor(self.frame.size.width / 2), floor(self.frame.size.height / 2));
        _activityIndicator.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        _activityIndicator.alpha = 0;
        if ([_activityIndicator respondsToSelector:@selector(startAnimating)]) {
            [(UIActivityIndicatorView *)_activityIndicator startAnimating];
        }
        [self addSubview:_activityIndicator];
        
        _refreshing = NO;
        _canRefresh = YES;
        _ignoreInset = NO;
        _ignoreOffset = NO;
        _didSetInset = NO;
        _hasSectionHeaders = NO;
        _tintColor = [UIColor colorWithRed:155.0 / 255.0 green:162.0 / 255.0 blue:172.0 / 255.0 alpha:1.0];
        
        _shapeLayer = [CAShapeLayer layer];
        _shapeLayer.fillColor = [_tintColor CGColor];
        _shapeLayer.strokeColor = [[[UIColor darkGrayColor] colorWithAlphaComponent:0.5] CGColor];
        _shapeLayer.lineWidth = 0.5;
        _shapeLayer.shadowColor = [[UIColor blackColor] CGColor];
        _shapeLayer.shadowOffset = CGSizeMake(0, 1);
        _shapeLayer.shadowOpacity = 0.4;
        _shapeLayer.shadowRadius = 0.5;
        [self.layer addSublayer:_shapeLayer];
        
        _arrowLayer = [CAShapeLayer layer];
        _arrowLayer.strokeColor = [[[UIColor darkGrayColor] colorWithAlphaComponent:0.5] CGColor];
        _arrowLayer.lineWidth = 0.5;
        _arrowLayer.fillColor = [[UIColor whiteColor] CGColor];
        [_shapeLayer addSublayer:_arrowLayer];
        
        _highlightLayer = [CAShapeLayer layer];
        _highlightLayer.fillColor = [[[UIColor whiteColor] colorWithAlphaComponent:0.2] CGColor];
        [_shapeLayer addSublayer:_highlightLayer];
		
		// Default animation styles
		_refreshStyle = CustomPullToRefreshNone;
		_refreshEasing = CustomPullToRefreshLinear;
		
		// Disk & drip - default to true to mimic native
		_drawDiskWhenPulling = true;
		_enableDiskDripEffect = true;
		
		// Stick to top - default to true to mimic native
		_stickToTopWhenRefreshing = true;
		
		// Scroll up to cancel - default to false to mimic native
		_scrollUpToCancel = false;
		
		// Momentum
		_momentumLastOffset = 0;
		_acceleration = 0;
		_velocity = 0;
    }
    return self;
}

- (void)dealloc
{
    [self.scrollView removeObserver:self forKeyPath:@"contentOffset"];
    [self.scrollView removeObserver:self forKeyPath:@"contentInset"];
    self.scrollView = nil;

	if (self.displayLink) {
		[self.displayLink invalidate];
		self.displayLink = nil;
	}
}

- (void)willMoveToSuperview:(UIView *)newSuperview
{
    [super willMoveToSuperview:newSuperview];
    if (!newSuperview) {
        [self.scrollView removeObserver:self forKeyPath:@"contentOffset"];
        [self.scrollView removeObserver:self forKeyPath:@"contentInset"];
        self.scrollView = nil;
    }
	
	if (self.displayLink) {
		[self.displayLink invalidate];
		self.displayLink = nil;
	}
}


#pragma mark - Getters & Setters

- (void)setEnabled:(BOOL)enabled
{
    super.enabled = enabled;
    _shapeLayer.hidden = !self.enabled;
}


- (void)setTintColor:(UIColor *)tintColor
{
    _tintColor = tintColor;
    _shapeLayer.fillColor = [_tintColor CGColor];
}

- (void)setStrokeColor:(UIColor *)strokeColor
{
    _strokeColor = strokeColor;
	_shapeLayer.strokeColor = [[strokeColor colorWithAlphaComponent:0.5] CGColor];
	_arrowLayer.strokeColor = [[strokeColor colorWithAlphaComponent:0.5] CGColor];
}

- (void)setShadowColor:(UIColor *)shadowColor
{
    _shadowColor = shadowColor;
	_shapeLayer.shadowColor = [_shadowColor CGColor];
}

- (void)setActivityIndicatorViewStyle:(UIActivityIndicatorViewStyle)activityIndicatorViewStyle
{
    if ([_activityIndicator isKindOfClass:[UIActivityIndicatorView class]]) {
        [(UIActivityIndicatorView *)_activityIndicator setActivityIndicatorViewStyle:activityIndicatorViewStyle];
    }
}

- (UIActivityIndicatorViewStyle)activityIndicatorViewStyle
{
    if ([_activityIndicator isKindOfClass:[UIActivityIndicatorView class]]) {
        return [(UIActivityIndicatorView *)_activityIndicator activityIndicatorViewStyle];
    }
    return 0;
}

- (void)setActivityIndicatorViewColor:(UIColor *)activityIndicatorViewColor
{
    if ([_activityIndicator isKindOfClass:[UIActivityIndicatorView class]] && [_activityIndicator respondsToSelector:@selector(setColor:)]) {
        [(UIActivityIndicatorView *)_activityIndicator setColor:activityIndicatorViewColor];
    }
}

- (UIColor *)activityIndicatorViewColor
{
    if ([_activityIndicator isKindOfClass:[UIActivityIndicatorView class]] && [_activityIndicator respondsToSelector:@selector(color)]) {
        return [(UIActivityIndicatorView *)_activityIndicator color];
    }
    return nil;
}

- (void)setPullView:(UIView*)pullView
{
	if (pullView)
	{
		_pullView = pullView;
		_pullView.alpha = 0;
		_pullView.frame = CGRectMake(
			floor(self.bounds.size.width / 2) - kMaxTopRadius,
			self.bounds.size.height - kMaxTopRadius * 2,
			kMaxTopRadius * 2,
			kMaxTopRadius * 2
		);
		[self addSubview:_pullView];
	
		// Start / stop continuous animation accordingly
		[self stopContinuousAnimation];
		[self stopMomentumAnimation];
		if (self.refreshEasing == CustomPullToRefreshContinuous) {
			[self startContinuousAnimation];
		} else if (self.refreshEasing == CustomPullToRefreshMomentum) {
			[self startMomentumAnimation];
		}
	}
	else {
		[_pullView removeFromSuperview];
		_pullView = nil;
	}
}

- (void)setRefreshEasing:(CustomPullToRefreshEasing)refreshEasing
{
	_refreshEasing = refreshEasing;

	// Start / stop continuous animation accordingly
	[self stopMomentumAnimation];
	[self stopContinuousAnimation];
	if (refreshEasing == CustomPullToRefreshContinuous) {
		[self startContinuousAnimation];
	} else if (refreshEasing == CustomPullToRefreshMomentum) {
		[self startMomentumAnimation];
	}
}


#pragma mark - Animation related

/** @brief Create display link to sync with redraw and show animation */
- (void)startMomentumAnimation
{
	if (self.pullView
		&& self.refreshStyle != CustomPullToRefreshNone
		&& self.refreshEasing == CustomPullToRefreshMomentum)
	{
		CADisplayLink *displayLink = [CADisplayLink
			displayLinkWithTarget:self selector:@selector(redraw:)];
		[displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
	}
}

/** @brief Drawing for momentum animation */
- (void)redraw:(id)sender
{
	// Physics - Stokes' Drag
	self.velocity += (self.acceleration - kMomentumAnimationFriction * self.velocity);
	
	// Cap velocity
	if (self.velocity > kMomentumAnimationVelocityMax) {
		self.velocity = kMomentumAnimationVelocityMax;
	}
	
	// Acceleration
	if (self.acceleration > 0) {
		self.acceleration -= kMomentumAnimationFriction;
	}
	if (self.acceleration < 0) {
		self.acceleration = 0;
	}
	
	// Drawing
	CGFloat x, y, z;
	switch (self.refreshStyle)
	{
		case CustomPullToRefreshRotate:
			x = z = 0.0;
			y = 1.0;
			break;
		
		case CustomPullToRefreshSpin:
			x = y = 0.0;
			z = 1.0;
			break;
		
		case CustomPullToRefreshNone:
		default:
			x = y = z = 0.0;
			break;
	}
	
	self.pullView.layer.transform
		= CATransform3DRotate(self.pullView.layer.transform,
			self.velocity * kMomentumAnimationVelocityScale, x, y, z);
}

/** @brief Remove display link */
- (void)stopMomentumAnimation
{
	if (self.displayLink) {
		[self.displayLink invalidate];
		self.displayLink = nil;
	}
}

/** @brief Start continuous animation on pullView */
- (void)startContinuousAnimation
{
	if (self.pullView
		&& self.refreshStyle != CustomPullToRefreshNone
		&& self.refreshEasing == CustomPullToRefreshContinuous)
	{
		// Setup Animation
		CABasicAnimation *animation;
		
		switch (self.refreshStyle)
		{
			case CustomPullToRefreshSpin:
			{
				animation = [CABasicAnimation animationWithKeyPath:@"transform.rotation"];
				animation.toValue = @(2 * M_PI);
				break;
			}
				
			case CustomPullToRefreshRotate:
			{
				CATransform3D transform = self.pullView.layer.transform;
				transform.m34 = -1/500;
				transform = CATransform3DRotate(transform, M_PI, 0, 1, 0);
				
				animation = [CABasicAnimation animationWithKeyPath:@"transform"];
				animation.autoreverses = true;
				animation.toValue = [NSValue valueWithCATransform3D:transform];
				break;
			}
				
			case CustomPullToRefreshNone:
			default:
				// Do nothing and return - shouldn't get here
				return;
		}
		
		animation.duration = kContinuousAnimationDuration;
		animation.repeatCount = HUGE_VALF;
		[self.pullView.layer addAnimation:animation forKey:@"continuous"];
	}
}

/** @brief Stops all continuous animation on the pullView */
- (void)stopContinuousAnimation
{
	if (self.pullView) {
		[self.pullView.layer removeAnimationForKey:@"continuous"];
	}
}

/** @brief Begins refreshing animation for control, but user must manually 
	set contentOffset to show control (to let them animate as they wish) */
- (void)beginRefreshing
{
    if (!self.refreshing)
	{
        CABasicAnimation *alphaAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
        alphaAnimation.duration = 0.0001;
        alphaAnimation.toValue = [NSNumber numberWithFloat:0];
        alphaAnimation.fillMode = kCAFillModeForwards;
        alphaAnimation.removedOnCompletion = NO;
        [self.shapeLayer addAnimation:alphaAnimation forKey:nil];
        [self.arrowLayer addAnimation:alphaAnimation forKey:nil];
        [self.highlightLayer addAnimation:alphaAnimation forKey:nil];
        
        self.activityIndicator.alpha = 1;
        self.activityIndicator.layer.transform = CATransform3DMakeScale(1, 1, 1);

        CGPoint offset = self.scrollView.contentOffset;
        self.ignoreInset = YES;
        [self.scrollView setContentInset:UIEdgeInsetsMake(kOpenedViewHeight + self.originalContentInset.top, self.originalContentInset.left, self.originalContentInset.bottom, self.originalContentInset.right)];
        self.ignoreInset = NO;
        [self.scrollView setContentOffset:offset animated:NO];

        self.refreshing = YES;
        self.canRefresh = NO;
		
		// Hide pullView if exists
		if (self.pullView) {
			[UIView animateWithDuration:kFadeAnimationDuration animations:^{
				self.pullView.alpha = 0;
			}];
		}
    }
}

/** @brief Cancels refreshing and emits action for listeners */
- (void)cancelRefreshing:(id)sender
{
	[self sendActionsForControlEvents:UIControlEventTouchCancel];
	[self endRefreshing];
}

/** @brief Ends refreshing animation and hides control */
- (void)endRefreshing
{
    if (self.refreshing)
	{
        self.refreshing = NO;
        // Create a temporary retain-cycle, so the scrollView won't be released
        // halfway through the end animation.
        // This allows for the refresh control to clean up the observer,
        // in the case the scrollView is released while the animation is running
        __block UIScrollView *blockScrollView = self.scrollView;
        [UIView animateWithDuration:0.4 animations:^{
            self.ignoreInset = YES;
            [blockScrollView setContentInset:self.originalContentInset];
            self.ignoreInset = NO;
            self.activityIndicator.alpha = 0;
            self.activityIndicator.layer.transform = CATransform3DScale(self.activityIndicator.layer.transform, 0.1, 0.1, 1);
        } completion:^(BOOL finished) {
            [self.shapeLayer removeAllAnimations];
            self.shapeLayer.path = nil;
            self.shapeLayer.shadowPath = nil;
            self.shapeLayer.position = CGPointZero;
            [self.arrowLayer removeAllAnimations];
            self.arrowLayer.path = nil;
            [self.highlightLayer removeAllAnimations];
            self.highlightLayer.path = nil;
            // We need to use the scrollView somehow in the end block,
            // or it'll get released in the animation block.
            self.ignoreInset = YES;
            [blockScrollView setContentInset:self.originalContentInset];
            self.ignoreInset = NO;
        }];
    }
}


#pragma mark - Observer Changes

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"contentInset"]) {
        if (!self.ignoreInset) {
            self.originalContentInset = [[change objectForKey:@"new"] UIEdgeInsetsValue];
            self.frame = CGRectMake(0, -(kTotalViewHeight + self.scrollView.contentInset.top), self.scrollView.frame.size.width, kTotalViewHeight);
        }
        return;
    }
    
    if (!self.enabled || self.ignoreOffset) {
        return;
    }

	// Content offset
	CGPoint offsetPoint = [[change objectForKey:@"new"] CGPointValue];

	// x Offset - Added by Carlin - Move with scroll view
	CGRect selfFrame = self.frame;
	selfFrame.origin.x = offsetPoint.x;
	self.frame = selfFrame;
	
	// y Offset
    CGFloat offset = offsetPoint.y + self.originalContentInset.top;
	
	// Momentum stuff if easing is set
	if (self.refreshEasing == CustomPullToRefreshMomentum)
	{
		// Update acceleration with diff between scroll updates
		CGFloat offsetDiff = MAX(0, -(offset - self.momentumLastOffset));
		self.acceleration += offsetDiff * kMomentumAnimationAccelerationScale;
		self.momentumLastOffset = offset;
	}
	else {	// Reset values
		self.acceleration = 0;
		self.velocity = 0;
	}
  

	#pragma mark - Refresh triggered
	// If refresh already triggered
    if (self.refreshing)
	{
		// If not at resting position (when PTR isn't active)
        if (offset != 0)
		{
			// Invalidate cancel timer if exists
			if (self.cancelTimer) {
				[self.cancelTimer invalidate];
			}
			
			// Keep thing pinned at the top
			[CATransaction begin];
			[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
			self.shapeLayer.position = CGPointMake(0, kMaxDistance + offset + kOpenedViewHeight);
			[CATransaction commit];
		
			if (self.stickToTopWhenRefreshing)
			{
				self.activityIndicator.center = CGPointMake(
					floor(self.frame.size.width / 2),
					MIN(offset + self.frame.size.height + floor(kOpenedViewHeight / 2),
						self.frame.size.height - kOpenedViewHeight/ 2));
			}
			else	// Stay with original position above scrollView
			{
				CGFloat currentBottomRadius = kMaxBottomRadius;
				CGFloat currentBottomPadding = kMaxBottomPadding;
				CGPoint bottomOrigin = CGPointMake(floor(self.bounds.size.width / 2), self.bounds.size.height - currentBottomPadding - currentBottomRadius);
				CGPoint topOrigin = CGPointMake(floor(self.bounds.size.width / 2), bottomOrigin.y);
				
				self.activityIndicator.center = CGPointMake(
					(topOrigin.x - bottomOrigin.x) / 2 + bottomOrigin.x,
					(topOrigin.y - bottomOrigin.y) / 2 + bottomOrigin.y
				);
			}

            self.ignoreInset = YES;
            self.ignoreOffset = YES;
            
            if (offset < 0)
			{
                // Set the inset depending on the situation
                if (offset >= -kOpenedViewHeight) {
                    if (!self.scrollView.dragging) {
                        if (!self.didSetInset) {
                            self.didSetInset = YES;
                            self.hasSectionHeaders = NO;
                            if([self.scrollView isKindOfClass:[UITableView class]]){
                                for (int i = 0; i < [(UITableView *)self.scrollView numberOfSections]; ++i) {
                                    if ([(UITableView *)self.scrollView rectForHeaderInSection:i].size.height) {
                                        self.hasSectionHeaders = YES;
                                        break;
                                    }
                                }
                            }
                        }
                        if (self.hasSectionHeaders) {
                            [self.scrollView setContentInset:UIEdgeInsetsMake(MIN(-offset, kOpenedViewHeight) + self.originalContentInset.top, self.originalContentInset.left, self.originalContentInset.bottom, self.originalContentInset.right)];
                        } else {
                            [self.scrollView setContentInset:UIEdgeInsetsMake(kOpenedViewHeight + self.originalContentInset.top, self.originalContentInset.left, self.originalContentInset.bottom, self.originalContentInset.right)];
                        }
                    } else if (self.didSetInset && self.hasSectionHeaders) {
                        [self.scrollView setContentInset:UIEdgeInsetsMake(-offset + self.originalContentInset.top, self.originalContentInset.left, self.originalContentInset.bottom, self.originalContentInset.right)];
                    }
                }
            }
			else if (self.hasSectionHeaders) {
                [self.scrollView setContentInset:self.originalContentInset];
            }
            self.ignoreInset = NO;
            self.ignoreOffset = NO;
        }
		else if (self.scrollUpToCancel)	// If at resting position & can cancel
		{
			// Clear and restart
			if (self.cancelTimer) {
				[self.cancelTimer invalidate];
			}
			
			// Create timer to see if user leaves in resting position
			self.cancelTimer = [NSTimer scheduledTimerWithTimeInterval:kCancelRefreshDelay target:self selector:@selector(cancelRefreshing:) userInfo:nil repeats:false];
		}
        return;
    }
	
	#pragma mark - Refresh not triggered yet
	else	// Refresh not triggered yet
	{
        // Check if we can trigger a new refresh and if we can draw the control
        BOOL dontDraw = NO;
        if (!self.canRefresh) {
            if (offset >= 0) {
                // We can refresh again after the control is scrolled out of view
                self.canRefresh = YES;
                self.didSetInset = NO;
            } else {
                dontDraw = YES;
            }
        } else {
            if (offset >= 0) {
                // Don't draw if the control is not visible
                dontDraw = YES;
            }
        }
        if (offset > 0 && self.lastOffset > offset && !self.scrollView.isTracking) {
            // If we are scrolling too fast, don't draw, and don't trigger unless the scrollView bounced back
            self.canRefresh = NO;
            dontDraw = YES;
        }
        if (dontDraw) {
            self.shapeLayer.path = nil;
            self.shapeLayer.shadowPath = nil;
            self.arrowLayer.path = nil;
            self.highlightLayer.path = nil;
            self.lastOffset = offset;
            return;
        }
    }
    
    self.lastOffset = offset;
    
    BOOL triggered = NO;

	
	#pragma mark - Drawing
    
    // Calculate some useful points and values
    CGFloat verticalShift = MAX(0, -((kMaxTopRadius + kMaxBottomRadius + kMaxTopPadding + kMaxBottomPadding) + offset));
    CGFloat distance = MIN(kMaxDistance, fabs(verticalShift));
    CGFloat percentage = 1 - (distance / kMaxDistance);
    
	// Draw drip or not?
    CGFloat currentTopPadding = (self.enableDiskDripEffect)
		? lerp(kMinTopPadding, kMaxTopPadding, percentage)
		: kMaxTopPadding;
    CGFloat currentTopRadius = (self.enableDiskDripEffect)
		? lerp(kMinTopRadius, kMaxTopRadius, percentage)
		: kMaxTopRadius;
    CGFloat currentBottomRadius = (self.enableDiskDripEffect)
		? lerp(kMinBottomRadius, kMaxBottomRadius, percentage)
		: kMaxBottomRadius;
    CGFloat currentBottomPadding = (self.enableDiskDripEffect)
		? lerp(kMinBottomPadding, kMaxBottomPadding, percentage)
		: kMaxBottomPadding;
    
    CGPoint bottomOrigin = CGPointMake(floor(self.bounds.size.width / 2), self.bounds.size.height - currentBottomPadding - currentBottomRadius);
    CGPoint topOrigin = CGPointZero;
	
	// Set distance of topOrigin for drawing
    if (distance == 0) {
        topOrigin = CGPointMake(floor(self.bounds.size.width / 2), bottomOrigin.y);
    }
	else	// Being pulled / dragged
	{
        topOrigin = CGPointMake(
			floor(self.bounds.size.width / 2),
			(self.enableDiskDripEffect)
				? self.bounds.size.height + offset
					+ currentTopPadding + currentTopRadius
				: bottomOrigin.y
		);
        if (percentage == 0) {
            bottomOrigin.y -= (fabs(verticalShift) - kMaxDistance);
            triggered = YES;
        }
    }
	
    // Top semicircle
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddArc(path, NULL, topOrigin.x, topOrigin.y, currentTopRadius, 0, M_PI, YES);
    
    //Left curve
    CGPoint leftCp1 = CGPointMake(lerp((topOrigin.x - currentTopRadius), (bottomOrigin.x - currentBottomRadius), 0.1), lerp(topOrigin.y, bottomOrigin.y, 0.2));
    CGPoint leftCp2 = CGPointMake(lerp((topOrigin.x - currentTopRadius), (bottomOrigin.x - currentBottomRadius), 0.9), lerp(topOrigin.y, bottomOrigin.y, 0.2));
    CGPoint leftDestination = CGPointMake(bottomOrigin.x - currentBottomRadius, bottomOrigin.y);
    
    CGPathAddCurveToPoint(path, NULL, leftCp1.x, leftCp1.y, leftCp2.x, leftCp2.y, leftDestination.x, leftDestination.y);
    
	// Bottom semicircle
	CGPathAddArc(path, NULL, bottomOrigin.x, bottomOrigin.y, currentBottomRadius, M_PI, 0, YES);
    
    //Right curve
    CGPoint rightCp2 = CGPointMake(lerp((topOrigin.x + currentTopRadius), (bottomOrigin.x + currentBottomRadius), 0.1), lerp(topOrigin.y, bottomOrigin.y, 0.2));
    CGPoint rightCp1 = CGPointMake(lerp((topOrigin.x + currentTopRadius), (bottomOrigin.x + currentBottomRadius), 0.9), lerp(topOrigin.y, bottomOrigin.y, 0.2));
    CGPoint rightDestination = CGPointMake(topOrigin.x + currentTopRadius, topOrigin.y);
    
    CGPathAddCurveToPoint(path, NULL, rightCp1.x, rightCp1.y, rightCp2.x, rightCp2.y, rightDestination.x, rightDestination.y);
    CGPathCloseSubpath(path);
    
    if (!triggered)		// Refresh not triggered yet, set paths
	{
		// Draw disk or not?
		if (self.drawDiskWhenPulling)
		{
			self.shapeLayer.path = path;
			self.shapeLayer.shadowPath = path;
		}
        
        // Add the arrow shape
        CGFloat currentArrowSize = lerp(kMinArrowSize, kMaxArrowSize, percentage);
        CGFloat currentArrowRadius = lerp(kMinArrowRadius, kMaxArrowRadius, percentage);
        CGFloat arrowBigRadius = currentArrowRadius + (currentArrowSize / 2);
        CGFloat arrowSmallRadius = currentArrowRadius - (currentArrowSize / 2);
		
		
		#pragma mark - Custom PullView Animation
		// Draw arrow or custom image
		if (self.pullView)
		{
			// Show pullView if exists
			self.pullView.alpha = 1;
			
			// Set bounds & center instead of changing frame,
			//	because changing the frame messes up transformation
			self.pullView.bounds = CGRectMake(
				topOrigin.x - arrowBigRadius * kArrowViewSize / 2,
				topOrigin.y - arrowBigRadius * kArrowViewSize / 2,
				arrowBigRadius * kArrowViewSize,
				arrowBigRadius * kArrowViewSize);
			self.pullView.center = CGPointMake(
				self.pullView.bounds.origin.x
					+ self.pullView.bounds.size.width / 2,
				self.pullView.bounds.origin.y
					+ self.pullView.bounds.size.height / 2
			);
		
			// Animation for Linear style, other styles managed elsewhere
			if (self.refreshEasing == CustomPullToRefreshLinear)
			{
				CGFloat angle = lerp(0, 2 * M_PI, percentage);
				
				switch (self.refreshStyle)
				{
					case CustomPullToRefreshSpin: {
						self.pullView.layer.transform
							= CATransform3DMakeRotation(angle, 0.0, 0.0, 1.0);
						break;
					}
					
					case CustomPullToRefreshRotate: {
						self.pullView.layer.transform
							= CATransform3DMakeRotation(angle, 0.0, 1.0, 0.0);
						break;
					}
					
					case CustomPullToRefreshNone:
					default:
						// Do nothing
						break;
				}
			}
		}
		else	// Draw arrow
		{
			CGMutablePathRef arrowPath = CGPathCreateMutable();
			CGPathAddArc(arrowPath, NULL, topOrigin.x, topOrigin.y, arrowBigRadius, 0, 3 * M_PI_2, NO);
			CGPathAddLineToPoint(arrowPath, NULL, topOrigin.x, topOrigin.y - arrowBigRadius - currentArrowSize);
			CGPathAddLineToPoint(arrowPath, NULL, topOrigin.x + (2 * currentArrowSize), topOrigin.y - arrowBigRadius + (currentArrowSize / 2));
			CGPathAddLineToPoint(arrowPath, NULL, topOrigin.x, topOrigin.y - arrowBigRadius + (2 * currentArrowSize));
			CGPathAddLineToPoint(arrowPath, NULL, topOrigin.x, topOrigin.y - arrowBigRadius + currentArrowSize);
			CGPathAddArc(arrowPath, NULL, topOrigin.x, topOrigin.y, arrowSmallRadius, 3 * M_PI_2, 0, YES);
			CGPathCloseSubpath(arrowPath);
			self.arrowLayer.path = arrowPath;
			[self.arrowLayer setFillRule:kCAFillRuleEvenOdd];
			CGPathRelease(arrowPath);
			
			// Add the highlight shape
			
			CGMutablePathRef highlightPath = CGPathCreateMutable();
			CGPathAddArc(highlightPath, NULL, topOrigin.x, topOrigin.y, currentTopRadius, 0, M_PI, YES);
			CGPathAddArc(highlightPath, NULL, topOrigin.x, topOrigin.y + 1.25, currentTopRadius, M_PI, 0, NO);
			
			self.highlightLayer.path = highlightPath;
			[self.highlightLayer setFillRule:kCAFillRuleNonZero];
			CGPathRelease(highlightPath);
		}
        
    }
	
	#pragma mark - Triggered Refresh Animation
	else	// Triggered refresh
	{
        // Start the shape disappearance animation
        CGFloat radius = lerp(kMinBottomRadius, kMaxBottomRadius, 0.2);
        CABasicAnimation *pathMorph = [CABasicAnimation animationWithKeyPath:@"path"];
        pathMorph.duration = 0.15;
        pathMorph.fillMode = kCAFillModeForwards;
        pathMorph.removedOnCompletion = NO;
        CGMutablePathRef toPath = CGPathCreateMutable();
        CGPathAddArc(toPath, NULL, topOrigin.x, topOrigin.y, radius, 0, M_PI, YES);
        CGPathAddCurveToPoint(toPath, NULL, topOrigin.x - radius, topOrigin.y, topOrigin.x - radius, topOrigin.y, topOrigin.x - radius, topOrigin.y);
        CGPathAddArc(toPath, NULL, topOrigin.x, topOrigin.y, radius, M_PI, 0, YES);
        CGPathAddCurveToPoint(toPath, NULL, topOrigin.x + radius, topOrigin.y, topOrigin.x + radius, topOrigin.y, topOrigin.x + radius, topOrigin.y);
        CGPathCloseSubpath(toPath);
        pathMorph.toValue = (__bridge id)toPath;
        [self.shapeLayer addAnimation:pathMorph forKey:nil];
        CABasicAnimation *shadowPathMorph = [CABasicAnimation animationWithKeyPath:@"shadowPath"];
        shadowPathMorph.duration = 0.15;
        shadowPathMorph.fillMode = kCAFillModeForwards;
        shadowPathMorph.removedOnCompletion = NO;
        shadowPathMorph.toValue = (__bridge id)toPath;
        [self.shapeLayer addAnimation:shadowPathMorph forKey:nil];
        CGPathRelease(toPath);
        CABasicAnimation *shapeAlphaAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
        shapeAlphaAnimation.duration = 0.1;
        shapeAlphaAnimation.beginTime = CACurrentMediaTime() + 0.1;
        shapeAlphaAnimation.toValue = [NSNumber numberWithFloat:0];
        shapeAlphaAnimation.fillMode = kCAFillModeForwards;
        shapeAlphaAnimation.removedOnCompletion = NO;
        [self.shapeLayer addAnimation:shapeAlphaAnimation forKey:nil];
        CABasicAnimation *alphaAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
        alphaAnimation.duration = 0.1;
        alphaAnimation.toValue = [NSNumber numberWithFloat:0];
        alphaAnimation.fillMode = kCAFillModeForwards;
        alphaAnimation.removedOnCompletion = NO;
        [self.arrowLayer addAnimation:alphaAnimation forKey:nil];
        [self.highlightLayer addAnimation:alphaAnimation forKey:nil];
        
        [CATransaction begin];
        [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
        self.activityIndicator.layer.transform = CATransform3DMakeScale(0.1, 0.1, 1);
        [CATransaction commit];
        [UIView animateWithDuration:0.2 delay:0.15 options:UIViewAnimationOptionCurveLinear animations:^{
            self.activityIndicator.alpha = 1;
            self.activityIndicator.layer.transform = CATransform3DMakeScale(1, 1, 1);
        } completion:nil];

		// Hide pullView if exists
		if (self.pullView) {
			[UIView animateWithDuration:kFadeAnimationDuration animations:^{
				self.pullView.alpha = 0;
			}];
		}
        
        self.refreshing = YES;
        self.canRefresh = NO;
        [self sendActionsForControlEvents:UIControlEventValueChanged];
    }
    
    CGPathRelease(path);
}

@end
