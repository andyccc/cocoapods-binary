//
//  TestEngineService.h
//  KouyuDemo
//
//  Created by yans on 2018/5/14.
//  Copyright © 2018年 Attu. All rights reserved.
//

#import <Foundation/Foundation.h>

#define TestEngineServerTimeout (100)
#define TestEngineConnectTimeout (60)
#define TestEngineLog   NSLog

typedef enum : NSUInteger {
    TestCoreType_EN_Word = 1,           //英文单词
    TestCoreType_EN_Sentence,           //英文句子
    TestCoreType_CN_Word,               //中文单词
    TestCoreType_CN_Sentence,           //中文句子
} TestCoreType;

typedef enum : NSUInteger {
    TestEngineTypeST,                   //声通
    TestEngineTypeCV,                   //驰声
} TestEngineType;

//年龄段支持
typedef enum : NSUInteger {
    TestEngineAgeGroupSupportOption_Junior = 1,     //3~6years-old
    TestEngineAgeGroupSupportOption_Middle,         //6~12years-old default
    TestEngineAgeGroupSupportOption_Senior,         //>12years-old
} TestEngineAgeGroupSupportOption;

#define GET_ENGLIST_VOICESDK(type)  [TestEngineService getEngineVoiceSDKType:type]

typedef void(^TestInitBlock)(BOOL isSuccess, int code, double costTime, TestEngineType engineType, TestCoreType coreType);
typedef void(^TestFinishBlock)(NSString *filePath, NSDictionary *resutDic, NSDictionary *orginResultDic, double costTime, TestEngineType engineType, TestCoreType coreType);
typedef void(^TestFailedBlock)(NSString *msg, int code, NSString *orginMsg, double costTime, TestEngineType engineType, TestCoreType coreType, NSString *content, NSDictionary *result);
typedef void(^TestFailed2Block)(NSString *msg, int code, NSError *error);

typedef void(^TestVolumeBlock)(CGFloat volume, TestEngineType engineType, TestCoreType coreType);

@interface TestEngineService : NSObject

@property (nonatomic, assign, readonly) BOOL initedEngine;
@property (nonatomic, assign, readonly) BOOL initedEngineResult;//启动结果

@property (nonatomic, assign) double startTime;
@property (nonatomic, assign) double stopTime;
@property (nonatomic, assign) double costTime;

@property (nonatomic, assign) double safeWait;//默认YES

@property (nonatomic, assign) BOOL openWatchDog;//默认YES
@property (nonatomic, assign, readonly) BOOL dogKill;

@property (nonatomic, copy, readonly) NSString *content;
@property (nonatomic, copy, readonly) NSDictionary *result;

/// 录音文件名 带 .wav后缀
@property (nonatomic, strong) NSString *recordName;

@property (nonatomic, strong, readonly) NSTimer *watchDogTimer;

/// 年龄段支持 目前只有英文设置有效 只有 middle 和 senior
@property (nonatomic, assign) TestEngineAgeGroupSupportOption ageGroupSupportOption;

/// SDK类型
@property (nonatomic, assign) TestEngineType engineType;

/// 内核类型
@property (nonatomic, assign) TestCoreType coreType;

/// 状态
@property (nonatomic, assign, readonly) BOOL recording;

/// 录音时长，到此值会自动停止，单位ms
@property (nonatomic, assign) NSInteger recDuration;

/// 评测结果回调
@property (nonatomic, copy) TestFinishBlock finishBlock;

/// 音量回调
@property (nonatomic, copy) TestVolumeBlock volumeBlock;

/// 错误回调
@property (nonatomic, copy) TestFailedBlock failedBlock;

@property (nonatomic, copy) TestFailed2Block failed2Block;

/// 可选, 用户在应用中的唯一标识 
@property (nonatomic, copy, readonly) NSString *userId;

- (void)initEngine:(TestInitBlock)initBlock;

#pragma mark - 启动入口
- (void)startEngineWithContent:(NSString *)content;
#pragma mark - 开始评测
- (void)stopEngine;

- (void)cancelEngine;
- (void)deleteEngine;
- (void)playback;

- (void)stopReplay;
- (void)replayLastRec;
- (void)replayRecWithRecID:(NSString *)recID;
- (void)replayRecWithPath:(NSString *)path;
- (void)replayRecWithName:(NSString *)filename;

- (void)startWatchDog;
- (void)stopWatchDog;

@property (nonatomic, copy) void (^recorderReplayStartCallback)(NSString *filePath, float dur);
@property (nonatomic, copy) void (^recorderReplayFinishedCallback)(NSString *filePath);

- (void)releaseService;

+ (id)initWithEngineType:(TestEngineType)engineType coreType:(TestCoreType)coreType block:(TestInitBlock)block;
+ (id)initWithEngineType:(TestEngineType)engineType coreType:(TestCoreType)coreType userId:(NSString *)userId block:(TestInitBlock)block;

- (void)appendDic:(NSMutableDictionary *)dic key:(NSString *)key object:(id)object;
- (NSMutableDictionary *)returnResultDic;

- (NSString *)generateRecordName;
- (NSString *)generateRecordName:(NSString *)audioName;
- (NSString *)getRecordSavePath;
- (NSString *)getRecordPath;
- (NSString *)getFilePath:(NSString *)filename;

- (BOOL)enableVolumeBlock;
- (NSString *)audioType;

- (void)beginParseContent;
- (void)beginTimeTrack;
- (void)markTimeTrack;

- (void)watchDogAction;
+ (TestEngineType)getEngineVoiceSDKType:(NSNumber *)type;

- (NSInteger)validRecDuration;
- (void)returnFinished:(NSDictionary *)result returnResult:(NSDictionary *)returnResult;
- (void)returnFailed:(NSString *)msg code:(int)code;
- (void)parseResult:(NSDictionary *)testResult;
- (void)initCallback:(BOOL)isSuccess ret:(int)ret initBlock:(TestInitBlock)initBlock;

@end








