/***
* 202505292050
* Axs优化
**/

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "AwemeHeaders.h"
#import "DYYYManager.h"

// 添加分类声明，避免编译器报错
@interface AWEUserModel (DYYYSocialStats)
- (BOOL)isCurrentUser;
@end

// 更安全的 override 宏，避免方法重定义
#define DYYY_OVERRIDE_NUMBER_PROPERTY(PROPERTY, SETTER, CACHEKEY) \
static NSNumber * getter_##PROPERTY(_LOGOS_SELF_TYPE_NORMAL AWEUserModel* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) { \
    return @(self.CACHEKEY); \
} \
static void setter_##PROPERTY(_LOGOS_SELF_TYPE_NORMAL AWEUserModel* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, NSNumber * count) { \
    objc_setAssociatedObject(self, @selector(PROPERTY), count, OBJC_ASSOCIATION_RETAIN_NONATOMIC); \
} \
%property (nonatomic, strong) NSNumber * PROPERTY; \
%getter(getter_##PROPERTY) \
%setter(setter_##PROPERTY)

%hook AWEUserModel

DYYY_OVERRIDE_NUMBER_PROPERTY(followerCount, setFollowerCount, cachedFollowersNumber)
DYYY_OVERRIDE_NUMBER_PROPERTY(followingCount, setFollowingCount, cachedFollowingNumber)

%end




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

#define DYYY_SOCIAL_STATS_ENABLED_KEY @"DYYYEnableSocialStatsCustom"
#define DYYY_SOCIAL_FOLLOWERS_KEY @"DYYYCustomFollowers"
#define DYYY_SOCIAL_LIKES_KEY @"DYYYCustomLikes"
#define DYYY_SOCIAL_FOLLOWING_KEY @"DYYYCustomFollowing"
#define DYYY_SOCIAL_MUTUAL_KEY @"DYYYCustomMutual"

static NSString *customFollowersCount = nil;
static NSString *customLikesCount = nil;
static NSString *customFollowingCount = nil;
static NSString *customMutualCount = nil;
static BOOL socialStatsEnabled = NO;

static NSNumber *cachedFollowersNumber = nil;
static NSNumber *cachedLikesNumber = nil;
static NSNumber *cachedFollowingNumber = nil;
static NSNumber *cachedMutualNumber = nil;

static void loadCustomSocialStats(void);
static void updateModelData(id model);

// 加载设置
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

// 仅伪造“我的主页”数据
static void updateModelData(id model) {
    if (!socialStatsEnabled || !model) return;
    if (![model respondsToSelector:@selector(isCurrentUser)] || ![model isCurrentUser]) return;

    if (cachedFollowersNumber) {
        NSArray *followerKeys = @[@"followerCount", @"fansCount", @"fans_count"];
        for (NSString *key in followerKeys) {
            if ([model respondsToSelector:NSSelectorFromString(key)]) {
                [model setValue:cachedFollowersNumber forKey:key];
            }
        }
    }

    if (cachedLikesNumber) {
        NSArray *likeKeys = @[@"totalFavorited", @"favoriteCount", @"diggCount", @"praiseCount", @"likeCount"];
        for (NSString *key in likeKeys) {
            if ([model respondsToSelector:NSSelectorFromString(key)]) {
                [model setValue:cachedLikesNumber forKey:key];
            }
        }
    }

    if (cachedFollowingNumber) {
        NSArray *followKeys = @[@"followingCount", @"followCount"];
        for (NSString *key in followKeys) {
            if ([model respondsToSelector:NSSelectorFromString(key)]) {
                [model setValue:cachedFollowingNumber forKey:key];
            }
        }
    }

    if (cachedMutualNumber) {
        NSArray *mutualKeys = @[@"friendCount", @"mutualFriendCount", @"followFriendCount", @"mutualCount"];
        for (NSString *key in mutualKeys) {
            if ([model respondsToSelector:NSSelectorFromString(key)]) {
                [model setValue:cachedMutualNumber forKey:key];
            }
        }
    }
}

%hook AWEUserModel

- (id)init {
    id instance = %orig;
    if (socialStatsEnabled && instance && [instance respondsToSelector:@selector(isCurrentUser)] && [instance isCurrentUser]) {
        updateModelData(instance);
    }
    return instance;
}

#define DYYY_OVERRIDE_NUMBER_PROPERTY(getter, setter, cached) \
- (NSNumber *)getter { \
    return socialStatsEnabled && [self respondsToSelector:@selector(isCurrentUser)] && [self isCurrentUser] && cached ? cached : %orig; \
} \
- (void)setter:(NSNumber *)count { \
    if (socialStatsEnabled && [self respondsToSelector:@selector(isCurrentUser)] && [self isCurrentUser] && cached) { \
        %orig(cached); \
    } else { \
        %orig; \
    } \
}

DYYY_OVERRIDE_NUMBER_PROPERTY(followerCount, setFollowerCount, cachedFollowersNumber)
DYYY_OVERRIDE_NUMBER_PROPERTY(followingCount, setFollowingCount, cachedFollowingNumber)
DYYY_OVERRIDE_NUMBER_PROPERTY(totalFavorited, setTotalFavorited, cachedLikesNumber)
DYYY_OVERRIDE_NUMBER_PROPERTY(diggCount, setDiggCount, cachedLikesNumber)
DYYY_OVERRIDE_NUMBER_PROPERTY(likeCount, setLikeCount, cachedLikesNumber)
DYYY_OVERRIDE_NUMBER_PROPERTY(friendCount, setFriendCount, cachedMutualNumber)
DYYY_OVERRIDE_NUMBER_PROPERTY(mutualFriendCount, setMutualFriendCount, cachedMutualNumber)
DYYY_OVERRIDE_NUMBER_PROPERTY(followFriendCount, setFollowFriendCount, cachedMutualNumber)

%end

%hook AWEProfileSocialStatisticView
- (void)setFansCount:(NSNumber *)count {
    %orig(socialStatsEnabled && cachedFollowersNumber ? cachedFollowersNumber : count);
}
- (void)setPraiseCount:(NSNumber *)count {
    %orig(socialStatsEnabled && cachedLikesNumber ? cachedLikesNumber : count);
}
- (void)setFollowingCount:(NSNumber *)count {
    %orig(socialStatsEnabled && cachedFollowingNumber ? cachedFollowingNumber : count);
}
- (void)setFriendCount:(NSNumber *)count {
    %orig(socialStatsEnabled && cachedMutualNumber ? cachedMutualNumber : count);
}

- (void)p_updateSocialStatisticContent:(BOOL)animated {
    %orig;
    if (socialStatsEnabled) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (cachedFollowersNumber) [self setFansCount:cachedFollowersNumber];
            if (cachedLikesNumber) [self setPraiseCount:cachedLikesNumber];
            if (cachedFollowingNumber) [self setFollowingCount:cachedFollowingNumber];
            if (cachedMutualNumber) [self setFriendCount:cachedMutualNumber];
        });
    }
}

- (void)layoutSubviews {
    %orig;
    if (socialStatsEnabled) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (cachedFollowersNumber) [self setFansCount:cachedFollowersNumber];
            if (cachedLikesNumber) [self setPraiseCount:cachedLikesNumber];
            if (cachedFollowingNumber) [self setFollowingCount:cachedFollowingNumber];
            if (cachedMutualNumber) [self setFriendCount:cachedMutualNumber];
            [self p_updateSocialStatisticContent:YES];
        });
    }
}
%end

%hook AWEProfileHeaderMyProfileViewController
- (void)viewDidLoad {
    %orig;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadSettings) name:NSUserDefaultsDidChangeNotification object:nil];
}
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    loadCustomSocialStats();
}
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}
%new
- (void)reloadSettings {
    loadCustomSocialStats();
}
%end

%hook NSUserDefaults
- (void)setObject:(id)value forKey:(NSString *)defaultName {
    %orig;
    if ([defaultName hasPrefix:@"DYYYCustom"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            loadCustomSocialStats();
        });
    }
}
%end

%ctor {
    loadCustomSocialStats();
}
