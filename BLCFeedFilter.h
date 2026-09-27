#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString *const BLCFeedPromotionKey;
FOUNDATION_EXPORT NSString *const BLCFeedMallKey;
FOUNDATION_EXPORT NSString *const BLCFeedAdBadgeKey;
FOUNDATION_EXPORT NSString *const BLCFeedWideKey;
FOUNDATION_EXPORT NSString *const BLCFeedMiniGameKey;

typedef NS_OPTIONS(NSUInteger, BLCFeedKind) {
    BLCFeedPromotion = 1 << 0,
    BLCFeedMall = 1 << 1,
    BLCFeedAdBadge = 1 << 2,
    BLCFeedWide = 1 << 3,
    BLCFeedMiniGame = 1 << 4,
};

FOUNDATION_EXPORT BOOL BLCIsHomeFeedURL(NSString *url);
FOUNDATION_EXPORT BLCFeedKind BLCClassifyFeedCard(NSDictionary *card);
FOUNDATION_EXPORT BOOL BLCShouldHideFeedCard(NSDictionary *card, NSUserDefaults *defaults);
