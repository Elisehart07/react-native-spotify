//
//  RNSpotifyAuthController.m
//  RNSpotify
//
//  Created by Luis Finke on 11/5/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import "RNSpotifyAuthController.h"
#import "RNSpotifyWebViewController.h"
#import "RNSpotifyProgressView.h"

#import "RNSpotify.h"

@interface RNSpotifyAuthController() <UIWebViewDelegate>
{
	SPTAuth* _auth;
	RNSpotifyWebViewController* _webController;
	RNSpotifyProgressView* _progressView;
}
-(void)didSelectCancelButton;
@end

@implementation RNSpotifyAuthController

+(UIViewController*)topViewController
{
	UIViewController* topController = [UIApplication sharedApplication].keyWindow.rootViewController;
	while(topController.presentedViewController != nil)
	{
		topController = topController.presentedViewController;
	}
	return topController;
}

-(id)initWithAuthWeb:(SPTAuth*)auth
{
    _auth = auth;

    RNSpotifyWebViewController* rootController = [[RNSpotifyWebViewController alloc] init];
    if(self = [super initWithRootViewController:rootController])
    {
    
        _webController = rootController;
        _progressView = [[RNSpotifyProgressView alloc] init];
        
        self.navigationBar.barTintColor = [UIColor blackColor];
        self.navigationBar.tintColor = [UIColor whiteColor];
        self.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName : [UIColor whiteColor]};
        self.view.backgroundColor = [UIColor whiteColor];
        self.modalPresentationStyle = UIModalPresentationFormSheet;
        
        _webController.webView.delegate = self;
        //_webController.title = @"Log into Spotify";
        _webController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(didSelectCancelButton)];
    
        NSURLRequest* request = [NSURLRequest requestWithURL:_auth.spotifyWebAuthenticationURL];
        [_webController.webView loadRequest:request];
    }
    

	return self;
}

-(id)initWithAuthApp:(SPTAuth*)auth
{
    _auth = auth;
    
    UIApplication *application = [UIApplication sharedApplication];
    [application openURL:_auth.spotifyAppAuthenticationURL options:@{} completionHandler:^(BOOL success) {
        if (success) {
            NSLog(@"Opened %@",_auth.spotifyAppAuthenticationURL);
        }
    }];

	return self;
}

-(UIStatusBarStyle)preferredStatusBarStyle
{
	return UIStatusBarStyleLightContent;
}

-(void)didSelectCancelButton
{
    [[self topViewController] dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark - UIWebViewDelegate

-(BOOL)webView:(UIWebView*)webView shouldStartLoadWithRequest:(NSURLRequest*)request navigationType:(UIWebViewNavigationType)navigationType
{
    RNSpotify *spotifyModule = (RNSpotify *) [RNSpotify sharedInstance];

	if([_auth canHandleURL:request.URL])
	{
		[_progressView showInView:self.view animated:YES completion:nil];
		[_auth handleAuthCallbackWithTriggeredAuthURL:request.URL callback:^(NSError* error, SPTSession* session){
			if(session!=nil)
			{
				_auth.session = session;
			}
			
			if(error == nil)
			{
				// success
				spotifyModule.loginCallbackResolve(@YES);
			}
			else
			{
				spotifyModule.loginCallbackResolve(@NO);
			}

            [[self topViewController] dismissViewControllerAnimated:YES completion:nil];
		}];
		return NO;
	}
	return YES;
}

@end
