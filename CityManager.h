#import <Foundation/Foundation.h>

@interface CityManager : NSObject

@property (nonatomic, strong) NSDictionary *cityCodeMap;

+ (instancetype)sharedInstance;

/// 获取最具体层级的行政区名称
- (NSString *)getCityNameWithCode:(NSString *)code;

/// 获取省级名称
- (NSString *)getProvinceNameWithCode:(NSString *)code;

/// 获取完整行政路径
- (NSString *)getFullCityNameWithCode:(NSString *)code;

/// 加载行政区数据
- (void)loadCityData;

@end
