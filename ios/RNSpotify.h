
#if __has_include("RCTBridgeModule.h")
#import "RCTBridgeModule.h"
#else
#import <React/RCTBridgeModule.h>
#endif

#if __has_include("RNEventEmitter.h")
#import "RNEventEmitter.h"
#else
#import <RNEventEmitter/RNEventEmitter.h>
#endif

@interface RNSpotify : NSObject <RCTBridgeModule, RNEventConformer>


@property (nonatomic, copy) RCTPromiseResolveBlock loginCallbackResolve;
@property (nonatomic, copy) RCTPromiseRejectBlock loginCallbackReject;

+ (RNSpotify *) sharedInstance;


-(id)test;

//initialize(options)
-(void)initialize:(NSDictionary*)options resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject;
//isInitialized()
-(id)isInitialized;
//isInitializedAsync()
-(void)isInitializedAsync:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject;

//login()
-(void)login:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject;
//logout()
-(void)logout:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject;
//isLoggedIn()
-(id)isLoggedIn;
//isLoggedInAsync()
-(void)isLoggedInAsync:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject;
//getAuth()
-(id)getAuth;
//getAuthAsync()
-(void)getAuthAsync:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject;

@end
