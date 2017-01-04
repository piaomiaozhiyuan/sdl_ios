//
//  SDLObjectWithPriority.h
//  SmartDeviceLink
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SDLObjectWithPriority : NSObject

@property (nullable, strong) id object;
@property (assign) NSInteger priority;

- (instancetype)initWithObject:(nullable id)object priority:(NSInteger)priority NS_DESIGNATED_INITIALIZER;

+ (instancetype)objectWithObject:(nullable id)object priority:(NSInteger)priority;

@end

NS_ASSUME_NONNULL_END
