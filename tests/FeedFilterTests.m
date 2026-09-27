#import "BLCFeedFilter.h"
#import "BLCTabManager.h"
#import <objc/runtime.h>

// In-memory preferences avoid touching the user's settings during tests.
@interface TestDefaults : NSUserDefaults
@property(nonatomic, strong) NSMutableDictionary *values;
@end
@implementation TestDefaults
- (id)objectForKey:(NSString *)key { return self.values[key]; }
- (void)setObject:(id)value forKey:(NSString *)key { self.values[key] = value; }
- (void)setBool:(BOOL)value forKey:(NSString *)key { self.values[key] = @(value); }
- (NSArray *)arrayForKey:(NSString *)key { return self.values[key]; }
- (void)registerDefaults:(NSDictionary *)defaults {
    for (NSString *key in defaults) if (!self.values[key]) self.values[key] = defaults[key];
}
- (BOOL)synchronize { return YES; }
@end
static TestDefaults *defaults;
@interface TestTabModel : NSObject
@property(nonatomic, copy) NSString *name;
@property(nonatomic, copy) NSString *title;
@property(nonatomic, copy) NSString *tab_id;
@property(nonatomic, copy) NSString *uri;
@end
@implementation TestTabModel
@end
static NSUserDefaults *TestStandardDefaults(id self, SEL selector) { return defaults; }
static void Check(BOOL value, NSString *message) { if (!value) { NSLog(@"FAIL: %@", message); exit(1); } }

static NSMutableDictionary *Tabs(void) {
    NSDictionary *root = @{@"code": @0, @"data": @{
        @"tab": @[@{@"name": @"会员购", @"tab_id": @"top-mall"}],
        @"bottom": @[@{@"name": @"首页", @"tab_id": @"home"},
                      @{@"name": @"会员购", @"tab_id": @"会员购Bottom"},
                      @{@"name": @"我的", @"tab_id": @"mine"}]}};
    return [NSJSONSerialization JSONObjectWithData:[NSJSONSerialization dataWithJSONObject:root options:0 error:nil]
        options:NSJSONReadingMutableContainers error:nil];
}

int main(void) {
    @autoreleasepool {
        defaults = [TestDefaults new]; defaults.values = [NSMutableDictionary dictionary];
        NSArray *keys = @[BLCFeedPromotionKey, BLCFeedMallKey, BLCFeedAdBadgeKey, BLCFeedWideKey, BLCFeedMiniGameKey];
        NSArray *cards = @[
            @{@"card_type": @"small_cover_v2", @"cover_right_text": @"创作推广"},
            @{@"cover_right_content_description": @"会员购"},
            @{@"ad_info": @{@"creative_content": @{@"ad_tag_style": @{@"text": @"广告"}}}},
            @{@"card_type": @"large_cover_v9", @"goto": @"live"},
            @{@"card_type": @"cm_double_v9", @"cover_right_text": @"小游戏 | 广告", @"ad_info": @{@"creative_id": @1}}];
        for (NSUInteger i = 0; i < cards.count; i++) {
            [defaults.values removeAllObjects];
            Check(BLCShouldHideFeedCard(cards[i], defaults), @"new filters default on");
            [defaults setBool:NO forKey:keys[i]];
            Check(!BLCShouldHideFeedCard(cards[i], defaults), @"corresponding switch off retains card");
            for (NSString *key in keys) [defaults setBool:NO forKey:key];
            [defaults setBool:YES forKey:keys[i]];
            Check(BLCShouldHideFeedCard(cards[i], defaults), @"independent enable");
            [defaults setBool:NO forKey:@"blc.master.enabled"];
            Check(!BLCShouldHideFeedCard(cards[i], defaults), @"master overrides every filter");
        }
        [defaults.values removeAllObjects];
        Check(BLCClassifyFeedCard(@{@"title": @"广告创作推广会员购评测", @"card_type": @"small_cover_v2"}) == 0,
              @"titles do not trigger corner-label filters");
        Check(!(BLCClassifyFeedCard(@{@"card_type": @"cm_double_v9"}) & BLCFeedWide), @"two-column grid card is not full width");
        Check(BLCClassifyFeedCard(@{@"card_type": @"cm_single_v1"}) & BLCFeedWide, @"single large ad spans both columns");
        Check(BLCClassifyFeedCard(@{@"card_type": @"cm_v2"}) & BLCFeedWide, @"legacy full-width ad supported");
        Check(BLCClassifyFeedCard(@{@"card_type": @"large_cover_single_v9"}) & BLCFeedWide, @"9.12.0 large card type supported");
        Check(BLCClassifyFeedCard(@{@"uri": @"bilibili://game_center/mini_game_home"}) == BLCFeedMiniGame, @"native mini-game route");
        Check(BLCClassifyFeedCard(@{@"title": @"小游戏广告评测", @"uri": @"bilibili://video/123"}) == 0, @"ordinary game videos retained");
        Check(BLCClassifyFeedCard(@{@"column_span": @2}) & BLCFeedWide, @"explicit column span supported");
        Check(BLCClassifyFeedCard(@{@"card_type": NSNull.null, @"badge": NSNull.null, @"span_size": NSNull.null}) == 0,
              @"malformed metadata is harmless");
        NSDictionary *both = @{@"cover_right_text": @"会员购", @"card_type": @"large_cover_v1"};
        [defaults setBool:NO forKey:BLCFeedMallKey];
        Check(BLCShouldHideFeedCard(both, defaults), @"wide filter still applies to mall wide card");
        [defaults setBool:NO forKey:BLCFeedWideKey];
        Check(!BLCShouldHideFeedCard(both, defaults), @"disabling both restores overlapping category");
        NSDictionary *ad = @{@"card_type": @"cm_double_v9", @"ad_info": @{@"creative_id": @1}};
        Check(BLCClassifyFeedCard(ad) == BLCFeedAdBadge, @"client-rendered ad badge identified");
        Check(BLCIsHomeFeedURL(@"https://app.bilibili.com/x/v2/feed/index?pn=2"), @"query parameters supported");
        Check(!BLCIsHomeFeedURL(@"https://app.bilibili.com/x/v2/feed/index/story"), @"story endpoint not filtered as home");

        Method method = class_getClassMethod(NSUserDefaults.class, @selector(standardUserDefaults));
        IMP original = method_setImplementation(method, (IMP)TestStandardDefaults);
        [defaults.values removeAllObjects];
        [BLCTabManager registerDefaults];
        BLCTabManager *manager = [BLCTabManager new];
        NSMutableDictionary *tabs = Tabs();
        [manager captureAndFilterResponseDictionary:tabs URLString:@"https://app.bilibili.com/x/resource/show/tab/v2"];
        Check([tabs[@"data"][@"bottom"] count] == 2, @"mall tab hidden by default");
        Check([tabs[@"data"][@"tab"] count] == 1, @"only bottom tab affected");
        Check(![manager isTabVisible:@"会员购Bottom"], @"TAB selector agrees with switch");
        [manager setTabID:@"会员购Bottom" visible:YES];
        tabs = Tabs();
        [manager captureAndFilterResponseDictionary:tabs URLString:@"https://app.bilibili.com/x/resource/show/tab/v2"];
        Check(!manager.hideMallTab && [tabs[@"data"][@"bottom"] count] == 3, @"TAB selector can restore mall");
        [manager setHideMallTab:YES];
        [defaults setBool:NO forKey:@"blc.master.enabled"];
        tabs = Tabs();
        [manager captureAndFilterResponseDictionary:tabs URLString:@"https://app.bilibili.com/x/resource/show/tab/v2"];
        Check([tabs[@"data"][@"bottom"] count] == 3, @"master off preserves all tabs");
        [defaults setBool:YES forKey:@"blc.master.enabled"];
        TestTabModel *mall = [TestTabModel new]; mall.tab_id = @"会员购Bottom";
        TestTabModel *view = [TestTabModel new]; view.title = @"会员购";
        TestTabModel *route = [TestTabModel new]; route.uri = @"bilibili://mall/home";
        TestTabModel *mine = [TestTabModel new]; mine.name = @"我的";
        NSArray *cached = @[mall, view, route, mine];
        Check([[manager filteredBottomItems:cached] isEqual:@[mine]], @"cached models and tab views filtered consistently");
        Check(cached.count == 4, @"cached input is not mutated");
        [manager setHideMallTab:NO];
        Check([manager filteredBottomItems:cached] == cached, @"switch off restores native cached tab list");
        Check([manager filteredBottomItems:@{@"unrecognized": @1}] != nil, @"unknown input passed through");
        method_setImplementation(method, original);
        NSLog(@"PASS: independent feed filters, overlap, false positives and mall TAB controls");
    }
    return 0;
}
