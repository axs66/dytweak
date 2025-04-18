#import <Foundation/Foundation.h>

@interface CityManager : NSObject

@property (nonatomic, strong) NSDictionary *cityCodeMap;

+ (instancetype)sharedInstance;
- (void)loadCityData;

- (NSString *)getCityNameWithCode:(NSString *)code;
- (NSString *)getProvinceNameWithCode:(NSString *)code;
- (NSString *)getFullCityNameWithCode:(NSString *)code;

@end
