//
//  STTestEngineService.m
//  STC
//
//  Created by yans on 2018/5/14.
//  Copyright © 2018年 yans. All rights reserved.
//

#import "STTestEngineService.h"
#import <STKouyuEngine/STKouyuEngine.h>
#import "TSJSON.h"

#define STAppKey @"1515390487000053"
#define STSecretKey @"2fdada4d487cd25404a6a9c2a6634bf1"


@interface STTestEngineService ()
{

}

@property (nonatomic, strong) KYStartEngineConfig *engineConfig;

@end

@implementation STTestEngineService

- (void)dealloc
{
    
}

- (void)initEngine:(TestInitBlock)initBlock
{
    [super initEngine:initBlock];
    
    __weak typeof(self) wkSelf = self;
    [self.engineInstance initEngine:KY_CloudEngine startEngineConfig:self.engineConfig finishBlock:^(BOOL isSuccess) {
        __strong typeof(wkSelf) sgSelf = wkSelf;
        dispatch_async(dispatch_get_main_queue(), ^{
            TestEngineLog(@"STKouyuEngine initCallback, isSuccess:%d", isSuccess);

            [sgSelf initCallback:isSuccess ret:isSuccess ? 0 : -1 initBlock:initBlock];
        });
    }];
}

#pragma mark -

- (KYTestConfig *)createConfig
{
    return [self createConfigWithContent:nil];
}

- (KYTestConfig *)createConfigWithContent:(NSString *)content
{
    return [self createConfigWithContent:content recordPath:nil];
}

- (KYTestConfig *)createConfigWithContent:(NSString *)content recordPath:(NSString *)recordPath
{
    NSInteger coreType = [self currentCoreType];
    NSAssert4((coreType  > -1), @"不支持的coreType:%@, %s, %s, %d", @(self.coreType), __FILE__, __FUNCTION__, __LINE__);
    
    NSString *audioType = [self audioType];
    self.recordName = [self generateRecordName];
    
    KYTestConfig *config = [[KYTestConfig alloc] init];
    config.protocol = @"http";
    config.coreType = coreType;
    config.audioType = audioType;
    config.compress = KYCompress_Speex;
    config.recordName = self.recordName;
    config.recordPath = [self getRecordSavePath];
    config.soundIntensityEnable = [self enableVolumeBlock]; //返回音强
    config.ageGroup = (NSUInteger)self.ageGroupSupportOption;
    if (content) {
        config.refText = content;
    }
    
    if (recordPath) {
        config.audioPath = recordPath;
    }
    
    if (self.userId && self.userId.length > 0) {
        config.userId = self.userId;// 默认 ‘user-id’ 如果传空'' 41002 错误，传nil 无结果返回
    }
    
    return config;
}

#pragma mark -

- (void)startEngineWithContent:(NSString *)content
{
    [self startEngineWithContent:content recordFile:nil];
}

- (void)startEngineWithContent:(NSString *)content recordFile:(NSString *)recordFile
{
    if (!self.initedEngine) {
        TestEngineLog(@"TestEngine... startEngineWithContent %lu %lu error:没有启动", (unsigned long)self.engineType, (unsigned long)self.coreType);
        return;
    }
    
    if (self.recording) {
        TestEngineLog(@"TestEngine... startEngineWithContent [%@] %lu %lu error:重复启动", content, (unsigned long)self.engineType, (unsigned long)self.coreType);
        return;
    }
    
    [super startEngineWithContent:content];
    
    KYTestConfig *config = [self createConfigWithContent:content];
    
    __weak typeof(self) wkSelf = self;
    [self.engineInstance startEngineWithTestConfig:config result:^(NSString *testResult) {
        __strong typeof(wkSelf) sgSelf = wkSelf;
        if ([sgSelf dogKill]) {
            return;
        }
        [sgSelf parseResultString:testResult];
    }];
}

/**
 关闭引擎（有回调）
 */
- (void)stopEngine
{
    if (self.recording) {
        if (self.initedEngine) {
            [self.engineInstance stopEngine];
        } else {
            TestEngineLog(@"TestEngine... stopEngine %lu %lu error:没有启动", (unsigned long)self.engineType, (unsigned long)self.coreType);
        }
    }
    
    [super stopEngine];
}

/**
 取消评测（无回调）
 */
- (void)cancelEngine
{
    [super cancelEngine];
    
    [self.engineInstance cancelEngine];
}

/**
 销毁引擎
 */
- (void)deleteEngine
{
    [super deleteEngine];
    
    [self.engineInstance deleteEngine];
}

/**
 回放
 */
- (void)playback
{
    [super playback];
    
    [self.engineInstance playback];
}

#pragma mark -

- (void)stopReplay
{
    [super stopReplay];
}

- (void)replayLastRec
{
    [super replayLastRec];
}

- (void)replayRecWithRecID:(NSString *)recID
{
    [super replayRecWithRecID:recID];
}

- (void)replayRecWithPath:(NSString *)path
{
    [super replayRecWithPath:path];
    
    [self.engineInstance playWithPath:path];
}

- (void)replayRecWithName:(NSString *)filename
{
    [super replayRecWithName:filename];
}

- (void)releaseService
{
    [super releaseService];
}

#pragma mark - watchdog

- (void)watchDogAction
{
    [super watchDogAction];
    
    [self markTimeTrack];
    
    [self returnFailed:@"评测超时，请重试！" code:-1];

    [self stopWatchDog];
}

#pragma mark -

- (void)parseResultString:(NSString *)testResult
{
    NSDictionary *result = [TSJSON ts_objectFromJSONString:testResult];
    [self parseResult:result];
}

- (void)parseResult:(NSDictionary *)result
{
    [super parseResult:result];

    if (result && [result count] ) {
        if ([result objectForKey:@"errId"] || [result objectForKey:@"error"]) { //错误回调
            [self parseError:result];
        } else if ([self enableVolumeBlock]) {
            NSNumber *intensity = [result objectForKey:@"sound_intensity"];
            if (intensity) {
                [self parseVolume:result];
            }
        } else {  //评测结果回调
            [self parseENContent:result];
        }
    } else {
        [self returnFailed:@"评测超时，请重试！!" code:-1];
    }
}

- (BOOL)parseError:(NSDictionary *)result
{
    /*
     {"error":"Illegal order of execution, before start service's status should be connect or end","dtLastResponse":"2018-05-14 17:43:48:476","eof":1,"errId":42003}
     */
    
    NSString *errMsg = result[@"error"];
    NSNumber *errId = result[@"errId"];
    int code = [errId intValue];

    [self returnFailed:errMsg code:code];
    
    return YES;
}

- (BOOL)parseVolume:(NSDictionary *)result
{
    /*
     {"sound_intensity": 0.000000}
     */
    
    CGFloat soundIntensity = [[result objectForKey:@"sound_intensity"] floatValue] / 100.0f;
    
    if (self.volumeBlock) {
        self.volumeBlock(soundIntensity, self.engineType, self.coreType);
    }
    
    return YES;
}


- (BOOL)parseENContent:(NSDictionary *)dataDic
{
    [self beginParseContent];

    /*
     {"applicationId":"1515390487000053","tokenId":"5af95b0f3a320695e8000003","recordId":"5af95b0f1667d1fbec2e6096","dtLastResponse":"2018-05-14 17:46:57:233","result":{"words":[{"scores":{"overall":17,"pronunciation":17,"stress":[{"phonetic":"kəmpjutər","spell":"computer","stress":1,"ref_stress":1}]},"charType":0,"word":"computer","span":{"end":156,"start":56},"phonemes":[{"span":{"end":59,"start":56},"phoneme":"k","pronunciation":0},{"span":{"end":64,"start":59},"phoneme":"ə","pronunciation":52},{"span":{"end":88,"start":64},"phoneme":"m","pronunciation":0},{"span":{"end":100,"start":88},"phoneme":"p","pronunciation":10},{"span":{"end":107,"start":100},"phoneme":"j","pronunciation":100},{"span":{"end":121,"start":107},"phoneme":"u","pronunciation":78},{"span":{"end":131,"start":121},"phoneme":"t","pronunciation":0},{"span":{"end":141,"start":131},"phoneme":"ə","pronunciation":78}]}],"pronunciation":17,"kernel_version":"2.8.0","overall":17,"resource_version":"1.4.8","duration":"1.800","stress":0},"eof":1,"params":{"app":{"timestamp":"1526291215","sig":"70b3c18963162e9a6086b07f144bb21c7323f56b","applicationId":"1515390487000053","userId":"user-id","clientId":"9a90887d-2a18-4dcd-bbdf-284d80dd5839"},"request":{"phoneme_output":1,"tokenId":"5af95b0f3a320695e8000003","refText":"computer","coreType":"word.eval","dict_type":"KK"},"audio":{"sampleBytes":2,"channel":1,"sampleRate":16000,"audioType":"ogg"}},"refText":"computer"}
     */
    
    NSDictionary *resultDic = dataDic[@"result"];
    
    NSString *tokenId = dataDic[@"tokenId"];
    // 记录id
    NSString *recordId = dataDic[@"recordId"];
    // 总分
    NSNumber *overall = resultDic[@"overall"];
    // 时长
    NSString *duration = resultDic[@"duration"];
    // 完整度 (单词无)
    NSNumber *integrity = nil;
    // 流利度 (单词无)
    NSNumber *fluency = nil;
    
    // 单词列表
    NSMutableArray *items = [NSMutableArray array];
    
    // 匹配度 准确度
    // NSString *confidence = resultDic[@"confidence"];
    
    if (self.coreType == TestCoreType_EN_Word) {// 英文单词
        
    } else if (self.coreType == TestCoreType_EN_Sentence) {// 英文句子
        integrity = resultDic[@"integrity"];
        fluency = resultDic[@"fluency"];
        
        NSArray *words = resultDic[@"words"];
        if (words && [words count]) {
            for (NSDictionary *word in words) {
                [items addObject:@{
                                   @"word": word[@"word"],
                                   @"overall": word[@"scores"][@"overall"],
                                   @"beginindex": word[@"span"][@"start"],
                                   @"endindex": word[@"span"][@"end"],
                                   }];
            }
        }
    }
    
    NSMutableDictionary *returnDic = [self returnResultDic];
    [self appendDic:returnDic key:@"recordId" object:recordId];
    [self appendDic:returnDic key:@"tokenId" object:tokenId];
    [self appendDic:returnDic key:@"overall" object:overall];
    [self appendDic:returnDic key:@"duration" object:duration];
    [self appendDic:returnDic key:@"integrity" object:integrity];
    [self appendDic:returnDic key:@"fluency" object:fluency];
    [self appendDic:returnDic key:@"items" object:items];
    
//    NSString *filePath = [self getFilePathWithTokenId:tokenId];
    
    [self returnFinished:returnDic returnResult:dataDic];

    return YES;
}

#pragma mark-

- (NSString *)getFilePathWithTokenId:(NSString *)tokenId
{
    NSString *filename = [NSString stringWithFormat:@"%@.%@", tokenId, [self audioType]];
    return [self getFilePath:filename];
}

- (NSInteger)currentCoreType
{
    if (self.coreType == TestCoreType_EN_Word) {
        return KYTestType_Word;
    } else if (self.coreType == TestCoreType_EN_Sentence) {
        return KYTestType_Sentence;
    } else {
        return -1;
    }
}

#pragma mark-

- (KYStartEngineConfig *)engineConfig
{
    if (!_engineConfig) {
        KYStartEngineConfig *engineConfig = [[KYStartEngineConfig alloc] init];
        engineConfig.appKey = STAppKey;
        engineConfig.secretKey = STSecretKey;
        engineConfig.server = KY_CloudServer_Release;
        engineConfig.serverTimeout = TestEngineServerTimeout;//响应的超时时间
        engineConfig.connectTimeout = TestEngineConnectTimeout;//建立连接的超时时间
#ifdef DEBUG
        engineConfig.sdkLogEnable = YES;
#endif
        
        _engineConfig = engineConfig;
    }
    return _engineConfig;
}

- (KYTestEngine *)engineInstance
{
    return [KYTestEngine sharedInstance];
}

- (NSString *)getTipMsg:(int)code msg:(NSString *)msg
{
    NSString *tipMsg = nil;
    
    switch (code) {
        case 2:
            tipMsg = @"没有检测到语音！";
            break;
        case 5:
            tipMsg = @"评分文本不正确！";
            break;
        case 6:
            tipMsg = @"评分文本不满足要求！";
            break;
        case 400:
            tipMsg = @"音频解码错误！";
            break;
        case 407:
            tipMsg = @"参数不正确！";
            break;
        case 503:
            tipMsg = @"请求超时！";
            break;
        case 20000:
        case 20001:
        case 20002:
        case 20003:
        case 20004:
        case 20005:
        case 20006:
        case 20007:
        case 20008:
            tipMsg = @"参数错误！";
            break;
        case 20009:
            tipMsg = @"网络异常！";
            break;
        case 20010:
            tipMsg = @"接口调用顺序错误！";
            break;
        case 20011:
            tipMsg = @"没有本地调用的配置！";
            break;
        case 20012:
            tipMsg = @"没有云端调用的配置！";
            break;
        case 20013:
            //tipMsg = @"使用云服务，服务响应超时(即在stop后60s内无结果返回)";
            tipMsg = @"服务响应超时！";
            break;
        case 20014:
            tipMsg = @"授权认证失败！";
            break;
        case 20015:
            tipMsg = @"内核参数错误！";
            break;

        //这个一般作为默认值
        case -1:
        case 0:
            tipMsg = @"录音未成功，请重试！";
            break;
        default:
            tipMsg = msg ? msg : @"录音未成功，请重试！";
            break;
    }
    
    return [NSString stringWithFormat:@"%@%d", tipMsg, code];
}

@end
