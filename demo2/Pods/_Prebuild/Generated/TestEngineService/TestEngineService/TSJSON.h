//
//  TSJSON.h
//  Pods-TestEngineService_Example
//
//  Created by yans on 2019/9/11.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TSJSON : NSObject

+ (NSString *)ts_stringFromObject:(id)object;
+ (NSDictionary *)ts_objectFromJSONString:(NSString *)string;

@end

NS_ASSUME_NONNULL_END
