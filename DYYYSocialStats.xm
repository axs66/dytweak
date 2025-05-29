#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "AwemeHeaders.h"
#import "DYYYManager.h"

// 添加完整接口声明
@interface AWEProfileSocialStatisticView : UIView
- (void)setFansCount:(NSNumber *)count;
- (void)setPraiseCount:(NSNumber *)count;
- (void)setFollowingCount:(NSNumber *)count;
- (void)setFriendCount:(NSNumber *)count;
- (void)p_updateSocialStatisticContent:(BOOL)animated;
@end

@interface AWEProfileHeaderMyProfileViewController : UIViewController
- (void)reloadSettings;
@end

// 控制开关 & 自定义数据持久化
#define DYYY_SOCIAL_STATS_ENABLED_KEY @"DYYYEnableSocialStatsCustom"
#define DYYY_SOCIAL_FOLLOWERS_KEY @"DYYYCustomFollowers"
#define DYYY_SOCIAL_LIKES_KEY @"DYYYCustomLikes"
#define DYYY_SOCIAL_FOLLOWING_KEY @"DYYYCustomFollowing"
#define DYYY_SOCIAL_MUTUAL_KEY @"DYYYCustomMutual"

// 静态缓存
static NSString *customFollowersCount = nil;
static NSString *customLikesCount = nil;
static NSString *customFollowingCount = nil;
static NSString *customMutualCount = nil;
static BOOL socialStatsEnabled = NO;

// 静态缓存的NSNumber值
static NSNumber *cachedFollowersNumber = nil;
static NSNumber *cachedLikesNumber = nil;
static NSNumber *cachedFollowingNumber = nil;
static NSNumber *cachedMutualNumber = nil;

// 防止重复更新（节流控制）
static NSTimeInterval lastSocialStatsUpdateTime = 0;
static NSTimeInterval const socialStatsUpdateInterval = 1.0; // 最小1秒更新间隔

// 函数声明
static void loadCustomSocialStats(void);
static void updateModelDataIfMine(id model);

// 加载设置数据
static void loadCustomSocialStats() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    socialStatsEnabled = [defaults boolForKey:DYYY_SOCIAL_STATS_ENABLED_KEY];
    
    if (socialStatsEnabled) {
        customFollowersCount = [defaults objectForKey:DYYY_SOCIAL_FOLLOWERS_KEY];
        customLikesCount = [defaults objectForKey:DYYY_SOCIAL_LIKES_KEY];
        customFollowingCount = [defaults objectForKey:DYYY_SOCIAL_FOLLOWING_KEY];
        customMutualCount = [defaults objectForKey:DYYY_SOCIAL_MUTUAL_KEY];
        
        cachedFollowersNumber = customFollowersCount ? @([customFollowersCount longLongValue]) : nil;
        cachedLikesNumber = customLikesCount ? @([customLikesCount longLongValue]) : nil;
        cachedFollowingNumber = customFollowingCount ? @([customFollowingCount longLongValue]) : nil;
        cachedMutualNumber = customMutualCount ? @([customMutualCount longLongValue]) : nil;
    }
}

// 判断是否是自己主页，只有自己主页才替换数据
static BOOL isMyProfile(id model) {
    // 这里示范用 model 的一个属性判断，具体按你的模型修改
    if ([model respondsToSelector:NSSelectorFromString(@"isMyProfile")]) {
        BOOL myProfile = ((BOOL (*)(id, SEL))objc_msgSend)(model, NSSelectorFromString(@"isMyProfile"));
        return myProfile;
    }
    // 如果没有该属性，返回NO，避免误替换别人数据
    return NO;
}

// 模型数据更新（仅替换自己主页数据）
static void updateModelDataIfMine(id model) {
    if (!socialStatsEnabled || !model) return;
    if (!isMyProfile(model)) return;  // 不是自己主页则不替换
    
    // 粉丝
    if (cachedFollowersNumber) {
        NSArray *followerKeys = @[@"followerCount", @"fansCount", @"fans_count"];
        for (NSString *key in followerKeys) {
            if ([model respondsToSelector:NSSelectorFromString(key)]) {
                [model setValue:cachedFollowersNumber forKey:key];
            }
        }
    }
    
    // 获赞
    if (cachedLikesNumber) {
        NSArray *likeKeys = @[
            @"totalFavorited", @"favoriteCount", @"diggCount",
            @"praiseCount", @"likeCount", @"like_count",
            @"total_favorited", @"favorite_count", @"digg_count"
        ];
        for (NSString *key in likeKeys) {
            if ([model respondsToSelector:NSSelectorFromString(key)]) {
                [model setValue:cachedLikesNumber forKey:key];
            }
        }
    }
    
    // 关注
    if (cachedFollowingNumber) {
        NSArray *followingKeys = @[@"followingCount", @"followCount", @"follow_count"];
        for (NSString *key in followingKeys) {
            if ([model respondsToSelector:NSSelectorFromString(key)]) {
                [model setValue:cachedFollowingNumber forKey:key];
            }
        }
    }
    
    // 互关
    if (cachedMutualNumber) {
        NSArray *mutualKeys = @[
            @"friendCount", @"mutualFriendCount", @"followFriendCount",
            @"mutualCount", @"friend_count", @"mutual_friend_count",
            @"follow_friend_count", @"mutual_count"
        ];
        for (NSString *key in mutualKeys) {
            if ([model respondsToSelector:NSSelectorFromString(key)]) {
                [model setValue:cachedMutualNumber forKey:key];
            }
        }
    }
}

// 数据Hook
%hook AWEUserModel
- (id)init {
    id instance = %orig;
    if (socialStatsEnabled && instance) {
        updateModelDataIfMine(instance);
    }
    return instance;
}

- (NSNumber *)followerCount {
    if (socialStatsEnabled && cachedFollowersNumber && isMyProfile(self)) {
        return cachedFollowersNumber;
    }
    return %orig;
}

- (void)setFollowerCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedFollowersNumber && isMyProfile(self)) {
        %orig(cachedFollowersNumber);
    } else {
        %orig(count);
    }
}

- (NSNumber *)followingCount {
    if (socialStatsEnabled && cachedFollowingNumber && isMyProfile(self)) {
        return cachedFollowingNumber;
    }
    return %orig;
}

- (void)setFollowingCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedFollowingNumber && isMyProfile(self)) {
        %orig(cachedFollowingNumber);
    } else {
        %orig(count);
    }
}

- (NSNumber *)totalFavorited {
    if (socialStatsEnabled && cachedLikesNumber && isMyProfile(self)) {
        return cachedLikesNumber;
    }
    return %orig;
}

- (void)setTotalFavorited:(NSNumber *)count {
    if (socialStatsEnabled && cachedLikesNumber && isMyProfile(self)) {
        %orig(cachedLikesNumber);
    } else {
        %orig(count);
    }
}

- (NSNumber *)diggCount {
    if (socialStatsEnabled && cachedLikesNumber && isMyProfile(self)) {
        return cachedLikesNumber;
    }
    return %orig;
}

- (void)setDiggCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedLikesNumber && isMyProfile(self)) {
        %orig(cachedLikesNumber);
    } else {
        %orig(count);
    }
}

- (NSNumber *)likeCount {
    if (socialStatsEnabled && cachedLikesNumber && isMyProfile(self)) {
        return cachedLikesNumber;
    }
    return %orig;
}

- (void)setLikeCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedLikesNumber && isMyProfile(self)) {
        %orig(cachedLikesNumber);
    } else {
        %orig(count);
    }
}

- (NSNumber *)friendCount {
    if (socialStatsEnabled && cachedMutualNumber && isMyProfile(self)) {
        return cachedMutualNumber;
    }
    return %orig;
}

- (void)setFriendCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedMutualNumber && isMyProfile(self)) {
        %orig(cachedMutualNumber);
    } else {
        %orig(count);
    }
}

- (NSNumber *)mutualFriendCount {
    if (socialStatsEnabled && cachedMutualNumber && isMyProfile(self)) {
        return cachedMutualNumber;
    }
    return %orig;
}

- (void)setMutualFriendCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedMutualNumber && isMyProfile(self)) {
        %orig(cachedMutualNumber);
    } else {
        %orig(count);
    }
}

- (NSNumber *)followFriendCount {
    if (socialStatsEnabled && cachedMutualNumber && isMyProfile(self)) {
        return cachedMutualNumber;
    }
    return %orig;
}

- (void)setFollowFriendCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedMutualNumber && isMyProfile(self)) {
        %orig(cachedMutualNumber);
    } else {
        %orig(count);
    }
}
%end

// 统计视图
%hook AWEProfileSocialStatisticView

- (void)setFansCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedFollowersNumber && isMyProfile(self)) {
        %orig(cachedFollowersNumber);
    } else {
        %orig(count);
    }
}

- (void)setPraiseCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedLikesNumber && isMyProfile(self)) {
        %orig(cachedLikesNumber);
    } else {
        %orig(count);
    }
}

- (void)setFollowingCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedFollowingNumber && isMyProfile(self)) {
        %orig(cachedFollowingNumber);
    } else {
        %orig(count);
    }
}

- (void)setFriendCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedMutualNumber && isMyProfile(self)) {
        %orig(cachedMutualNumber);
    } else {
        %orig(count);
    }
}

// 节流处理，控制更新频率
- (void)p_updateSocialStatisticContent:(BOOL)animated {
    NSTimeInterval now = CACurrentMediaTime();
    if (now - lastSocialStatsUpdateTime < socialStatsUpdateInterval) {
        return;
    }
    lastSocialStatsUpdateTime = now;
    
    %orig;
    
    if (socialStatsEnabled && isMyProfile(self)) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (socialStatsEnabled) {
                [self setFansCount:cachedFollowersNumber];
                [self setPraiseCount:cachedLikesNumber];
                [self setFollowingCount:cachedFollowingNumber];
                [self setFriendCount:cachedMutualNumber];
            }
        });
    }
}

// 优化取消 layoutSubviews 中重复调用，改为仅调用一次更新
- (void)layoutSubviews {
    %orig;
    [self p_updateSocialStatisticContent:YES];
}

%end

// NSDictionary的objectForKey: hook
%hook NSDictionary

// 声明一个静态变量和初始化函数
static NSSet *keySet = nil;

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keySet = [NSSet setWithObjects:
                  @"totalFavorited", @"followerCount", @"followingCount", @"friendCount",
                  @"favoriteCount", @"diggCount", @"praiseCount", @"likeCount", @"like_count",
                  @"fansCount", @"fans_count", @"followCount", @"follow_count", @"mutualFriendCount",
                  @"followFriendCount", @"mutualCount", @"friend_count", @"mutual_friend_count",
                  @"follow_friend_count", @"mutual_count", @"total_favorited", @"favorite_count",
                  @"digg_count", nil];
    });
}

- (id)objectForKey:(id)key {
    id origVal = %orig(key);
    if (!socialStatsEnabled || !key || ![key isKindOfClass:[NSString class]]) {
        return origVal;
    }
    
    if (![keySet containsObject:key]) {
        return origVal;
    }
    
    // 只有“我的主页”才替换，判断方式需要根据上下文调整
    // 这里没上下文判断，只简单示范
    // 建议结合调用堆栈、对象上下文判断
    
    if ([key isEqualToString:@"followerCount"] || [key isEqualToString:@"fansCount"] || [key isEqualToString:@"fans_count"]) {
        if (cachedFollowersNumber) return cachedFollowersNumber;
    }
    if ([key isEqualToString:@"totalFavorited"] || [key isEqualToString:@"favoriteCount"] || [key isEqualToString:@"diggCount"] ||
        [key isEqualToString:@"praiseCount"] || [key isEqualToString:@"likeCount"] || [key isEqualToString:@"like_count"] ||
        [key isEqualToString:@"total_favorited"] || [key isEqualToString:@"favorite_count"] || [key isEqualToString:@"digg_count"]) {
        if (cachedLikesNumber) return cachedLikesNumber;
    }
    if ([key isEqualToString:@"followingCount"] || [key isEqualToString:@"followCount"] || [key isEqualToString:@"follow_count"]) {
        if (cachedFollowingNumber) return cachedFollowingNumber;
    }
    if ([key isEqualToString:@"friendCount"] || [key isEqualToString:@"mutualFriendCount"] || [key isEqualToString:@"followFriendCount"] ||
        [key isEqualToString:@"mutualCount"] || [key isEqualToString:@"friend_count"] || [key isEqualToString:@"mutual_friend_count"] ||
        [key isEqualToString:@"follow_friend_count"] || [key isEqualToString:@"mutual_count"]) {
        if (cachedMutualNumber) return cachedMutualNumber;
    }
    
    return origVal;
}

%end

// Hook控制器reloadSettings刷新界面数据，强制刷新数据
%hook AWEProfileHeaderMyProfileViewController

- (void)reloadSettings {
    loadCustomSocialStats();
    %orig;
}
%end

// 在插件加载时读取设置
__attribute__((constructor)) static void initSocialStatsReplacement() {
    loadCustomSocialStats();
}
