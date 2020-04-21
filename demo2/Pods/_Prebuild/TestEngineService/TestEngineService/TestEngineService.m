//
//  TestEngineService.m
//  KouyuDemo
//
//  Created by yans on 2018/5/14.
//  Copyright © 2018年 Attu. All rights reserved.
//

#import "TestEngineService.h"
#import <AVFoundation/AVFAudio.h>
#import <objc/runtime.h>
#import <sys/stat.h>
#import "TSJSON.h"

#define BEGIN_TIME [[NSDate date] timeIntervalSince1970] * 1000

#define ST_CLASS "STTestEngineService"
#define CV_CLASS "CVTestEngineService"

@implementation TestEngineService
{
    NSString *appVersion;
}

- (void)dealloc
{
    
}

- (id)init
{
    if (self = [super init]) {
        appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
        
        self.safeWait = 1000;
        self.openWatchDog = YES;
        
        self.ageGroupSupportOption = TestEngineAgeGroupSupportOption_Middle;
    }
    return self;
}

- (id)initWithEngineType:(TestEngineType)engineType coreType:(TestCoreType)coreType userId:(NSString *)userId block:(TestInitBlock)block
{
    if (self = [self init]) {
        self.engineType = engineType;
        self.coreType = coreType;
        _userId = userId;
        
        [self initEngine:block];
    }
    
    return self;
}

+ (id)initWithEngineType:(TestEngineType)engineType coreType:(TestCoreType)coreType block:(TestInitBlock)block
{
    return [self initWithEngineType:engineType coreType:coreType userId:nil block:block];
}

+ (id)initWithEngineType:(TestEngineType)engineType coreType:(TestCoreType)coreType userId:(NSString *)userId block:(TestInitBlock)block
{
    Class cls = nil;
    
    if (engineType == TestEngineTypeST) {
        cls = objc_getClass(ST_CLASS);
    } else if (engineType == TestEngineTypeCV) {
        cls = objc_getClass(CV_CLASS);
    } else {
        cls = objc_getClass(CV_CLASS);
    }
    
    if (coreType == TestCoreType_CN_Word || coreType == TestCoreType_CN_Sentence) {
        cls = objc_getClass(CV_CLASS);
    }
    
    if (cls) {
        return [[cls alloc] initWithEngineType:engineType coreType:coreType userId:userId block:block];
    }
    
    return nil;
}

+ (TestEngineType)getEngineVoiceSDKType:(NSNumber *)type
{
    if ( type )
    {
        if ( type.intValue == 1 )
        {
            return TestEngineTypeCV;
        }
        else if ( type.intValue == 2 )
        {
            return TestEngineTypeST;
        }
    }
    return TestEngineTypeST;
}

#pragma mark -

- (void)initEngine:(TestInitBlock)initBlock
{
    TestEngineLog(@"TestEngine... initEngine %lu %lu", (unsigned long)self.engineType, (unsigned long)self.coreType);
    
    [self beginTimeTrack];
}

- (void)startEngineWithContent:(NSString *)content
{
    TestEngineLog(@"TestEngine... startEngineWithContent: '%@' %lu %lu", content, (unsigned long)self.engineType, (unsigned long)self.coreType);

    //防止录音机被其他程序占用
//    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryMultiRoute error:nil];
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    
    //创建录音文件夹
    [self createSaveRecPath:[self getRecordSavePath]];
    
    _recording = YES;
    _content = content;
    
    [self stopWatchDog];//关狗
}

- (void)stopEngine
{
    TestEngineLog(@"TestEngine... stopEngine %lu %lu", (unsigned long)self.engineType, (unsigned long)self.coreType);
    
    if (_recording) {
        _recording = NO;
        [self startWatchDog];
    }
    
    [self beginTimeTrack];
}

- (void)cancelEngine
{
    TestEngineLog(@"TestEngine... cancelEngine %lu %lu", (unsigned long)self.engineType, (unsigned long)self.coreType);

    _recording = NO;
    
    [self stopWatchDog];
}

- (void)deleteEngine
{
    TestEngineLog(@"TestEngine... deleteEngine %lu %lu", (unsigned long)self.engineType, (unsigned long)self.coreType);

    _recording = NO;
    
    [self stopWatchDog];
}

- (void)playback
{
    
}

#pragma mark -

- (void)stopReplay
{
    
}

- (void)replayLastRec
{
    
}

- (void)replayRecWithRecID:(NSString *)recID
{
    
}

- (void)replayRecWithPath:(NSString *)path
{
    
}

- (void)replayRecWithName:(NSString *)filename
{
    
}

- (void)releaseService
{
    [self stopWatchDog];

}

#pragma mark -

- (void)beginParseContent
{
    _recording = NO;
    
    [self stopWatchDog];
    
    [self markTimeTrack];
}

- (void)beginTimeTrack
{
    _startTime = BEGIN_TIME;
    _stopTime = 0;
    _costTime = 0;
}

- (void)markTimeTrack
{
    _stopTime = BEGIN_TIME;
    _costTime = _stopTime - _startTime;
}

#pragma mark -

- (NSString *)generateRecordName
{
    NSString *audioName = [[NSUUID UUID] UUIDString];
    return [self generateRecordName:audioName];
}

- (NSString *)generateRecordName:(NSString *)audioName
{
    NSString *audioType = [self audioType];
    return [NSString stringWithFormat:@"%@.%@", audioName, audioType];
}

- (NSString *)getRecordSavePath
{
    NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    return [docPath stringByAppendingPathComponent:@"record"];
}

- (NSString *)getRecordPath
{
    if (!self.recordName) {
        return nil;
    }
    
    return [self getFilePath:self.recordName];
}

- (NSString *)getFilePath:(NSString *)filename
{
    return [[self getRecordSavePath] stringByAppendingPathComponent:filename];
}

- (void)createSaveRecPath:(NSString *)path
{
    struct stat statBuf;
    const char *cpath = [path fileSystemRepresentation];//这里 一定不要用 UTF8String
    if (cpath && stat(cpath, &statBuf) == 0 && S_ISDIR(statBuf.st_mode)) {
        
    } else {
        [[NSFileManager defaultManager] createDirectoryAtPath:path
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:NULL];
    }
}

- (void)appendDic:(NSMutableDictionary *)dic key:(NSString *)key object:(id)object
{
    if (!key || !object) {
        return;
    }
    
    [dic setObject:object forKey:key];
}

- (NSMutableDictionary *)returnResultDic
{
    NSMutableDictionary *returnDic = [NSMutableDictionary dictionary];
    [self appendDic:returnDic key:@"deviceType" object:@"1"];// 1 ios 2 android
    [self appendDic:returnDic key:@"engineType" object:@(self.engineType)];
    [self appendDic:returnDic key:@"costTime" object:@(self.costTime)];
    [self appendDic:returnDic key:@"coreType" object:@(self.coreType)];
    [self appendDic:returnDic key:@"appVersion" object:appVersion];
    [self appendDic:returnDic key:@"userId" object:self.userId];
    
    return returnDic;
}

#pragma mark -

- (BOOL)enableVolumeBlock
{
    return (self.volumeBlock != nil);
}

- (NSString *)audioType
{
    return @"wav";
}

#pragma mark -

- (void)startWatchDog
{
    if (!self.openWatchDog) return;
    
    [self stopWatchDog];
    
    TestEngineLog(@"TestEngine... startWatchDog %lu %lu", (unsigned long)self.engineType, (unsigned long)self.coreType);
    
    _watchDogTimer = [NSTimer timerWithTimeInterval:TestEngineServerTimeout + 1.5 target:self selector:@selector(watchDogAction) userInfo:nil repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:_watchDogTimer forMode:NSRunLoopCommonModes];
}

- (void)watchDogAction
{
    if (!self.openWatchDog) return;
    
    TestEngineLog(@"TestEngine... watchDogAction %lu %lu", (unsigned long)self.engineType, (unsigned long)self.coreType);
    
    _dogKill = YES;
}

- (void)stopWatchDog
{
    if (!self.openWatchDog) return;
    
    _dogKill = NO;
    
    if (_watchDogTimer) {
        
        TestEngineLog(@"TestEngine... stopWatchDog %lu %lu", (unsigned long)self.engineType, (unsigned long)self.coreType);
        
        [_watchDogTimer invalidate];
        _watchDogTimer = nil;
    }
}

- (NSInteger)validRecDuration
{
    return 20 * 1000;
}

- (void)returnFinished:(NSDictionary *)result returnResult:(NSDictionary *)returnResult
{
    int costTime = self.costTime;
    float delay = (costTime < self.safeWait) ? 0.8 : 0;
    NSDictionary *_result = [NSDictionary dictionaryWithDictionary:result];
    NSDictionary *_returnResult = [NSDictionary dictionaryWithDictionary:returnResult];
    NSString *filePath = [self getRecordPath];
    NSString *_filePath = [NSString stringWithFormat:@"%@", filePath];
    
    __weak typeof(self) wkSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(wkSelf) sgSelf = wkSelf;

        if (sgSelf.finishBlock) {
            sgSelf.finishBlock(_filePath, _result, _returnResult, costTime, sgSelf.engineType, sgSelf.coreType);
        }
    });
}

- (void)returnFailed:(NSString *)msg code:(int)code
{
    [self beginParseContent];
    
    int costTime = self.costTime;
    float delay = (costTime < self.safeWait) ? 0.8 : 0;
    
    TestCoreType coreType = self.coreType;
    TestEngineType engineType = self.engineType;
    
    NSString *content = [NSString stringWithFormat:@"%@", self.content];
    NSDictionary *result = [NSDictionary dictionaryWithDictionary:self.result];
    NSString *tipMsg = [self getTipMsg:code msg:msg];
    NSString *userId = self.userId;
    
    __weak typeof(self) wkSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(wkSelf) sgSelf = wkSelf;
        if (sgSelf.failed2Block) {
            NSString *res = [TSJSON ts_stringFromObject:result];
            
            NSDictionary *errInfo = @{
                                      @"code" : @(code),
                                      @"costTime" : @(costTime),
                                      @"engineType" : @(engineType),
                                      @"coreType" : @(coreType),
                                      @"msg" : tipMsg ? tipMsg : @"",
                                      @"orginMsg" :msg ? msg : @"",
                                      @"userId" : userId ? userId : @"",
                                      @"content" : content ? content : @"",
                                      @"result" : res ? res : @"",
                                      };
            NSError *error = [NSError errorWithDomain:@"TestEngineTestFailed" code:code userInfo:errInfo];
            
            sgSelf.failed2Block(tipMsg, code, error);
        }
        
        if (sgSelf.failedBlock) {
            sgSelf.failedBlock(tipMsg, code, msg, costTime, engineType, coreType, content, result);
        }
    });
}

- (NSString *)getTipMsg:(int)code msg:(NSString *)msg
{
    return [NSString stringWithFormat:@"评测超时，请重试。%d", code];
}

- (void)parseResult:(NSDictionary *)testResult
{
    _result = testResult;
    
}

- (void)initCallback:(BOOL)isSuccess ret:(int)ret initBlock:(TestInitBlock)initBlock
{
    _initedEngine = YES;
    _initedEngineResult = isSuccess;
    
    [self markTimeTrack];
    
    __weak typeof(self) wkSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(wkSelf) sgSelf = wkSelf;
        if (!sgSelf) {
            return ;
        }
        
        if (initBlock) {
            initBlock(isSuccess, ret, sgSelf.costTime, sgSelf.engineType, sgSelf.coreType);
        }
    });
}

@end
