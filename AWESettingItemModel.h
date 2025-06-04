// AWESettingItemModel.h
#import <Foundation/Foundation.h>

@interface AWESettingItemModel : NSObject

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, assign) BOOL enabled;

@end
