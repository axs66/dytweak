#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "AwemeHeaders.h"
#import "DYYYManager.h"

// 添加完整接口声明
@interface AWEProfileSocialStatisticView : UIView
@property (nonatomic, strong) AWEUserModel *user;
- (void)setFansCount:(NSNumber *)count;
- (void)setPraiseCount:(NSNumber *)count;
- (void)setFollowingCount:(NSNumber *)count;
- (void)setFriendCount:(NSNumber *)count;
- (void)p_updateSocialStatisticContent:(BOOL)animated;
@end

@interface AWEProfileHeaderMyProfileViewController : UIViewController
@property (nonatomic, strong) AWEUserModel *user;
- (void)reloadSettings;
@end

@interface AWEProfileHeaderOtherProfileViewController : UIViewController
@property (nonatomic, strong) AWEUserModel *user;
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
static BOOL isCurrentUserModel(id model);

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

// 检查是否是当前用户模型
static BOOL isCurrentUserModel(id model) {
    if (!model) return NO;
    
    // 获取当前用户ID
    NSString *currentUserID = [[DYYYManager sharedManager] currentUserID];
    if (!currentUserID) return NO;
    
    // 检查模型是否包含uid属性
    if ([model respondsToSelector:@selector(uid)]) {
        NSString *modelUID = [model valueForKey:@"uid"];
        return [modelUID isEqualToString:currentUserID];
    }
    // 检查模型是否包含userId属性
    else if ([model respondsToSelector:@selector(userId)]) {
        NSString *modelUserID = [model valueForKey:@"userId"];
        return [modelUserID isEqualToString:currentUserID];
    }
    
    return NO;
}

// 数据Hook - 核心用户模型
%hook AWEUserModel

- (NSNumber *)followerCount {
    return (socialStatsEnabled && isCurrentUserModel(self) && cachedFollowersNumber) ? cachedFollowersNumber : %orig;
}

- (void)setFollowerCount:(NSNumber *)count {
    if (socialStatsEnabled && isCurrentUserModel(self) && cachedFollowersNumber) {
        %orig(cachedFollowersNumber);
    } else {
        %orig;
    }
}

- (NSNumber *)followingCount {
    return (socialStatsEnabled && isCurrentUserModel(self) && cachedFollowingNumber) ? cachedFollowingNumber : %orig;
}

- (void)setFollowingCount:(NSNumber *)count {
    if (socialStatsEnabled && isCurrentUserModel(self) && cachedFollowingNumber) {
        %orig(cachedFollowingNumber);
    } else {
        %orig;
    }
}

- (NSNumber *)totalFavorited {
    return (socialStatsEnabled && isCurrentUserModel(self) && cachedLikesNumber) ? cachedLikesNumber : %orig;
}

- (void)setTotalFavorited:(NSNumber *)count {
    if (socialStatsEnabled && isCurrentUserModel(self) && cachedLikesNumber) {
        %orig(cachedLikesNumber);
    } else {
        %orig;
    }
}

- (NSNumber *)diggCount {
    return (socialStatsEnabled && isCurrentUserModel(self) && cachedLikesNumber) ? cachedLikesNumber : %orig;
}

- (void)setDiggCount:(NSNumber *)count {
    if (socialStatsEnabled && isCurrentUserModel(self) && cachedLikesNumber) {
        %orig(cachedLikesNumber);
    } else {
        %orig;
    }
}

- (NSNumber *)likeCount {
    return (socialStatsEnabled && isCurrentUserModel(self) && cachedLikesNumber) ? cachedLikesNumber : %orig;
}

- (void)setLikeCount:(NSNumber *)count {
    if (socialStatsEnabled && isCurrentUserModel(self) && cachedLikesNumber) {
        %orig(cachedLikesNumber);
    } else {
        %orig;
    }
}

- (NSNumber *)friendCount {
    return (socialStatsEnabled && isCurrentUserModel(self) && cachedMutualNumber) ? cachedMutualNumber : %orig;
}

- (void)setFriendCount:(NSNumber *)count {
    if (socialStatsEnabled && isCurrentUserModel(self) && cachedMutualNumber) {
        %orig(cachedMutualNumber);
    } else {
        %orig;
    }
}

- (NSNumber *)mutualFriendCount {
    return (socialStatsEnabled && isCurrentUserModel(self) && cachedMutualNumber) ? cachedMutualNumber : %orig;
}

- (void)setMutualFriendCount:(NSNumber *)count {
    if (socialStatsEnabled && isCurrentUserModel(self) && cachedMutualNumber) {
        %orig(cachedMutualNumber);
    } else {
        %orig;
    }
}

- (NSNumber *)followFriendCount {
    return (socialStatsEnabled && isCurrentUserModel(self) && cachedMutualNumber) ? cachedMutualNumber : %orig;
}

- (void)setFollowFriendCount:(NSNumber *)count {
    if (socialStatsEnabled && isCurrentUserModel(self) && cachedMutualNumber) {
        %orig(cachedMutualNumber);
    } else {
        %orig;
    }
}
%end

// 统计视图
%hook AWEProfileSocialStatisticView

- (void)setFansCount:(NSNumber *)count {
    // 确保视图关联的用户是当前用户
    if (socialStatsEnabled && self.user && isCurrentUserModel(self.user) && cachedFollowersNumber) {
        %orig(cachedFollowersNumber);
    } else {
        %orig;
    }
}

- (void)setPraiseCount:(NSNumber *)count {
    if (socialStatsEnabled && self.user && isCurrentUserModel(self.user) && cachedLikesNumber) {
        %orig(cachedLikesNumber);
    } else {
        %orig;
    }
}

- (void)setFollowingCount:(NSNumber *)count {
    if (socialStatsEnabled && self.user && isCurrentUserModel(self.user) && cachedFollowingNumber) {
        %orig(cachedFollowingNumber);
    } else {
        %orig;
    }
}

- (void)setFriendCount:(NSNumber *)count {
    if (socialStatsEnabled && self.user && isCurrentUserModel(self.user) && cachedMutualNumber) {
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
    
    // 只有在当前用户的视图上才应用自定义值
    if (socialStatsEnabled && self.user && isCurrentUserModel(self.user)) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self setFansCount:cachedFollowersNumber];
            [self setPraiseCount:cachedLikesNumber];
            [self setFollowingCount:cachedFollowingNumber];
            [self setFriendCount:cachedMutualNumber];
        });
    }
}

%end

// 个人主页控制器
%hook AWEProfileHeaderMyProfileViewController

- (void)reloadSettings {
    %orig;
    
    // 确保刷新当前用户的数据
    if (socialStatsEnabled && self.user && isCurrentUserModel(self.user)) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            // 强制刷新统计数据
            [self reloadSettings];
        });
    }
}

%end

// 其他用户主页控制器
%hook AWEProfileHeaderOtherProfileViewController

- (void)viewDidLoad {
    %orig;
    
    // 确保其他用户的数据不被修改
    if (socialStatsEnabled && self.user && !isCurrentUserModel(self.user)) {
        // 强制刷新显示真实数据
        [self.user setFollowerCount:%orig(self.user.followerCount)];
        [self.user setFollowingCount:%orig(self.user.followingCount)];
        [self.user setTotalFavorited:%orig(self.user.totalFavorited)];
        [self.user setFriendCount:%orig(self.user.friendCount)];
    }
}

%end

// 配置加载入口
%ctor {
    loadCustomSocialStats();
}
