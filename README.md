Based off Fabio Ritrovato's ODRefreshControl.

Added features by Carlin:

 * Custom animation styles - using linear and momentum "easing", and spin
   or rotate transforms.
 * Custom stroke & shadow colors.
 * Custom ImageView in place of arrow, with fun spin animation.
 * Added functionality to reposition if scrollview gets scrolled horizontally.
 
![Enhancements](/screenshot.png "Enhancements")

Known Issues:

 * It looks like if you set this on a regular UIScrollView and enable paging, the activity indicator doesn't stay at the top. Working on this.
 * To get your UIScrollView to scroll vertically and show the refresh control, either set the contentsize a pixel larger than the scrollview frame, or set vertical bounces to enabled.

-----------------------
ODRefreshControl Readme

__*Important note if your project doesn't use ARC*: you must add the @-fobjc-arc@ compiler flag to @ODRefreshControl.m@ in Target Settings > Build Phases > Compile Sources.__

*If you are using ODRefreshControl in your app, drop me a line so I can add your app here!*

h1. ODRefreshControl

![Screenshot](http://www.orangeinaday.com/img/ODRefreshControl.jpg "ODRefresh")

ODRefreshControl is a "pull down to refresh" control for UIScrollView, like the one Apple introduced in iOS6, but available to anyone from iOS4 and up.

h2. Installation

* Drag the @ODRefreshControl/ODRefreshControl@ folder into your project.
* Add the *QuartzCore* framework to your project.
* @#import "ODRefreshControl.h"@

h2. Usage

(see sample Xcode project in @/Demo@)

h3. Adding a refresh control to your table view

<pre>
ODRefreshControl *refreshControl = [[ODRefreshControl alloc] initInScrollView:self.scrollView];
</pre>

To know when the refresh operation has started, add an action method to the UIControlEventValueChanged event of the control

<pre>
[refreshControl addTarget:self action:@selector(dropViewDidBeginRefreshing:) forControlEvents:UIControlEventValueChanged];
</pre>

If you’d like to programmatically start the refresh operation, use

<pre>
[refreshControl beginRefreshing];
</pre>

Remember to tell the control when the refresh operation has ended

<pre>
[refreshControl endRefreshing];
</pre>

h4. Customization

The @ODRefreshControl@ can be customized using the following properties:

<pre>
@property (nonatomic, strong) UIColor *tintColor;
@property (nonatomic, assign) UIActivityIndicatorViewStyle activityIndicatorViewStyle;
@property (nonatomic, strong) UIColor *activityIndicatorViewColor; // iOS5 or more
</pre>

h2. Credits

ODRefreshControl is brought to you by "Fabio Ritrovato":http://orangeinaday.com and "contributors to the project":https://github.com/Sephiroth87/ODRefreshControl/contributors. If you have feature suggestions or bug reports, feel free to help out by sending pull requests or by "creating new issues":https://github.com/Sephiroth87/ODRefreshControl/issues/new. If you're using ODRefreshControl in your project, attribution would be nice.
!https://cruel-carlota.pagodabox.com/a9d517c98620f7f8e865458f744c1cbb!
