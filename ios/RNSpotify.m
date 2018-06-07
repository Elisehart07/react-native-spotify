
#import "RNSpotify.h"
#import <AVFoundation/AVFoundation.h>
#import <SpotifyAuthentication/SpotifyAuthentication.h>
#import "RNSpotifyAuthController.h"
#import "RNSpotifyProgressView.h"
#import "RNSpotifyConvert.h"
#import "RNSpotifyCompletion.h"
#import "HelperMacros.h"

@interface RNSpotify() 
{
	BOOL _initialized;

	BOOL _loggingIn;

	SPTAuth* _auth;
	
	NSDictionary* _options;
	
	BOOL _renewingSession;

	NSMutableArray<RNSpotifyCompletion*>* _renewCallbacks;
}

+(RNSpotify *) sharedInstance;

+(NSMutableDictionary*)mutableDictFromDict:(NSDictionary*)dict;


-(void)logBackInIfNeeded:(RNSpotifyCompletion*)completion waitForDefinitiveResponse:(BOOL)waitForDefinitiveResponse;


@end

@implementation RNSpotify

static RNSpotify *sharedInstance = nil;


+ (RNSpotify *)sharedInstance
{
    @synchronized(self) {
        if (sharedInstance == nil) {
            sharedInstance = [[self alloc] init];
        }
    }
    return sharedInstance;
}

@synthesize bridge = _bridge;

-(id)init
{
	if(self = [super init])
	{
		_initialized = NO;
		_loggingIn = NO;

		_auth = nil;
		
		_options = nil;
		
		_renewingSession = NO;
		_renewCallbacks = [NSMutableArray array];
			}
	return self;
}

+(BOOL)requiresMainQueueSetup
{
	return NO;
}

RCT_EXPORT_METHOD(__registerAsJSEventEmitter:(int)moduleId)
{
	[RNEventEmitter registerEventEmitterModule:self withID:moduleId bridge:_bridge];
}

+(id)reactSafeArg:(id)arg
{
	if(arg==nil)
	{
		return [NSNull null];
	}
	return arg;
}

+(NSMutableDictionary*)mutableDictFromDict:(NSDictionary*)dict
{
	if(dict==nil)
	{
		return [NSMutableDictionary dictionary];
	}
	return dict.mutableCopy;
}


#pragma mark - React Native functions

RCT_EXPORT_MODULE()

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(test)
{
	NSLog(@"ayy lmao");
	return [NSNull null];
}

RCT_EXPORT_METHOD(initialize:(NSDictionary*)options resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
	if(_initialized)
	{
		[RNSpotifyErrorCode.AlreadyInitialized reject:reject];
		return;
	}
	
	// ensure options is not null or missing fields
	if(options == nil)
	{
		[[RNSpotifyError nullParameterErrorForName:@"options"] reject:reject];
		return;
	}
	else if(options[@"clientID"] == nil)
	{
		[[RNSpotifyError missingOptionErrorForName:@"clientID"] reject:reject];
		return;
	}
	
	// load default options
	_options = options;
	_auth = [SPTAuth defaultInstance];

	// load auth options
	_auth.clientID = options[@"clientID"];
	_auth.redirectURL = [NSURL URLWithString:options[@"redirectURL"]];
	_auth.sessionUserDefaultsKey = options[@"sessionUserDefaultsKey"];
	_auth.requestedScopes = options[@"scopes"];
	_auth.tokenSwapURL = [NSURL URLWithString:options[@"tokenSwapURL"]];
	_auth.tokenRefreshURL = [NSURL URLWithString:options[@"tokenRefreshURL"]];
	
	// load iOS-specific options
	NSDictionary* iosOptions = options[@"ios"];
	if(iosOptions == nil)
	{
		iosOptions = @{};
	}
	
	// done initializing
	_initialized = YES;
	
	// call callback
	NSNumber* loggedIn = [self isLoggedIn];
	resolve(loggedIn);

	[self logBackInIfNeeded:[RNSpotifyCompletion<NSNumber*> onReject:^(RNSpotifyError* error) {
		// failure
	} onResolve:^(NSNumber* loggedIn) {
		// success
	}] waitForDefinitiveResponse:YES];
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(isInitialized)
{
	if(_auth==nil)
	{
		return @NO;
	}
	return [NSNumber numberWithBool:_initialized];
}

RCT_EXPORT_METHOD(isInitializedAsync:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
	resolve([self isInitialized]);
}



#pragma mark - React Native functions - Session Handling

-(void)logBackInIfNeeded:(RNSpotifyCompletion*)completion waitForDefinitiveResponse:(BOOL)waitForDefinitiveResponse
{
	// ensure auth is actually logged in
	if(_auth.session == nil)
	{
		[completion resolve:@NO];
		return;
	}
	// attempt to renew auth session
	[self renewSessionIfNeeded:[RNSpotifyCompletion onReject:^(RNSpotifyError* error) {
		// session renewal failed (we should log out)
		[completion resolve:@NO];
	} onResolve:^(id unused) {
		// success
		[completion resolve:@YES];
	}] waitForDefinitiveResponse:waitForDefinitiveResponse];
}

-(void)renewSessionIfNeeded:(RNSpotifyCompletion*)completion waitForDefinitiveResponse:(BOOL)waitForDefinitiveResponse
{
	if(_auth.session == nil)
	{
		// not logged in
		[completion resolve:@NO];
	}
	else if(_auth.session.isValid)
	{
		// session does not need renewal
		[completion resolve:@NO];
	}
	else if(_auth.session.encryptedRefreshToken == nil)
	{
		// no refresh token to renew session with, so the session has expired
		[completion reject:[RNSpotifyError errorWithCodeObj:RNSpotifyErrorCode.SessionExpired]];
	}
	else
	{
		[self renewSession:[RNSpotifyCompletion onReject:^(RNSpotifyError* error) {
			[completion reject:error];
		} onResolve:^(id result) {
			[completion resolve:result];
		}] waitForDefinitiveResponse:waitForDefinitiveResponse];
	}
}

-(void)renewSession:(RNSpotifyCompletion*)completion waitForDefinitiveResponse:(BOOL)waitForDefinitiveResponse
{
	dispatch_async(dispatch_get_main_queue(), ^{
		if(_auth.session == nil)
		{
			[completion reject:[RNSpotifyError errorWithCodeObj:RNSpotifyErrorCode.NotLoggedIn]];
			return;
		}
		else if(!_auth.hasTokenRefreshService)
		{
			[completion resolve:@NO];
			return;
		}
		else if(_auth.session.encryptedRefreshToken == nil)
		{
			[completion resolve:@NO];
			return;
		}
		
		// add completion to be called when the renewal finishes
		if(completion != nil)
		{
			[_renewCallbacks addObject:completion];
		}
		
		// if we're already in the process of renewing the session, don't continue
		if(_renewingSession)
		{
			return;
		}
		_renewingSession = YES;
		
		// renew session
		[_auth renewSession:_auth.session callback:^(NSError* error, SPTSession* session){
			dispatch_async(dispatch_get_main_queue(), ^{
				_renewingSession = NO;
				
				if(session != nil && _auth.session != nil)
				{
					_auth.session = session;
				}
				
				id renewed = @NO;
				if(session != nil)
				{
					renewed = @YES;
				}
				
				//TODO figure out what SPTAuth.renewSession does if the internet is not connected (probably throws an error)
				
				NSArray<RNSpotifyCompletion*>* renewCallbacks = [NSArray arrayWithArray:_renewCallbacks];
				[_renewCallbacks removeAllObjects];
				for(RNSpotifyCompletion* completion in renewCallbacks)
				{
					if(error != nil)
					{
						[completion reject:[RNSpotifyError errorWithNSError:error]];
					}
					else
					{
						[completion resolve:renewed];
					}
				}
			});
		}];
	});
}

RCT_EXPORT_METHOD(login:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
	// ensure we're not already logging in
	if(_loggingIn)
	{
		[[RNSpotifyError errorWithCodeObj:RNSpotifyErrorCode.ConflictingCallbacks message:@"Cannot call login multiple times before completing"] reject:reject];
		return;
	}
	_loggingIn = YES;   

    RNSpotify *spotifyModule = (RNSpotify *)[RNSpotify sharedInstance];
	// do UI logic on main thread
	dispatch_async(dispatch_get_main_queue(), ^{    
        
        RNSpotify *spotifyModule = (RNSpotify *)[RNSpotify sharedInstance];
        spotifyModule.loginCallbackResolve = resolve;

         if ([SPTAuth supportsApplicationAuthentication]) {

            //open spotiyf
            [[RNSpotifyAuthController alloc] initWithAuthApp:_auth];
            
        } else {

            RNSpotifyAuthController* authController = [[RNSpotifyAuthController alloc] initWithAuthWeb:_auth];
            
            // present auth view controller
            UIViewController* topViewController = [RNSpotifyAuthController topViewController];
            [topViewController presentViewController:authController animated:YES completion:nil];
        }
	});
}

RCT_EXPORT_METHOD(logout:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    _auth.session = nil;
    resolve(nil);
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(isLoggedIn)
{
	if(!_initialized)
	{
		return @NO;
	}
	else if(_auth.session == nil)
	{
		return @NO;
	}
	return @YES;
}

RCT_EXPORT_METHOD(isLoggedInAsync:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
	resolve([self isLoggedIn]);
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(getAuth)
{
	return [RNSpotifyConvert SPTAuth:_auth];
}

RCT_EXPORT_METHOD(getAuthAsync:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
	resolve([RNSpotifyConvert ID:[self getAuth]]);
}

@end