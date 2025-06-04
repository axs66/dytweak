#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "AwemeHeaders.h"
#import "DYYYManager.h"

// 接口声明
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

// 常量定义
#define DYYY_SOCIAL_STATS_ENABLED_KEY @"DYYYEnableSocialStatsCustom"
#define DYYY_SOCIAL_FOLLOWERS_KEY    @"DYYYCustomFollowers"
#define DYYY_SOCIAL_LIKES_KEY        @"DYYYCustomLikes"
#define DYYY_SOCIAL_FOLLOWING_KEY    @"DYYYCustomFollowing"
#define DYYY_SOCIAL_MUTUAL_KEY       @"DYYYCustomMutual"

// 线程安全的缓存管理
@interface DYYYSocialStatsCache : NSObject
+ (instancetype)shared;
@property (atomic, strong) NSNumber *followers;
@property (atomic, strong) NSNumber *likes;
@property (atomic, strong) NSNumber *following;
@property (atomic, strong) NSNumber *mutual;
@property (atomic, assign) BOOL enabled;
@property (atomic, assign) NSTimeInterval lastUpdateTime;
@end

@implementation DYYYSocialStatsCache
+ (instancetype)shared {
    static DYYYSocialStatsCache *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
        [shared loadConfig];
    });
    return shared;
}

- (void)loadConfig {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    _enabled = [defaults boolForKey:DYYY_SOCIAL_STATS_ENABLED_KEY];
    
    _followers = @([defaults integerForKey:DYYY_SOCIAL_FOLLOWERS_KEY]);
    _likes = @([defaults integerForKey:DYYY_SOCIAL_LIKES_KEY]);
    _following = @([defaults integerForKey:DYYY_SOCIAL_FOLLOWING_KEY]);
    _mutual = @([defaults integerForKey:DYYY_SOCIAL_MUTUAL_KEY]);
    
    _lastUpdateTime = 0;
}
@end

// 模型数据更新
static void updateModelData(id model) {
    DYYYSocialStatsCache *cache = [DYYYSocialStatsCache shared];
    if (!cache.enabled || !model) return;
    
    @try {
        // 粉丝
        if (cache.followers) {
            NSArray *followerKeys = @[@"followerCount", @"fansCount", @"fans_count"];
            for (NSString *key in followerKeys) {
                if ([model respondsToSelector:NSSelectorFromString(key)]) {
                    [model setValue:cache.followers forKey:key];
                }
            }
        }
        
        // 获赞
        if (cache.likes) {
            NSArray *likeKeys = @[
                @"totalFavorited", @"favoriteCount", @"diggCount", 
                @"praiseCount", @"likeCount", @"like_count",
                @"total_favorited", @"favorite_count", @"digg_count"
            ];
            for (NSString *key in likeKeys) {
                if ([model respondsToSelector:NSSelectorFromString(key)]) {
                    [model setValue:cache.likes forKey:key];
                }
            }
        }
        
        // 关注
        if (cache.following) {
            NSArray *followingKeys = @[@"followingCount", @"followCount", @"follow_count"];
            for (NSString *key in followingKeys) {
                if ([model respondsToSelector:NSSelectorFromString(key)]) {
                    [model setValue:cache.following forKey:key];
                }
            }
        }
        
        // 互关
        if (cache.mutual) {
            NSArray *mutualKeys = @[
                @"friendCount", @"mutualFriendCount", @"followFriendCount",
                @"mutualCount", @"friend_count", @"mutual_friend_count",
                @"follow_friend_count", @"mutual_count"
            ];
            for (NSString *key in mutualKeys) {
                if ([model respondsToSelector:NSSelectorFromString(key)]) {
                    [model setValue:cache.mutual forKey:key];
                }
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[DYYY] Model update failed: %@", e);
    }
}

#pragma mark - Hook Implementations

%hook AWEUserModel

- (id)init {
    id instance = %orig;
    if ([DYYYSocialStatsCache shared].enabled && instance) {
        updateModelData(instance);
    }
    return instance;
}

// 粉丝数相关
- (NSNumber *)followerCount {
    DYYYSocialStatsCache *cache = [DYYYSocialStatsCache shared];
    return cache.enabled && cache.followers ? cache.followers : %orig;
}

- (void)setFollowerCount:(NSNumber *)count {
    DYYYSocialStatsCache *cache = [DYYYSocialStatsCache shared];
    %orig(cache.enabled && cache.followers ? cache.followers : count);
}

// 关注数相关
- (NSNumber *)followingCount {
    DYYYSocialStatsCache *cache = [DYYYSocialStatsCache shared];
    return cache.enabled && cache.following ? cache.following : %orig;
}

- (void)setFollowingCount:(NSNumber *)count {
    DYYYSocialStatsCache *cache = [DYYYSocialStatsCache shared];
    %orig(cache.enabled && cache.following ? cache.following : count);
}

// 获赞数相关
- (NSNumber *)totalFavorited {
    DYYYSocialStatsCache *cache = [DYYYSocialStatsCache shared];
    return cache.enabled && cache.likes ? cache.likes : %orig;
}

- (void)setTotalFavorited:(NSNumber *)count {
    DYYYSocialStatsCache *cache = [DYYYSocialStatsCache shared];
    %orig(cache.enabled && cache.likes ? cache.likes : count);
}

- (NSNumber *)diggCount {
    DYYYSocialStatsCache *cache = [DYYYSocialStatsCache shared];
    return cache.enabled && cache.likes ? cache.likes : %orig;
}

- (void)setDiggCount:(NSNumber *)count {
    DYYYSocialStatsCache *cache = [DYYYSocialStatsCache shared];
    %orig(cache.enabled && cache.likes ? cache.likes : count);
}

- (NSNumber *)likeCount {
    DYYYSocialStatsCache *cache = [DYYYSocialStatsCache shared];
    return cache.enabled && cache.likes ? cache.likes : %orig;
}

- (void)setLikeCount:(NSNumber *)count {
    DYYYSocialStatsCache *cache = [DYYYSocialStatsCache shared];
    %orig(cache.enabled && cache.likes ? cache.likes : count);
}

// 互关数相关
- (NSNumber *)friendCount {
    DYYYSocialStatsCache *cache = [DYYYSocialStatsCache shared];
    return cache.enabled && cache.mutual ? cache.mutual : %orig;
}

- (void)setFriendCount:(NSNumber *)count {
    DYYYSocialStatsCache *cache = [DYYYSocialStatsCache shared];
    %orig(cache.enabled && cache.mutual ? cache.mutual : count);
}

- (NSNumber *)mutualFriendCount {
    DYYYSocialStatsCache *cache = [DYYYSocialStatsCache shared];
    return cache.enabled && cache.mutual ? cache.mutual : %orig;
}

- (void)setMutualFriendCount:(NSNumber *)count {
    DYYYSocialStatsCache *cache = [DYYYSocialStatsCache shared];
    %orig(cache.enabled && cache.mutual ? cache.mutual : count);
}

- (NSNumber *)followFriendCount {
    DYYYSocialStatsCache *cache = [DYYYSocialStatsCache shared];
    return cache.enabled && cache.mutual ? cache.mutual : %orig;
}

- (void)setFollowFriendCount:(NSNumber *)count {
    DYYYSocialStatsCache *cache = [DYYYSocialStatsCache shared];
    %orig(cache.enabled && cache.mutual ? cache.mutual : count);
}

%end

%hook AWEProfileSocialStatisticView

- (void)setFansCount:(NSNumber *)count {
    DYYYSocialStatsCache *cache = [DYYYSocialStatsCache shared];
    %orig(cache.enabled && cache.followers ? cache.followers : count);
}

- (void)setPraiseCount:(NSNumber *)count {
    DYYYSocialStatsCache *cache = [DYYYSocialStatsCache shared];
    %orig(cache.enabled && cache.likes ? cache.likes : count);
}

- (void)setFollowingCount:(NSNumber *)count {
    DYYYSocialStatsCache *cache = [DYYYSocialStatsCache shared];
    %orig(cache.enabled && cache.following ? cache.following : count);
}

- (void)setFriendCount:(NSNumber *)count {
    DYYYSocialStatsCache *cache = [DYYYSocialStatsCache shared];
    %orig(cache.enabled && cache.mutual ? cache.mutual : count);
}

- (void)p_updateSocialStatisticContent:(BOOL)animated {
    %orig;
    
    DYYYSocialStatsCache *cache = [DYYYSocialStatsCache shared];
    if (!cache.enabled) return;
    
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (now - cache.lastUpdateTime < 0.5) return;
    cache.lastUpdateTime = now;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (cache.followers) [self setFansCount:cache.followers];
            if (cache.likes) [self setPraiseCount:cache.likes];
            if (cache.following) [self setFollowingCount:cache.following];
            if (cache.mutual) [self setFriendCount:cache.mutual];
        } @catch (NSException *e) {
            NSLog(@"[DYYY] Update stats failed: %@", e);
        }
    });
}

- (void)layoutSubviews {
    %orig;
    
    DYYYSocialStatsCache *cache = [DYYYSocialStatsCache shared];
    if (cache.enabled) {
        [self p_updateSocialStatisticContent:YES];
    }
}

%end

%hook NSDictionary

- (id)objectForKey:(id)aKey {
    id originalValue = %orig;
    DYYYSocialStatsCache *cache = [DYYYSocialStatsCache shared];
    
    if (!cache.enabled || !aKey || !originalValue || ![aKey isKindOfClass:[NSString class]]) {
        return originalValue;
    }
    
    NSString *keyString = (NSString *)aKey;
    
    @try {
        // 粉丝
        if (cache.followers && 
            ([keyString isEqualToString:@"follower_count"] ||
             [keyString isEqualToString:@"fans_count"] ||
             [keyString isEqualToString:@"follower"] ||
             [keyString isEqualToString:@"fans"])) {
            return cache.followers;
        }
        
        // 获赞
        if (cache.likes && 
            ([keyString isEqualToString:@"total_favorited"] ||
             [keyString isEqualToString:@"favorite_count"] ||
             [keyString isEqualToString:@"digg_count"] ||
             [keyString isEqualToString:@"like_count"] ||
             [keyString isEqualToString:@"praise_count"])) {
            return cache.likes;
        }
        
        // 关注
        if (cache.following && 
            ([keyString isEqualToString:@"following_count"] ||
             [keyString isEqualToString:@"follow_count"] ||
             [keyString isEqualToString:@"following"] ||
             [keyString isEqualToString:@"follow"])) {
            return cache.following;
        }
        
        // 互关
        if (cache.mutual && 
            ([keyString isEqualToString:@"friend_count"] ||
             [keyString isEqualToString:@"mutual_friend_count"] ||
             [keyString isEqualToString:@"mutual_count"] ||
             [keyString isEqualToString:@"friendship_count"])) {
            return cache.mutual;
        }
    } @catch (NSException *e) {
        NSLog(@"[DYYY] Dictionary hook failed: %@", e);
    }
    
    return originalValue;
}

%end

%ctor {
    // 初始化时自动加载配置
    [DYYYSocialStatsCache shared];
}
