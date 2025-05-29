#import <UIKit/UIKit.h>
#import <objc/runtime.h>
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

@interface AWEProfileHeaderOtherProfileViewController : UIViewController
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
static void updateModelData(id model);

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

// 模型数据更新
static void updateModelData(id model) {
    if (!socialStatsEnabled || !model) return;
    
    // 粉丝
    if (cachedFollowersNumber) {
        NSArray *followerKeys = @[@"followerCount", @"fansCount", @"fans_count", @"followersCount"];
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
            @"total_favorited", @"favorite_count", @"digg_count",
            @"awemeCount", @"aweme_count", @"videoCount"
        ];
        for (NSString *key in likeKeys) {
            if ([model respondsToSelector:NSSelectorFromString(key)]) {
                [model setValue:cachedLikesNumber forKey:key];
            }
        }
    }
    
    // 关注
    if (cachedFollowingNumber) {
        NSArray *followingKeys = @[@"followingCount", @"followCount", @"follow_count", @"followingsCount"];
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
            @"follow_friend_count", @"mutual_count", @"mutualFriendsCount"
        ];
        for (NSString *key in mutualKeys) {
            if ([model respondsToSelector:NSSelectorFromString(key)]) {
                [model setValue:cachedMutualNumber forKey:key];
            }
        }
    }
}

// 数据Hook - 核心用户模型
%hook AWEUserModel
- (id)init {
    id instance = %orig;
    if (socialStatsEnabled && instance) {
        updateModelData(instance);
    }
    return instance;
}

- (NSNumber *)followerCount {
    return socialStatsEnabled && cachedFollowersNumber ? cachedFollowersNumber : %orig;
}

- (void)setFollowerCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedFollowersNumber) {
        %orig(cachedFollowersNumber);
    } else {
        %orig;
    }
}

- (NSNumber *)followingCount {
    return socialStatsEnabled && cachedFollowingNumber ? cachedFollowingNumber : %orig;
}

- (void)setFollowingCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedFollowingNumber) {
        %orig(cachedFollowingNumber);
    } else {
        %orig;
    }
}

- (NSNumber *)totalFavorited {
    return socialStatsEnabled && cachedLikesNumber ? cachedLikesNumber : %orig;
}

- (void)setTotalFavorited:(NSNumber *)count {
    if (socialStatsEnabled && cachedLikesNumber) {
        %orig(cachedLikesNumber);
    } else {
        %orig;
    }
}

- (NSNumber *)diggCount {
    return socialStatsEnabled && cachedLikesNumber ? cachedLikesNumber : %orig;
}

- (void)setDiggCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedLikesNumber) {
        %orig(cachedLikesNumber);
    } else {
        %orig;
    }
}

- (NSNumber *)likeCount {
    return socialStatsEnabled && cachedLikesNumber ? cachedLikesNumber : %orig;
}

- (void)setLikeCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedLikesNumber) {
        %orig(cachedLikesNumber);
    } else {
        %orig;
    }
}

- (NSNumber *)friendCount {
    return socialStatsEnabled && cachedMutualNumber ? cachedMutualNumber : %orig;
}

- (void)setFriendCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedMutualNumber) {
        %orig(cachedMutualNumber);
    } else {
        %orig;
    }
}

- (NSNumber *)mutualFriendCount {
    return socialStatsEnabled && cachedMutualNumber ? cachedMutualNumber : %orig;
}

- (void)setMutualFriendCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedMutualNumber) {
        %orig(cachedMutualNumber);
    } else {
        %orig;
    }
}

- (NSNumber *)followFriendCount {
    return socialStatsEnabled && cachedMutualNumber ? cachedMutualNumber : %orig;
}

- (void)setFollowFriendCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedMutualNumber) {
        %orig(cachedMutualNumber);
    } else {
        %orig;
    }
}

- (NSNumber *)awemeCount {
    return socialStatsEnabled && cachedLikesNumber ? cachedLikesNumber : %orig;
}

- (void)setAwemeCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedLikesNumber) {
        %orig(cachedLikesNumber);
    } else {
        %orig;
    }
}
%end

// 统计视图
%hook AWEProfileSocialStatisticView

- (void)setFansCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedFollowersNumber) {
        %orig(cachedFollowersNumber);
    } else {
        %orig;
    }
}

- (void)setPraiseCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedLikesNumber) {
        %orig(cachedLikesNumber);
    } else {
        %orig;
    }
}

- (void)setFollowingCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedFollowingNumber) {
        %orig(cachedFollowingNumber);
    } else {
        %orig;
    }
}

- (void)setFriendCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedMutualNumber) {
        %orig(cachedMutualNumber);
    } else {
        %orig;
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
    
    if (socialStatsEnabled) {
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

- (void)layoutSubviews {
    %orig;
    [self p_updateSocialStatisticContent:YES];
}

%end

// 其他用户主页控制器
%hook AWEProfileHeaderOtherProfileViewController

- (void)reloadSettings {
    %orig;
    
    if (socialStatsEnabled) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            // 强制刷新统计数据
            [self performSelector:@selector(reloadSettings)];
        });
    }
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
                  @"digg_count", @"awemeCount", @"aweme_count", @"videoCount", @"followersCount",
                  @"followingsCount", @"mutualFriendsCount", nil];
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
    
    // 伪造数据替换逻辑
    if ([key isEqualToString:@"followerCount"] || [key isEqualToString:@"fansCount"] || [key isEqualToString:@"fans_count"] || [key isEqualToString:@"followersCount"]) {
        return cachedFollowersNumber ?: origVal;
    } else if ([key isEqualToString:@"totalFavorited"] || [key isEqualToString:@"favoriteCount"] || [key isEqualToString:@"diggCount"] || [key isEqualToString:@"praiseCount"] || [key isEqualToString:@"likeCount"] || [key isEqualToString:@"like_count"] || [key isEqualToString:@"total_favorited"] || [key isEqualToString:@"favorite_count"] || [key isEqualToString:@"digg_count"] || [key isEqualToString:@"awemeCount"] || [key isEqualToString:@"aweme_count"] || [key isEqualToString:@"videoCount"]) {
        return cachedLikesNumber ?: origVal;
    } else if ([key isEqualToString:@"followingCount"] || [key isEqualToString:@"followCount"] || [key isEqualToString:@"follow_count"] || [key isEqualToString:@"followingsCount"]) {
        return cachedFollowingNumber ?: origVal;
    } else if ([key isEqualToString:@"friendCount"] || [key isEqualToString:@"mutualFriendCount"] || [key isEqualToString:@"followFriendCount"] || [key isEqualToString:@"mutualCount"] || [key isEqualToString:@"friend_count"] || [key isEqualToString:@"mutual_friend_count"] || [key isEqualToString:@"follow_friend_count"] || [key isEqualToString:@"mutual_count"] || [key isEqualToString:@"mutualFriendsCount"]) {
        return cachedMutualNumber ?: origVal;
    }
    
    return origVal;
}

%end

// 配置加载入口
%ctor {
    loadCustomSocialStats();
}
