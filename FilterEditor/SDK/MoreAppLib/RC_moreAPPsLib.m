//
//  RC_moreAPPsLib.m
//  RC_moreAPPsLib
//
//  Created by wsq-wlq on 14-11-25.
//  Copyright (c) 2014年 wsq-wlq. All rights reserved.
//

#import "RC_moreAPPsLib.h"

#import "Reachability.h"
#import "RC_AppInfo.h"
#import "UIImageView+WebCache.h"
#import "SDWebImageManager.h"
#import "RC_PopUpADView.h"
#import <sqlite3.h>
#import "RC_MoreTableViewCell.h"
#import "AFHTTPRequestOperationManager.h"
#import "SDWebImagePrefetcher.h"
#import "GADInterstitialDelegate.h"
#import "MobClick.h"
#import "RC_GetPath.h"
#import "RC_MoreAppDefines.h"


#define kRequestMoreAppDateKey @"kRequestMoreAppDateKey"

#define kAppsInfoFileName @"AppsInfo.sql"

#define kCustomMaxShowTimesKey @"customMaxShowTimes"
#define kAdmobMaxShowTimesKey @"admobMaxShowTimes"
#define kCustomCanShowTimesKey @"customCanShowTimes"
#define kAdmobCanShowTimesKey @"admobCanShowTimes"

#define kRequestDateKey @"requestAdMobDate"
#define kRequestAppDateKey @"requestAppDate"
#define krefreshTimeKey @"refreshtimekey"
#define kcutomAdRect [UIScreen mainScreen].bounds

#define kCustomAdAppCount @"popAppCount"
#define kShareAdShowCount @"shareAdshowCount"

#define isFirstLaunch @"firstLaunch"
#define NewMoreApp @"RC_isNewMoreApp"

#import "GADInterstitial.h"
#import "GADRequest.h"


@class GADRequest;

static RC_moreAPPsLib *picObject = nil;

@interface RC_moreAPPsLib ()<UITableViewDataSource,UITableViewDelegate,GADInterstitialDelegate>

{
    BOOL isbecomeActivity;
    BOOL isPopUping;
    BOOL isMoreApping;
    BOOL isShare;
    BOOL isPopingAdmob;
    UIView *customADView;
    sqlite3 *_database;
    UITableView *appInfoTableView;
}
@property (nonatomic, strong) AFHTTPRequestOperationManager *manager;
@property (nonatomic, assign) NSInteger CustomMaxShowTimes;
@property (nonatomic, assign) NSInteger AdmobMaxshowTimes;
@property (nonatomic, assign) NSInteger CustomCanshowTimes;
@property (nonatomic, assign) NSInteger AdmobCanShowTimes;

@property (nonatomic, strong) RC_AppInfo *temAppInfo;
@property (nonatomic, strong) NSString *popAppInfoID;
@property (nonatomic, strong) NSString *shareAppInfoID;
@property (nonatomic, strong) RC_PopUpADView *popCell;
@property (nonatomic, strong) RC_PopUpADView *sharePopCell;
@property (nonatomic, strong) NSMutableArray *moreAPPSArray;
@property (nonatomic, strong) NSMutableArray *appInfoTableArray;
@property (nonatomic, strong) UIApplication *appDelegate;

@property (nonatomic, strong) GADInterstitial *intersitial;
@property (nonatomic, strong) NSString *admobKey;

@property (nonatomic, strong) UIViewController *returnAPPVC;
@property (nonatomic, strong) UIViewController *popViewController;

@property (nonatomic, strong) UINavigationController *returnMoreAppNav;

@property (nonatomic, strong) NSDictionary *attributeDic;
@property (nonatomic, assign) UIBackgroundTaskIdentifier bgTask;


@end

@implementation RC_moreAPPsLib

@synthesize temAppInfo;
@synthesize popAppInfoID;
@synthesize shareAppInfoID;
@synthesize popCell;
@synthesize sharePopCell;
@synthesize moreAPPSArray;
@synthesize intersitial;
@synthesize admobKey = _admobKey;
@synthesize returnAPPVC;
@synthesize popViewController = _popViewController;
@synthesize returnMoreAppNav;
@synthesize attributeDic;
@synthesize bgTask;

- (id)init
{
    if (self = [super init]) {
        self.manager = [AFHTTPRequestOperationManager manager];
        //        self.manager.responseSerializer = [[AFHTTPResponseSerializer alloc] init];
        self.manager.requestSerializer = [AFHTTPRequestSerializer serializer];
        self.manager.responseSerializer = [AFHTTPResponseSerializer serializer];
        
//        popCell = [[PopUpADView alloc]init];
        [RC_PopUpADView class];
        [RC_MoreTableViewCell class];
        
        popCell = [[[RC_GetPath getBundle] loadNibNamed:@"RC_PopUpADView" owner:self options:nil] objectAtIndex:0];
        sharePopCell = [[[RC_GetPath getBundle] loadNibNamed:@"RC_PopUpADView" owner:self options:nil] objectAtIndex:0];
        returnAPPVC = [[UIViewController alloc]init];
        returnMoreAppNav = [[UINavigationController alloc]initWithRootViewController:returnAPPVC];
        returnMoreAppNav.navigationBarHidden = NO;
        returnMoreAppNav.navigationBar.translucent = NO;

        attributeDic = [[NSDictionary alloc]init];
        
        moreAPPSArray = [[NSMutableArray alloc]init];
        self.moreAPPSArray = [self getAllAppInfoData];
        self.appInfoTableArray = [[NSMutableArray alloc]init];
        self.appInfoTableArray = RC_changeMoreTurnArray(self.moreAPPSArray);
        [self addObservers];
        
        picObject.appDelegate = [UIApplication sharedApplication];
        
        isbecomeActivity = YES;
        
        NSUserDefaults *userDefault = [NSUserDefaults standardUserDefaults];
        //判断首次安装第一次启动
        if ([userDefault objectForKey:isFirstLaunch] == nil)
        {
            [userDefault setObject:[NSNumber numberWithBool:YES] forKey:isFirstLaunch];
            [userDefault setObject:@"0" forKey:@"MoreAPP"];
            [userDefault synchronize];
        }
        else
        {
            [userDefault setObject:[NSNumber numberWithBool:NO] forKey:isFirstLaunch];
            [userDefault synchronize];
        }
    }
    return self;
}

#pragma mark -
#pragma mark 设置admob
- (void)admobSetting
{
    if ([self checkNetWorking])
    {
        intersitial = [[GADInterstitial alloc] init];
        intersitial.delegate = self;
        intersitial.adUnitID = _admobKey;
        [GADRequest request].testDevices = @[ @"05dd3d6aeb38ff2ca6206269e0c0da8c" ];
        [intersitial loadRequest:[GADRequest request]];
        
        NSLog(@"已请求Admob");
    }
}

- (void)setAdmobKey:(NSString *)admobKey
{
    _admobKey = admobKey;

    NSNumber *times = [[NSUserDefaults standardUserDefaults] objectForKey:kAdmobCanShowTimesKey];
    if (times.integerValue > 0 && (intersitial.isReady == NO || ( intersitial.isReady == YES && intersitial.hasBeenUsed == YES)))
    {
        [self admobSetting];
    }
}

- (void)interstitialDidReceiveAd:(GADInterstitial *)ad
{
    NSLog(@"ads is ready");
}
- (void)interstitialWillDismissScreen:(GADInterstitial *)ad
{
    isPopingAdmob = NO;
    NSNumber *times = [[NSUserDefaults standardUserDefaults] objectForKey:kAdmobCanShowTimesKey];
    if (times.integerValue > 0 && (intersitial.isReady == NO || ( intersitial.isReady == YES && intersitial.hasBeenUsed == YES)))
    {
        [self admobSetting];
    }
}
- (void)interstitial:(GADInterstitial *)ad didFailToReceiveAdWithError:(GADRequestError *)error
{
    NSLog(@"ads is not ready");
    NSNumber *times = [[NSUserDefaults standardUserDefaults] objectForKey:kAdmobCanShowTimesKey];
    if (times.integerValue > 0 && (intersitial.isReady == NO || ( intersitial.isReady == YES && intersitial.hasBeenUsed == YES)))
    {
        [self admobSetting];
    }
}


- (void)addObservers
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationEnterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationTerminate:)
                                                 name:UIApplicationWillTerminateNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(cellSelected:)
                                                 name:@"call"
                                               object:nil];
}

+ (id)shareAdManager
{
    if (picObject == nil)
    {
        picObject = [[RC_moreAPPsLib alloc]init];
    }
    return picObject;
}

- (BOOL)isMultitaskingSupported{
    
    BOOL result;
    if ([[UIDevice currentDevice]respondsToSelector:@selector(isMultitaskingSupported)]) {
        result = [[UIDevice currentDevice] isMultitaskingSupported];
    }
    return result;
}

- (void)applicationEnterBackground:(UIApplication *)application
{
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:NO] forKey:isFirstLaunch];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    UIApplication *app = [UIApplication sharedApplication];
    
    //检测多任务的可用性
    if ([self isMultitaskingSupported] == NO) {
        return;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //定义要完成的任务 ，开始执行，
        [self PrefetcherURLs:self.appInfoTableArray];
        
//        [app endBackgroundTask: bgTask];
//        bgTask = UIBackgroundTaskInvalid;
    });
    
    
    //返回一个任务标识
    bgTask = [app beginBackgroundTaskWithExpirationHandler:^(void){
        // do something 。。。
        
        //结束该任务
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        //将任务标识符标记为 UIBackgroundTasksInvalid,标志任务结束
        bgTask = UIBackgroundTaskInvalid;
    }];
    
    
}

- (void)applicationEnterForeground:(UIApplication *)application
{
    
    isbecomeActivity = YES;
    self.appInfoTableArray = RC_changeMoreTurnArray(self.moreAPPSArray);
    if (appInfoTableView != nil)
    {
        [appInfoTableView reloadData];
    }
    
    NSNumber *times = [[NSUserDefaults standardUserDefaults] objectForKey:kAdmobCanShowTimesKey];
    if (times.integerValue > 0 && (intersitial.isReady == NO || ( intersitial.isReady == YES && intersitial.hasBeenUsed == YES)))
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self admobSetting];
        });
    }
    if (_popViewController.view.window)
    {
//        [self showAdmobAdsWithController:_popViewController];
//        [self showCustomAdsWithViewController:_popViewController];
        
        [self showAdsWithController:_popViewController];
    }
    
    
}

- (void)applicationTerminate:(UIApplication *)application
{
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:NO] forKey:isFirstLaunch];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)requestWithMoreappId:(NSInteger)appid
{
    [self downLoadAppsWithMoreAppId:appid];
    [self requestAdMobTimesForMoreAppId:appid];
}

- (void)downLoadAppsWithMoreAppId:(NSInteger)appid
{
    NSDate *lastDate = [[NSUserDefaults standardUserDefaults] objectForKey:kRequestAppDateKey];
    NSDate *time = [NSDate date];
    NSTimeInterval timeInterval = [time timeIntervalSinceDate:lastDate];
    if (lastDate == nil || timeInterval > 24*60*60 || self.moreAPPSArray.count == 0)
    {
        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
        NSString *currentVersion = [infoDict objectForKey:@"CFBundleVersion"];
        NSString *language = [[NSLocale preferredLanguages] firstObject];
        if ([language isEqualToString:@"zh-Hans"])
        {
            language = @"zh";
        }
        else if ([language isEqualToString:@"zh-Hant"])
        {
            language = @"zh_TW";
        }
        
        NSDictionary *appDic = @{@"appId":[NSNumber numberWithInteger:appid],@"packageName":bundleIdentifier,@"language":language,@"version":currentVersion,@"platform":[NSNumber numberWithInt:0]};
        
        AFJSONRequestSerializer *requestSerializer = [AFJSONRequestSerializer serializer];
        [requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        [requestSerializer setTimeoutInterval:30];
        self.manager.requestSerializer = requestSerializer;
        self.manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript" , @"text/plain" ,@"text/html", nil];
        AFJSONResponseSerializer *responseSerializer = [AFJSONResponseSerializer serializerWithReadingOptions:NSJSONReadingMutableContainers];
        self.manager.responseSerializer = responseSerializer;
        //        NSString *url = @"http://192.168.0.86:8076/AdlayoutBossWeb/platform/getRcAdvConrol.do";
        NSString *url = @"http://moreapp.rcplatformhk.net/pbweb/app/getIOSAppListNew.do";
        
        [self.manager POST:url parameters:appDic success:^(AFHTTPRequestOperation *operation, id responseObject)
         {
             //解析数据
             NSDictionary *dic = (NSDictionary *)responseObject;
             NSLog(@"%@",dic);
             NSArray *infoArray = [dic objectForKey:@"list"];
             NSMutableArray *sqlArray = [[NSMutableArray alloc]init];
             for (NSMutableDictionary *infoDic in infoArray)
             {
                 RC_AppInfo *appInfo = [[RC_AppInfo alloc]initWithDictionary:infoDic];
                 [sqlArray addObject:appInfo];
             }
             
             //判断是否有新应用
             NSMutableArray *dataArray = [self getAllAppInfoData];
             
             for (RC_AppInfo *app in sqlArray)
             {
                 BOOL isHave = NO;
                 for (RC_AppInfo *appInfo in dataArray)
                 {
                     if (app.appId == appInfo.appId)
                     {
                         isHave = YES;
                     }
                 }
                 if (!isHave)
                 {
                     [[NSUserDefaults standardUserDefaults] setObject:@"1" forKey:NewMoreApp];
                     [[NSUserDefaults standardUserDefaults] synchronize];
                     [[NSNotificationCenter defaultCenter] postNotificationName:NewMoreApp object:nil];
                     break;
                 }
             }
             
             [[NSUserDefaults standardUserDefaults] setObject:time forKey:kRequestAppDateKey];
             
             [self deleteAllAppInfoData];
             [self insertAppInfo:sqlArray];
             self.moreAPPSArray = sqlArray;
             self.appInfoTableArray = RC_changeMoreTurnArray(self.moreAPPSArray);
             if (appInfoTableView != nil)
             {
                 [appInfoTableView reloadData];
             }
             
         } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
             NSLog(@"%@",error);
         }];
    }
}

- (BOOL)isHaveNewApp
{
    NSString *newMoreApp = [[NSUserDefaults standardUserDefaults] objectForKey:NewMoreApp];
    if ([newMoreApp isEqualToString:@"0"])
    {
        return NO;
    }
    else if ([newMoreApp isEqualToString:@"1"])
    {
        return YES;
    }
    return NO;
}

- (BOOL)isCanShowAdmob
{
    NSNumber *times = [[NSUserDefaults standardUserDefaults] objectForKey:kAdmobCanShowTimesKey];

    if (times.integerValue > 0 && (intersitial.isReady == YES && intersitial.hasBeenUsed == NO))
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

- (void)refreshCount
{
    _CustomMaxShowTimes = ((NSNumber *)([[NSUserDefaults standardUserDefaults] objectForKey:kCustomMaxShowTimesKey])).integerValue;
    _CustomCanshowTimes = ((NSNumber *)([[NSUserDefaults standardUserDefaults] objectForKey:kCustomMaxShowTimesKey])).integerValue;
    _AdmobMaxshowTimes = ((NSNumber *)([[NSUserDefaults standardUserDefaults] objectForKey:kAdmobMaxShowTimesKey])).integerValue;
    _AdmobCanShowTimes = ((NSNumber *)([[NSUserDefaults standardUserDefaults] objectForKey:kAdmobMaxShowTimesKey])).integerValue;
    
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInteger:_CustomCanshowTimes] forKey:kCustomCanShowTimesKey];
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInteger:_AdmobCanShowTimes] forKey:kAdmobCanShowTimesKey];
    
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)requestAdMobTimesForMoreAppId:(NSInteger)appId
{
    NSDate *lastDate = [[NSUserDefaults standardUserDefaults] objectForKey:kRequestDateKey];
    NSDate *time = [NSDate date];
    
    NSTimeInterval timeInterval = [time timeIntervalSinceDate:lastDate];
    
    NSLog(@"timeInterval = %f",timeInterval);
    if (lastDate == nil || timeInterval > 24*60*60)
    {
        NSLog(@"begin request admob setting.......");
        NSString *moreAppId = [NSString stringWithFormat:@"%ld",(long)appId];
        NSDictionary *dic = [[NSDictionary alloc]initWithObjectsAndKeys:moreAppId,@"app_id",nil];
        if (![self checkNetWorking])
        {
            if (lastDate != nil)
            {
                NSNumber *oldCanShow = [[NSUserDefaults standardUserDefaults] objectForKey:kCustomCanShowTimesKey];
                NSNumber *oldMaxShow = [[NSUserDefaults standardUserDefaults] objectForKey:kCustomMaxShowTimesKey];
                
                NSInteger newCanShow = _CustomMaxShowTimes-(oldMaxShow.integerValue-oldCanShow.integerValue);
                
                [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInteger:newCanShow] forKey:kCustomCanShowTimesKey];
            }
            
            return;
        }
        
        AFJSONRequestSerializer *requestSerializer = [AFJSONRequestSerializer serializer];
        [requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        [requestSerializer setTimeoutInterval:30];
        self.manager.requestSerializer = requestSerializer;
        self.manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript" , @"text/plain" ,@"text/html", nil];
        AFJSONResponseSerializer *responseSerializer = [AFJSONResponseSerializer serializerWithReadingOptions:NSJSONReadingMutableContainers];
        self.manager.responseSerializer = responseSerializer;
        //        NSString *url = @"http://192.168.0.86:8076/AdlayoutBossWeb/platform/getRcAdvConrol.do";
        NSString *url = @"http://ads.rcplatformhk.com/AdlayoutBossWeb/platform/getRcAdvConrol.do";
        
        //        NSString *url = @"http://115.28.90.23:8066/lottery/registermain";
        
        //        NSDictionary *postDic = @{@"username":@"18618415293",@"password":@"123456",@"shopId":@"871"};
        [self.manager POST:url parameters:dic success:^(AFHTTPRequestOperation *operation, id responseObject)
         {
             //解析数据
             NSDictionary *dic = (NSDictionary *)responseObject;
             NSLog(@"%@",dic);
             if (![[dic objectForKey:@"advertising"] isKindOfClass:[NSNull class]])
             {
                 NSString *str = [NSString stringWithFormat:@"%@",[dic objectForKey:@"advertising"]];
                 _CustomMaxShowTimes = [[[str componentsSeparatedByString:@","] objectAtIndex:0] integerValue];
                 _AdmobMaxshowTimes = [[[str componentsSeparatedByString:@","]objectAtIndex:1] integerValue];
             }
             if (lastDate != nil)
             {
                 NSNumber *oldCustomCanShow = [[NSUserDefaults standardUserDefaults] objectForKey:kCustomCanShowTimesKey];
                 NSNumber *oldCustomMaxShow = [[NSUserDefaults standardUserDefaults] objectForKey:kCustomMaxShowTimesKey];
                 
                 NSNumber *oldAdmobCanShow = [[NSUserDefaults standardUserDefaults] objectForKey:kAdmobCanShowTimesKey];
                 NSNumber *oldAdmobMaxShow = [[NSUserDefaults standardUserDefaults] objectForKey:kAdmobMaxShowTimesKey];
                 
                 NSInteger newCustomCanShow = _CustomMaxShowTimes-(oldCustomMaxShow.integerValue-oldCustomCanShow.integerValue);
                 NSInteger newAdmobCanShow = _AdmobMaxshowTimes-(oldAdmobMaxShow.integerValue-oldAdmobCanShow.integerValue);
                 
                 [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInteger:newCustomCanShow] forKey:kCustomCanShowTimesKey];
                 [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInteger:newAdmobCanShow] forKey:kAdmobCanShowTimesKey];
             }
             
             
             [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInteger:_CustomMaxShowTimes] forKey:kCustomMaxShowTimesKey];
             [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInteger:_AdmobMaxshowTimes] forKey:kAdmobMaxShowTimesKey];
             [[NSUserDefaults standardUserDefaults] setObject:time forKey:kRequestDateKey];
             [[NSUserDefaults standardUserDefaults] setObject:time forKey:krefreshTimeKey];
             if (lastDate == nil)
             {
                 _CustomCanshowTimes = _CustomMaxShowTimes;
                 _AdmobCanShowTimes = _AdmobMaxshowTimes;
                 
                 [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInteger:_CustomCanshowTimes] forKey:kCustomCanShowTimesKey];
                 [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInteger:_AdmobCanShowTimes] forKey:kAdmobCanShowTimesKey];
             }
             [[NSUserDefaults standardUserDefaults] synchronize];
             NSNumber *times = [[NSUserDefaults standardUserDefaults] objectForKey:kAdmobCanShowTimesKey];
             if (times.integerValue > 0 && (intersitial.isReady == NO || ( intersitial.isReady == YES && intersitial.hasBeenUsed == YES)))
             {
                 [self admobSetting];
             }
             
         } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
             
             if (lastDate != nil)
             {
                 NSNumber *oldCustomCanShow = [[NSUserDefaults standardUserDefaults] objectForKey:kCustomCanShowTimesKey];
                 NSNumber *oldCustomMaxShow = [[NSUserDefaults standardUserDefaults] objectForKey:kCustomMaxShowTimesKey];
                 NSNumber *newCustomMaxShow = [[NSUserDefaults standardUserDefaults] objectForKey:kCustomMaxShowTimesKey];
                 
                 NSNumber *oldAdmobCanShow = [[NSUserDefaults standardUserDefaults] objectForKey:kAdmobCanShowTimesKey];
                 NSNumber *oldAdmobMaxShow = [[NSUserDefaults standardUserDefaults] objectForKey:kAdmobMaxShowTimesKey];
                 NSNumber *newAdmobMaxShow = [[NSUserDefaults standardUserDefaults] objectForKey:kAdmobMaxShowTimesKey];
                 
                 NSInteger newCustomCanShow = newCustomMaxShow.integerValue-(oldCustomMaxShow.integerValue-oldCustomCanShow.integerValue);
                 NSInteger newAdmobCanShow = newAdmobMaxShow.integerValue-(oldAdmobMaxShow.integerValue-oldAdmobCanShow.integerValue);
                 
                 [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInteger:newCustomCanShow] forKey:kCustomCanShowTimesKey];
                 [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInteger:newAdmobCanShow] forKey:kAdmobCanShowTimesKey];
             }
             
             NSLog(@"error.......%@",error);
             [[NSUserDefaults standardUserDefaults] synchronize];
         }];
    }
    
}

- (void)setPopViewController:(UIViewController *)popViewController
{
    _popViewController = popViewController;
    if (_popViewController.view.window)
    {
        [self presentViewCompletion:^{
            [self showCustomSeccess];
        }];
    }
}

- (void)showAdsWithController:(UIViewController *)popViewController
{
    _popViewController = popViewController;
    if ([self isCanShowAdmob] && isbecomeActivity)
    {
        [self showAdmobSeccess];
        isPopingAdmob = YES;
        
        if (isPopUping)
        {
            customADView.frame = CGRectMake(kcutomAdRect.origin.x, kcutomAdRect.size.height, kcutomAdRect.size.width, kcutomAdRect.size.height);
            [customADView removeFromSuperview];
            isPopUping = NO;
        }
        
        [self.intersitial presentFromRootViewController:popViewController];
    }
    else
    {
        [self showCustomAdsWithViewController:popViewController];
    }
}

- (void)showCustomAdsWithViewController:(UIViewController *)popController
{
    NSDate *lastDate = [[NSUserDefaults standardUserDefaults] objectForKey:krefreshTimeKey];
    NSDate *time = [NSDate date];
    
    NSTimeInterval timeInterval = [time timeIntervalSinceDate:lastDate];
    
    NSLog(@"timeInterval = %f",timeInterval);
    if (lastDate != nil && timeInterval > 24*60*60)
    {
        [picObject refreshCount];
        [[NSUserDefaults standardUserDefaults] setObject:time forKey:krefreshTimeKey];
    }
    if (!isbecomeActivity)
    {
        NSLog(@"本次启动已弹出一次");
        return;
    }
    BOOL isFirst = [[[NSUserDefaults standardUserDefaults] objectForKey:isFirstLaunch] boolValue];
    if (isFirst)
    {
        NSLog(@"首次安装");
        return;
    }
    if (isPopUping)
    {
        NSLog(@"已有弹出");
        return;
    }
    NSNumber *times = [[NSUserDefaults standardUserDefaults] objectForKey:kCustomCanShowTimesKey];
    NSLog(@"%d",times.intValue);
    if (times.intValue > 0)
    {
        BOOL canPopUp = NO;
        NSInteger lastPopCount = -1;
        popAppInfoID = [[NSUserDefaults standardUserDefaults] objectForKey:kCustomAdAppCount];
        
        for (int i = 0; i < self.moreAPPSArray.count; i++)
        {
            RC_AppInfo *tempApp = (RC_AppInfo *)[self.moreAPPSArray objectAtIndex:i];
            if ([tempApp.downUrl isEqualToString:popAppInfoID])
            {
                lastPopCount = i;
                break;
            }
            else
            {
                lastPopCount = -1;
            }
        }
        for (int j = 0; j < self.moreAPPSArray.count; j++)
        {
            lastPopCount = lastPopCount+1;
            NSInteger popCount = lastPopCount%self.moreAPPSArray.count;
            RC_AppInfo *appInfo = [self.moreAPPSArray objectAtIndex:popCount];
            
            NSString *string = appInfo.openUrl;
            NSURL *url = nil;
            if (![string isKindOfClass:[NSNull class]] && string != nil ) {
                url = [NSURL URLWithString:string];
            }else{
                url = nil;
            }
            if (appInfo.state == 1001 && ![[UIApplication sharedApplication] canOpenURL:url])
            {
                canPopUp = YES;
                temAppInfo = appInfo;
                popAppInfoID = appInfo.downUrl;
                break;
            }
        }
        if (canPopUp == NO)
        {
            NSLog(@"POPUP无可弹出");
            return;
        }
        if (canPopUp == YES)
        {
            SDWebImageManager *manager = [SDWebImageManager sharedManager];
            BOOL isIconCache = [manager cachedImageExistsForURL:[NSURL URLWithString:temAppInfo.iconUrl]];
            BOOL isBannerCache = [manager cachedImageExistsForURL:[NSURL URLWithString:temAppInfo.bannerUrl]];
            if (!(isIconCache && isBannerCache))
            {
                return;
            }
            
            customADView = [[UIView alloc]init];
            customADView.frame = CGRectMake(kcutomAdRect.origin.x, kcutomAdRect.size.height, kcutomAdRect.size.width, kcutomAdRect.size.height);
            customADView.backgroundColor = [UIColor clearColor];
            
            UIView *backView = [[UIView alloc]initWithFrame:kcutomAdRect];
            backView.backgroundColor = [UIColor blackColor];
            backView.alpha = 0.7;
            [customADView addSubview:backView];
            
            
            popCell.center = backView.center;
            popCell.appInfo = temAppInfo;
            popCell.viewName = @"popup";
            [customADView addSubview:popCell];
            
            //            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(cellSelected:)];
            //            tap.numberOfTapsRequired = 1;
            //            tap.numberOfTouchesRequired = 1;
            //            [popCell addGestureRecognizer:tap];
            
            UIButton *backButton = [UIButton buttonWithType:UIButtonTypeCustom];
            [backButton setBackgroundImage:[UIImage imageWithContentsOfFile:[RC_GetPath getMyBundlePath:@"popUp_cancel@2x.png"]] forState:UIControlStateNormal];
            backButton.frame = CGRectMake(popCell.frame.origin.x+popCell.frame.size.width-20, popCell.frame.origin.y-10, 30, 30);
            [backButton addTarget:self action:@selector(backButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
            [customADView addSubview:backButton];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self presentViewCompletion:^{
                    [self showCustomSeccess];
                }];
            });
            
        }
    }
}
- (void)showAdmobAdsWithController:(UIViewController *)presentController
{
    NSNumber *times = [[NSUserDefaults standardUserDefaults] objectForKey:kAdmobCanShowTimesKey];
    if (times.intValue > 0)
    {
        if(intersitial.isReady && !intersitial.hasBeenUsed)
        {
            [self showAdmobSeccess];
            isPopingAdmob = YES;
            [intersitial presentFromRootViewController:presentController];
        }
    }
}

- (void)showCustomSeccess
{
    NSNumber *times = [[NSUserDefaults standardUserDefaults] objectForKey:kCustomCanShowTimesKey];
    [[NSUserDefaults standardUserDefaults] setObject:popAppInfoID forKey:kCustomAdAppCount];
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInteger:times.integerValue - 1] forKey:kCustomCanShowTimesKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    NSLog(@"canShowCusTimes = %ld",(long)((NSNumber *)[[NSUserDefaults standardUserDefaults] objectForKey:kCustomCanShowTimesKey]).integerValue);
    
    isbecomeActivity = NO;
    isPopUping = YES;
}

- (void)showAdmobSeccess
{
    isbecomeActivity = NO;
    NSNumber *times = [[NSUserDefaults standardUserDefaults] objectForKey:kAdmobCanShowTimesKey];
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInteger:times.integerValue - 1] forKey:kAdmobCanShowTimesKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    NSLog(@"canShowAdmobTimes = %ld",(long)((NSNumber *)[[NSUserDefaults standardUserDefaults] objectForKey:kAdmobCanShowTimesKey]).integerValue);
}

- (void)backButtonPressed:(id)sender
{
    isPopUping = NO;
    customADView.frame = CGRectMake(kcutomAdRect.origin.x, kcutomAdRect.size.height, kcutomAdRect.size.width, kcutomAdRect.size.height);
    [customADView removeFromSuperview];
}

- (void)presentViewCompletion:(void (^)(void))completion
{
    NSLog(@"已弹出POPUP");
    [_popViewController.view.window addSubview:customADView];
    [UIView animateWithDuration:0.5 animations:^{
        customADView.frame = kcutomAdRect;
    } completion:^(BOOL finished){
        if (finished)
        {
            completion();
        }
    }];
}
- (void)cellSelected:(id)sender
{
    if ([sender isKindOfClass:[NSNotification class]])
    {
        NSNotification *tempNotification = (NSNotification *)sender;
        RC_PopUpADView *tempPop = (RC_PopUpADView *)[tempNotification object];
        if ([tempPop.viewName isEqualToString:@"popup"])
        {
            [self event:@"C_POPUP" label:[NSString stringWithFormat:@"c_popup_%@",tempPop.appInfo.appName]];
            NSString *downURL = [NSString stringWithFormat:@"itms-apps://itunes.apple.com/app/id%@",tempPop.appInfo.downUrl];
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:downURL]];
        }
        else if ([tempPop.viewName isEqualToString:@"share"])
        {
            [self event:@"C_SHARE" label:[NSString stringWithFormat:@"c_share_%@",tempPop.appInfo.appName]];
            NSString *downURL = [NSString stringWithFormat:@"itms-apps://itunes.apple.com/app/id%@",tempPop.appInfo.downUrl];
            if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:tempPop.appInfo.openUrl]])
            {
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:tempPop.appInfo.openUrl]];
            }
            else
            {
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:downURL]];
            }
        }
    }
}
#pragma mark moreAppsViewController

- (void)setMoreAppCellAttribut:(NSDictionary *)attribute
{
    attributeDic = attribute;
    [appInfoTableView reloadData];
}

- (UIViewController *)getMoreAppController
{
    [[NSUserDefaults standardUserDefaults] setObject:@"0" forKey:NewMoreApp];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    appInfoTableView = [[UITableView alloc]initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height - 44) style:UITableViewStylePlain];
    [appInfoTableView registerNib:[UINib nibWithNibName:@"RC_MoreTableViewCell" bundle:[RC_GetPath getBundle]] forCellReuseIdentifier:@"cell"];
    appInfoTableView.backgroundColor = [UIColor clearColor];
    appInfoTableView.backgroundView = nil;
    appInfoTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    appInfoTableView.delegate = self;
    appInfoTableView.dataSource = self;
    
    returnAPPVC.view = appInfoTableView;
    
    return returnAPPVC;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return tableView.frame.size.width*95.f/320.f;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.appInfoTableArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    RC_MoreTableViewCell *cell = (RC_MoreTableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    RC_AppInfo *appInfo = [self.appInfoTableArray objectAtIndex:indexPath.row];
    
    NSArray *tempAttributeArray = [attributeDic allKeys];
    NSMutableSet *keysSet = [NSMutableSet setWithObjects:KEYTOCELLTITLEFONT,KEYTOCELLTITLETEXTCOLOR,KEYTOCELLDETAILTITLEFONT,KEYTOCELLDETAILTITLTEXTCOLOR,KEYTOCELLCOMMENTTITLEFONT,KEYTOCELLCOMMENTTITLETEXTCOLOR, nil];
    NSMutableSet *attributeSet = [NSMutableSet setWithArray:tempAttributeArray];
    [keysSet intersectSet:attributeSet];
    
    if ([keysSet containsObject:KEYTOCELLTITLEFONT])
    {
        cell.titleLabel.font = [attributeDic objectForKeyedSubscript:KEYTOCELLTITLEFONT];
    }
    if ([keysSet containsObject:KEYTOCELLTITLETEXTCOLOR])
    {
        cell.titleLabel.textColor = [attributeDic objectForKey:KEYTOCELLTITLETEXTCOLOR];
    }
    if ([keysSet containsObject:KEYTOCELLDETAILTITLEFONT])
    {
        cell.typeLabel.font = [attributeDic objectForKeyedSubscript:KEYTOCELLDETAILTITLEFONT];
    }
    if ([keysSet containsObject:KEYTOCELLDETAILTITLTEXTCOLOR])
    {
        cell.typeLabel.textColor = [attributeDic objectForKey:KEYTOCELLDETAILTITLTEXTCOLOR];
    }
    if ([keysSet containsObject:KEYTOCELLCOMMENTTITLEFONT])
    {
        cell.commentLabel.font = [attributeDic objectForKeyedSubscript:KEYTOCELLCOMMENTTITLEFONT];
    }
    if ([keysSet containsObject:KEYTOCELLCOMMENTTITLETEXTCOLOR])
    {
        cell.commentLabel.textColor = [attributeDic objectForKey:KEYTOCELLCOMMENTTITLETEXTCOLOR];
    }
    CGSize appNameSize = RC_getTextLabelRectWithContentAndFont(appInfo.appName, cell.titleLabel.font).size;
    if (appNameSize.height < 20.f)
    {
        [cell.titleLabel setFrame:CGRectMake(cell.titleLabel.frame.origin.x, cell.typeLabel.frame.origin.y - appNameSize.height - 6, appNameSize.width, appNameSize.height)];
    }
    else
    {
        [cell.titleLabel setFrame:CGRectMake(cell.titleLabel.frame.origin.x, cell.titleLabel.frame.origin.y - 6, appNameSize.width, appNameSize.height)];
    }
    cell.titleLabel.text = appInfo.appName;
    cell.typeLabel.text = appInfo.appCate;
    cell.commentLabel.text = [NSString stringWithFormat:@"(%d)",appInfo.appComment];
    
    [cell.logoImageView sd_setImageWithURL:[NSURL URLWithString:appInfo.iconUrl] placeholderImage:nil options:SDWebImageRetryFailed | SDWebImageLowPriority];
    
    NSString *title = @"";
    NSString *language = [[NSLocale preferredLanguages] firstObject];
    
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:appInfo.openUrl]])
    {
        title = NSLocalizedStringFromTableInBundle(@"open", @"CusLocalizable", [RC_GetPath getBundle], @"");
        if ([language isEqualToString:@"en"])
        {
            title = @"open";
        }

//        title = NSLocalizedString(@"open", nil);
    }
    else
    {
        if ([appInfo.price isEqualToString:@"0"])
        {
            title = NSLocalizedStringFromTableInBundle(@"free", @"CusLocalizable", [RC_GetPath getBundle], @"");
            if ([language isEqualToString:@"en"])
            {
                title = @"free";
            }

//            title = NSLocalizedString(@"free", nil);
        }
        else
        {
            title = appInfo.price;
        }
    }
    
    CGSize size = RC_getTextLabelRectWithContentAndFont(title, [UIFont fontWithName:@"HelveticaNeue-Light" size:18]).size;
    cell.installLabel.text = title;
//    [cell.installLabel setFrame:CGRectMake(cell.frame.size.width - size.width-10 - 20, cell.installLabel.frame.origin.y, size.width+10, 26)];
//    cell.installLabel.frame = CGRectMake(cell.frame.size.width - size.width-10 - 20, cell.installLabel.frame.origin.y, size.width+10, 26);
    
    cell.installLabel.translatesAutoresizingMaskIntoConstraints = NO;
//    cell.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [cell.installLabel removeConstraints:cell.installLabel.constraints];
    
//    if (cell.layoutconstraint) {
//        [cell.installLabel removeConstraint:cell.layoutconstraint];
//        cell.layoutconstraint = nil;
//    }
    NSLayoutConstraint *width = [NSLayoutConstraint constraintWithItem:cell.installLabel attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:size.width+10];
    NSLayoutConstraint *height = [NSLayoutConstraint constraintWithItem:cell.installLabel attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:cell.installLabel.frame.size.height];
    
    [cell.installLabel addConstraints:@[width,height]];
//    [cell layoutIfNeeded];
//    [cell.installLabel layoutIfNeeded];
    cell.appInfo = appInfo;
    cell.layoutconstraint = width;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    RC_AppInfo *appInfo = [self.appInfoTableArray objectAtIndex:indexPath.row];
    [self event:@"C_MORE" label:[NSString stringWithFormat:@"c_more_%@",appInfo.appName]];
    
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:appInfo.openUrl]])
    {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:appInfo.openUrl]];
    }
    else
    {
        NSString *downURL = [NSString stringWithFormat:@"itms-apps://itunes.apple.com/app/id%@",appInfo.downUrl];
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:downURL]];
    }
}


#pragma mark shareView
- (UIView *)getShareView
{
    if (self.moreAPPSArray.count == 0)
    {
        return nil;
    }
    BOOL canPopUp = NO;
    NSInteger lastPopCount = -1;
    shareAppInfoID = [[NSUserDefaults standardUserDefaults] objectForKey:kShareAdShowCount];
    
    NSLog(@"shareAppInfoID===%@",shareAppInfoID);
    
    RC_AppInfo *shareAppInfo = nil;
    
    for (int i = 0; i < self.moreAPPSArray.count; i++)
    {
        RC_AppInfo *tempApp = (RC_AppInfo *)[self.moreAPPSArray objectAtIndex:i];
        if ([tempApp.downUrl isEqualToString:shareAppInfoID])
        {
            lastPopCount = i;
            break;
        }
        else
        {
            lastPopCount = -1;
        }
    }
    for (int j = 0; j < self.moreAPPSArray.count; j++)
    {
        lastPopCount = lastPopCount+1;
        NSInteger popCount = lastPopCount%self.moreAPPSArray.count;
        RC_AppInfo *appInfo = [self.moreAPPSArray objectAtIndex:popCount];
        
        NSString *string = appInfo.openUrl;
        NSURL *url = nil;
        if (![string isKindOfClass:[NSNull class]] && string != nil ) {
            url = [NSURL URLWithString:string];
        }else{
            url = nil;
        }
        if (![[UIApplication sharedApplication] canOpenURL:url])
        {
            canPopUp = YES;
            shareAppInfo = appInfo;
            shareAppInfoID = appInfo.downUrl;
            break;
        }
    }
    if (canPopUp == NO)
    {
        shareAppInfo = [self.moreAPPSArray objectAtIndex:0];
        shareAppInfoID = shareAppInfo.downUrl;
    }
    
    sharePopCell.viewName = @"share";
    sharePopCell.center = CGPointMake([UIScreen mainScreen].bounds.size.width/2, popCell.center.y);
    sharePopCell.appInfo = shareAppInfo;
    
    NSLog(@"shareAppInfoID===%@",shareAppInfoID);
    [[NSUserDefaults standardUserDefaults] setObject:shareAppInfoID forKey:kShareAdShowCount];
    
    return sharePopCell;
}

- (void)PrefetcherURLs:(NSArray *)array
{
    NSMutableArray *tempArray = [[NSMutableArray alloc]initWithArray:array];
    for (RC_AppInfo *info in array)
    {
        if (info.openUrl)
        {
            if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:info.openUrl]])
            {
                [tempArray removeObject:info];
                [tempArray insertObject:info atIndex:tempArray.count];
            }
        }
    }
    NSMutableArray *imageCacheArray = [[NSMutableArray alloc]init];
    for (RC_AppInfo *tempAPP in tempArray)
    {
        NSLog(@"%@",tempAPP.appName);
        
        NSURL *iconUrl = [NSURL URLWithString:tempAPP.iconUrl];
        NSURL *bannerUrl = [NSURL URLWithString:tempAPP.bannerUrl];
        [imageCacheArray addObject:iconUrl];
        [imageCacheArray addObject:bannerUrl];
    }
    
    [[SDWebImagePrefetcher sharedImagePrefetcher] cancelPrefetching];
    [[SDWebImagePrefetcher sharedImagePrefetcher]prefetchURLs:imageCacheArray];
}

- (void)setTitleColor:(UIColor *)color
{
    [popCell setTitleColor:color];
}
- (void)setBackGroundColor:(UIColor *)color
{
    [popCell setBackViewColor:color];
}

- (void)setShareTitleColor:(UIColor *)color
{
    [sharePopCell setTitleColor:color];
}
- (void)setShareBackGroundColor:(UIColor *)color
{
    [sharePopCell setBackViewColor:color];
}

#pragma mark - 数据库操作
//数据库沙盒路径
- (NSString *)dataFilePath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    return [documentsDirectory stringByAppendingPathComponent:kAppsInfoFileName];
}

//创建，打开数据库
- (BOOL)openDB {
    
    //获取数据库路径
    NSString *path = [self dataFilePath];
    //文件管理器
    NSFileManager *fileManager = [NSFileManager defaultManager];
    //判断数据库是否存在
    BOOL find = [fileManager fileExistsAtPath:path];
    
    //如果数据库存在，则用sqlite3_open直接打开（不要担心，如果数据库不存在sqlite3_open会自动创建）
    if (find) {
        
        //打开数据库，这里的[path UTF8String]是将NSString转换为C字符串，因为SQLite3是采用可移植的C(而不是
        //Objective-C)编写的，它不知道什么是NSString.
        if(sqlite3_open([path UTF8String], &_database) != SQLITE_OK) {
            
            //如果打开数据库失败则关闭数据库
            sqlite3_close(_database);
            NSLog(@"Error: open database file.");
            return NO;
        }
        
        //创建一个新表
        [self createTable:_database];
        
        return YES;
    }
    //如果发现数据库不存在则利用sqlite3_open创建数据库（上面已经提到过），与上面相同，路径要转换为C字符串
    if(sqlite3_open([path UTF8String], &_database) == SQLITE_OK) {
        
        //创建一个新表
        [self createTable:_database];
        return YES;
    }else {
        //如果创建并打开数据库失败则关闭数据库
        sqlite3_close(_database);
        NSLog(@"Error: open database file.");
        return NO;
    }
    return NO;
}

//创建数据库
- (BOOL)createTable:(sqlite3 *)db
{
    //这句是大家熟悉的SQL语句
    char *sql;
    
    sql = "create table if not exists appsInfoTable(ID INTEGER PRIMARY KEY AUTOINCREMENT, appCate text,appComment int,appId int,appName text,bannerUrl text,downUrl text,iconUrl text,packageName text,price text,openUrl text,isHave int,appDesc text, state int)";
    
    sqlite3_stmt *statement;
    //sqlite3_prepare_v2 接口把一条SQL语句解析到statement结构里去. 使用该接口访问数据库是当前比较好的的一种方法
    NSInteger sqlReturn = sqlite3_prepare_v2(_database, sql, -1, &statement, nil);
    //第一个参数跟前面一样，是个sqlite3 * 类型变量，
    //第二个参数是一个 sql 语句。
    //第三个参数我写的是-1，这个参数含义是前面 sql 语句的长度。如果小于0，sqlite会自动计算它的长度（把sql语句当成以\0结尾的字符串）。
    //第四个参数是sqlite3_stmt 的指针的指针。解析以后的sql语句就放在这个结构里。
    //第五个参数我也不知道是干什么的。为nil就可以了。
    //如果这个函数执行成功（返回值是 SQLITE_OK 且 statement 不为 NULL ），那么下面就可以开始插入二进制数据。
    
    //如果SQL语句解析出错的话程序返回
    if(sqlReturn != SQLITE_OK) {
        NSLog(@"Error: failed to prepare statement:create test table");
        return NO;
    }
    
    //执行SQL语句
    int success = sqlite3_step(statement);
    //释放sqlite3_stmt
    sqlite3_finalize(statement);
    
    //执行SQL语句失败
    if ( success != SQLITE_DONE) {
        NSLog(@"Error: failed to dehydrate:create table test");
        return NO;
    }
    
    return YES;
}
- (BOOL)insertAppInfo:(NSMutableArray *)appsInfo
{
    //先判断数据库是否打开
    if ([self openDB]) {
        
        char *zErrorMsg;
        int ret;
        ret = sqlite3_exec(_database, "begin transaction" , 0 , 0 , &zErrorMsg);
        
        for (RC_AppInfo *appInfo in appsInfo) {
            //能够使用sqlite3_step()执行编译好的准备语句的指针
            
            sqlite3_stmt *statement;
            
            //这个 sql 语句特别之处在于 values 里面有个? 号。在sqlite3_prepare函数里，?号表示一个未定的值，它的值等下才插入。
            char *sql = "INSERT INTO appsInfoTable(appCate, appComment ,appId ,appName , bannerUrl, downUrl, iconUrl, packageName, price, openUrl, isHave ,appDesc,state) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)";
            
            //准备语句：第三个参数是从zSql中读取的字节数的最大值
            int success2 = sqlite3_prepare_v2(_database, sql, -1, &statement, NULL);
            if (success2 != SQLITE_OK)
            {
                sqlite3_close(_database);
                return NO;
            }
            
            //这里的数字1，2，3代表第几个问号，这里将两个值绑定到两个绑定变量
            sqlite3_bind_text(statement, 1, [appInfo.appCate UTF8String], -1, SQLITE_TRANSIENT);
            sqlite3_bind_int (statement, 2, appInfo.appComment);
            sqlite3_bind_int (statement, 3, appInfo.appId);
            sqlite3_bind_text(statement, 4, [appInfo.appName UTF8String], -1, SQLITE_TRANSIENT);
            sqlite3_bind_text(statement, 5, [appInfo.bannerUrl UTF8String], -1, SQLITE_TRANSIENT);
            sqlite3_bind_text(statement, 6, [appInfo.downUrl UTF8String], -1, SQLITE_TRANSIENT);
            sqlite3_bind_text(statement, 7, [appInfo.iconUrl UTF8String], -1, SQLITE_TRANSIENT);
            sqlite3_bind_text(statement, 8, [appInfo.packageName UTF8String], -1, SQLITE_TRANSIENT);
            sqlite3_bind_text(statement, 9, [appInfo.price UTF8String], -1, SQLITE_TRANSIENT);
            sqlite3_bind_text(statement, 10, [appInfo.openUrl UTF8String], -1, SQLITE_TRANSIENT);
            sqlite3_bind_int (statement, 11, appInfo.isHave);
            sqlite3_bind_text(statement, 12, [appInfo.appDesc UTF8String], -1, SQLITE_TRANSIENT);
            sqlite3_bind_int(statement, 13, appInfo.state);
            //执行插入语句
            success2 = sqlite3_step(statement);
            //释放statement
            sqlite3_finalize(statement);
            
            //如果插入失败
            if (success2 == SQLITE_ERROR) {
                NSLog(@"Error: failed to insert into the database with message.");
                ret = sqlite3_exec(_database , "rollback transaction" , 0 , 0 , & zErrorMsg);
                //关闭数据库
                sqlite3_close(_database);
                return NO;
            }
        }
        
        ret = sqlite3_exec(_database , "commit transaction" , 0 , 0 , & zErrorMsg);
        sqlite3_close(_database);
        
        return YES;
    }
    return NO;
}
- (NSMutableArray *)getAllAppInfoData
{
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:0];
    if ([self openDB]) {
        sqlite3_stmt *statement = nil;
        
        char *sql = "SELECT appCate ,appComment ,appId ,appName ,bannerUrl ,downUrl ,iconUrl, packageName, price, openUrl, isHave ,appDesc,state FROM appsInfoTable";
        
        if (sqlite3_prepare_v2(_database, sql, -1, &statement, NULL) != SQLITE_OK)
        {
            return NO;
        }else {
            //查询结果集中一条一条的遍历所有的记录，这里的数字对应的是列值。
            
            while (sqlite3_step(statement) == SQLITE_ROW) {
                RC_AppInfo* appInfo = [[RC_AppInfo alloc] init] ;
                
                char* appCate  = (char*)sqlite3_column_text(statement, 0);
                appInfo.appCate = [NSString stringWithUTF8String:appCate];
                
                appInfo.appComment  = sqlite3_column_int(statement,1);
                
                appInfo.appId  = sqlite3_column_int(statement,2);
                
                char* appName  = (char*)sqlite3_column_text(statement, 3);
                appInfo.appName = [NSString stringWithUTF8String:appName];
                
                char* bannerUrl  = (char*)sqlite3_column_text(statement, 4);
                appInfo.bannerUrl = [NSString stringWithUTF8String:bannerUrl];
                
                char* downUrl  = (char*)sqlite3_column_text(statement, 5);
                appInfo.downUrl = [NSString stringWithUTF8String:downUrl];
                
                char* iconUrl  = (char*)sqlite3_column_text(statement, 6);
                appInfo.iconUrl = [NSString stringWithUTF8String:iconUrl];
                
                char* packageName  = (char*)sqlite3_column_text(statement, 7);
                appInfo.packageName = [NSString stringWithUTF8String:packageName];
                
                char* price  = (char*)sqlite3_column_text(statement, 8);
                appInfo.price = [NSString stringWithUTF8String:price];
                
                char* openUrl  = (char*)sqlite3_column_text(statement, 9);
                appInfo.openUrl = [NSString stringWithUTF8String:openUrl];
                
                appInfo.isHave  = sqlite3_column_int(statement,10);
                
                char* appDesc  = (char*)sqlite3_column_text(statement, 11);
                appInfo.appDesc = [NSString stringWithUTF8String:appDesc];
                
                appInfo.state = sqlite3_column_int(statement, 12);
                
                [array addObject:appInfo];
            }
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(_database);
    }
    
    return array;
}
- (BOOL)deleteAllAppInfoData
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    NSString *pathSql = [documentsDirectory stringByAppendingPathComponent:kAppsInfoFileName];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:pathSql])
    {
        [[NSFileManager defaultManager] removeItemAtPath:pathSql error:nil];;
    }
    return YES;
}


CGRect RC_getTextLabelRectWithContentAndFont(NSString *content ,UIFont *font)
{
    CGSize size = CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX);
    
    NSDictionary * tdic = [NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName,nil];
    
    CGRect returnRect = [content boundingRectWithSize:size options:NSStringDrawingUsesLineFragmentOrigin |NSStringDrawingUsesFontLeading attributes:tdic context:nil];
    
    return returnRect;
}

NSMutableArray *RC_changeMoreTurnArray(NSArray *array)
{
    NSMutableArray *tempArray = [[NSMutableArray alloc]initWithArray:array];
    for (RC_AppInfo *info in array)
    {
        NSLog(@"%@",info.openUrl);
        if (info.openUrl)
        {
            if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:info.openUrl]])
            {
                [tempArray removeObject:info];
                [tempArray insertObject:info atIndex:tempArray.count];
            }
        }
    }
    return [NSMutableArray arrayWithArray:tempArray];
}

#pragma mark -
#pragma mark 检测网络状态
- (BOOL)checkNetWorking
{
    BOOL connected = [[Reachability reachabilityForInternetConnection] currentReachabilityStatus] != NotReachable ? YES : NO;
    
    if (!connected) {
        
    }
    
    return connected;
}

#pragma mark 事件统计
- (void)event:(NSString *)eventID label:(NSString *)label;
{
    //友盟
    [MobClick event:eventID label:label];
}

@end
