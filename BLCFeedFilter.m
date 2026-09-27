#import "BLCFeedFilter.h"

NSString *const BLCFeedPromotionKey = @"blc.feed.hide.promotion";
NSString *const BLCFeedMallKey = @"blc.feed.hide.mall";
NSString *const BLCFeedAdBadgeKey = @"blc.feed.hide.ad.badge";
NSString *const BLCFeedWideKey = @"blc.feed.hide.wide";
NSString *const BLCFeedMiniGameKey = @"blc.feed.hide.minigame";

BOOL BLCIsHomeFeedURL(NSString *url) {
    NSString *path = [NSURLComponents componentsWithString:url].path;
    return [path isEqual:@"/x/v2/feed/index"] || [path isEqual:@"/x/v2/feed/index/"];
}

static BOOL BLCLabelMatches(id value, NSString *label, NSUInteger depth) {
    if (depth > 5) return NO;
    if ([value isKindOfClass:NSString.class]) {
        NSString *text = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if ([text isEqual:label]) return YES;
        // The iOS badge can combine labels, e.g. "小游戏 | 广告".
        for (NSString *part in [text componentsSeparatedByCharactersInSet:
                               [NSCharacterSet characterSetWithCharactersInString:@"|｜·•/／"]]) {
            if ([[part stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] isEqual:label]) return YES;
        }
        return NO;
    }
    if ([value isKindOfClass:NSDictionary.class]) {
        // Only text fields inside a label, never a card's title or author.
        for (NSString *key in @[@"text", @"label", @"content", @"badge", @"name", @"description", @"text_v2"]) {
            if (BLCLabelMatches(value[key], label, depth + 1)) return YES;
        }
    } else if ([value isKindOfClass:NSArray.class]) {
        for (id child in value) if (BLCLabelMatches(child, label, depth + 1)) return YES;
    }
    return NO;
}

static BOOL BLCHasCornerLabel(NSDictionary *card, NSString *label) {
    for (NSString *key in @[@"cover_right_text", @"cover_right_text_1", @"cover_right_text_2",
        @"cover_right_content_description", @"cover_right_text_style", @"cover_right_text_1_style",
        @"cover_right_top_text", @"cover_right_top_text_style", @"cover_right_top_badge",
        @"badge", @"badge_style", @"badges", @"ad_tag", @"ad_tag_style", @"ad_label"]) {
        if (BLCLabelMatches(card[key], label, 0)) return YES;
    }
    // Advertising metadata can carry the corner badge separately from the card.
    for (NSString *key in @[@"ad_info", @"adInfo", @"creative_content", @"creativeContent"]) {
        NSDictionary *info = card[key];
        if (![info isKindOfClass:NSDictionary.class]) continue;
        for (NSString *tag in @[@"ad_tag", @"ad_tag_style", @"ad_label", @"badge", @"badge_style"])
            if (BLCLabelMatches(info[tag], label, 0)) return YES;
        NSDictionary *creative = info[@"creative_content"];
        if ([creative isKindOfClass:NSDictionary.class]) {
            for (NSString *tag in @[@"ad_tag", @"ad_tag_style", @"ad_label", @"badge"])
                if (BLCLabelMatches(creative[tag], label, 0)) return YES;
        }
    }
    return NO;
}

BLCFeedKind BLCClassifyFeedCard(NSDictionary *card) {
    if (![card isKindOfClass:NSDictionary.class]) return 0;
    BLCFeedKind kind = 0;
    if (BLCHasCornerLabel(card, @"创作推广")) kind |= BLCFeedPromotion;
    if (BLCHasCornerLabel(card, @"会员购")) kind |= BLCFeedMall;
    if (BLCHasCornerLabel(card, @"小游戏")) kind |= BLCFeedMiniGame;
    for (NSString *key in @[@"card_goto", @"goto", @"card_type"]) {
        NSString *value = [card[key] isKindOfClass:NSString.class] ? [card[key] lowercaseString] : @"";
        if ([value isEqual:@"mini_game"] || [value isEqual:@"minigame"] ||
            [value hasPrefix:@"mini_game_"] || [value hasPrefix:@"minigame_"]) kind |= BLCFeedMiniGame;
    }
    NSString *uri = [card[@"uri"] isKindOfClass:NSString.class] ? card[@"uri"] : nil;
    NSURLComponents *route = uri ? [NSURLComponents componentsWithString:uri] : nil;
    if ([route.scheme.lowercaseString isEqual:@"bilibili"] &&
        ([@[@"mini_game", @"minigame"] containsObject:route.host.lowercaseString] ||
         [route.path containsString:@"/mini_game"] || [route.path containsString:@"/minigame"])) kind |= BLCFeedMiniGame;
    if (!(kind & BLCFeedMiniGame) && BLCHasCornerLabel(card, @"广告")) kind |= BLCFeedAdBadge;
    NSString *type = [card[@"card_type"] isKindOfClass:NSString.class] ? [card[@"card_type"] lowercaseString] : @"";
    // Some ad cards let the client draw its own badge from ad_info, without
    // returning the literal text. Keep named promotion/mall categories separate.
    if (!(kind & (BLCFeedPromotion | BLCFeedMall | BLCFeedMiniGame))) {
        id info = card[@"ad_info"] ?: card[@"adInfo"];
        if ([type hasPrefix:@"cm_"] && [info isKindOfClass:NSDictionary.class] && [info count] > 0) {
            kind |= BLCFeedAdBadge;
        }
    }
    // "cm_double" means a card in the two-column grid, not a full-width card.
    for (NSString *prefix in @[@"large_cover", @"cm_single", @"banner_v", @"banner_ipad", @"full_cover"]) {
        if ([type hasPrefix:prefix]) kind |= BLCFeedWide;
    }
    if ([type isEqual:@"cm_v1"] || [type isEqual:@"cm_v2"]) kind |= BLCFeedWide;
    for (NSString *key in @[@"column_span", @"col_span", @"span_size"]) {
        id span = card[key];
        if ([span respondsToSelector:@selector(integerValue)] && [span integerValue] == 2) kind |= BLCFeedWide;
    }
    return kind;
}

BOOL BLCShouldHideFeedCard(NSDictionary *card, NSUserDefaults *defaults) {
    id master = [defaults objectForKey:@"blc.master.enabled"];
    if (master && ![master boolValue]) return NO;
    BLCFeedKind kind = BLCClassifyFeedCard(card);
    NSArray *keys = @[BLCFeedPromotionKey, BLCFeedMallKey, BLCFeedAdBadgeKey, BLCFeedWideKey, BLCFeedMiniGameKey];
    for (NSUInteger i = 0; i < keys.count; i++) {
        id value = [defaults objectForKey:keys[i]];
        if ((kind & (1 << i)) && (!value || [value boolValue])) return YES;
    }
    return NO;
}
