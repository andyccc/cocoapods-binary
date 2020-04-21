//
//  TSJSON.m
//  Pods-TestEngineService_Example
//
//  Created by yans on 2019/9/11.
//

#import "TSJSON.h"

@implementation TSJSON

#pragma mark -

+ (NSDictionary *)ts_objectFromJSONString:(NSString *)string
{
    @try {
        NSError *error;
        NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
        if (data) {
            NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&error];
            if (!error) {
                return result;
            }
        }
        
        NSLog(@"ts_objectFromJSONString error : %@\n\n string:[%@]", error, string);
    } @catch (NSException *exception) {
        NSLog(@"ts_objectFromJSONString exception : %@\n\n string:[%@]", exception, string);
    } @finally {
        
    }
    return nil;
}

+ (NSString *)ts_stringFromObject:(id)object
{
    if (!object) return nil;
    NSString *jsonString = nil;
    @try {
        NSError *error;
        id jsonData = [NSJSONSerialization dataWithJSONObject:object options:NSJSONWritingPrettyPrinted error:&error];
        if (jsonData) {
            jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        }
        
        if (jsonString) {
            return jsonString;
        }

        NSLog(@"ts_stringFromObject error : %@\n\n object:[%@]", error, object);
    } @catch (NSException *exception) {
        NSLog(@"ts_stringFromObject exception : %@\n\n object:[%@]", exception, object);
    } @finally {
        
    }
    return jsonString;
}

@end
