// Run on macOS without an iOS SDK. No network calls or device required.
#import "BLCCDNManager.h"

@interface TestPlayeruniteV1PlayViewUniteReply : NSObject
@property (nonatomic, strong) NSDictionary *vodInfo;
@end
@implementation TestPlayeruniteV1PlayViewUniteReply
@end

@interface BLCCDNManager (ProbeTests)
- (NSArray<NSURL *> *)probeURLsForHost:(NSString *)host;
@end

@interface SampleTestManager : BLCCDNManager
@property (nonatomic) BOOL replacementEnabled;
@property (nonatomic) BOOL fetchedAnonymousSample;
@property (nonatomic, copy) NSString *probedURL;
@property (nonatomic, strong) dispatch_semaphore_t done;
@end
@implementation SampleTestManager
- (BOOL)isEnabled { return self.replacementEnabled; }
- (NSArray *)selectedHosts { return @[@"replacement.example"]; }
- (void)probeNextCandidateWithToken:(NSUUID *)token {
    self.probedURL = [self valueForKey:@"workingSampleURL"];
    dispatch_semaphore_signal(self.done);
}
- (void)fetchSampleURLForBVID:(NSString *)bvid token:(NSUUID *)token {
    self.fetchedAnonymousSample = YES;
    dispatch_semaphore_signal(self.done);
}
@end

static void Check(BOOL condition, NSString *message) {
    if (!condition) { NSLog(@"FAIL: %@", message); exit(1); }
}

static SampleTestManager *Manager(void) {
    SampleTestManager *manager = [SampleTestManager new];
    manager.done = dispatch_semaphore_create(0);
    return manager;
}

static TestPlayeruniteV1PlayViewUniteReply *Reply(NSString *URL) {
    TestPlayeruniteV1PlayViewUniteReply *reply = [TestPlayeruniteV1PlayViewUniteReply new];
    reply.vodInfo = @{@"streamListArray": @[@{@"dashVideo":
        [@{@"baseURL": URL, @"backupURLArray": @[@"https://replacement.example/other.m4s?token=backup%2Fsignature"]} mutableCopy]}]};
    return reply;
}

static void Run(SampleTestManager *manager) {
    [manager startSpeedTestWithProgress:nil completion:nil];
    Check(dispatch_semaphore_wait(manager.done, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC)) == 0,
          @"sample selection completed");
}

int main(void) {
    @autoreleasepool {
        NSString *url = @"https://original.example/video.m4s?token=a%2Fb&x=1&x=2";
        SampleTestManager *disabled = Manager();
        [disabled rewritePlayViewReply:Reply(url)];
        Run(disabled);
        Check([disabled.probedURL isEqual:url] && !disabled.fetchedAnonymousSample,
              @"normal playback bypasses anonymous API even when CDN replacement is disabled");

        SampleTestManager *enabled = Manager();
        enabled.replacementEnabled = YES;
        TestPlayeruniteV1PlayViewUniteReply *reply = Reply(url);
        [enabled rewritePlayViewReply:reply];
        Check([reply.vodInfo[@"streamListArray"][0][@"dashVideo"][@"baseURL"] containsString:@"replacement.example"],
              @"playback replacement still works");
        [enabled rewritePlayViewReply:reply];
        Run(enabled);
        Check([enabled.probedURL isEqual:url], @"repeated hooks preserve original signed URL byte for byte");

        SampleTestManager *expired = Manager();
        [expired rewritePlayViewReply:Reply(@"https://original.example/v?deadline=1")];
        Run(expired);
        Check(expired.fetchedAnonymousSample, @"expired signature is not reused");

        SampleTestManager *aged = Manager();
        [aged rewritePlayViewReply:Reply(url)];
        dispatch_queue_t queue = [aged valueForKey:@"queue"];
        dispatch_sync(queue, ^{ [aged setValue:[NSDate distantPast] forKey:@"recentSampleExpiry"]; });
        [aged rewritePlayViewReply:Reply(@"file:///tmp/video")];
        Run(aged);
        Check(aged.fetchedAnonymousSample, @"aged or non-HTTP samples fall back to BV lookup");

        SampleTestManager *bounded = Manager();
        NSString *deadlineURL = [NSString stringWithFormat:@"https://original.example/v?deadline=%.0f",
                                 NSDate.date.timeIntervalSince1970 + 120];
        [bounded rewritePlayViewReply:Reply(deadlineURL)];
        Run(bounded);
        NSDate *expiry = [bounded valueForKey:@"recentSampleExpiry"];
        Check(expiry.timeIntervalSinceNow > 85 && expiry.timeIntervalSinceNow <= 91,
              @"signature deadline limits cache lifetime with a 30 second margin");
        NSDictionary *native = [enabled valueForKey:@"workingSampleURLs"];
        Check([native[@"original.example"] isEqual:url], @"original URL preserved");
        Check([native[@"replacement.example"] isEqual:@"https://replacement.example/other.m4s?token=backup%2Fsignature"],
              @"backup uses its own path and signature");
        for (NSDictionary *candidate in enabled.candidates) {
            NSArray<NSURL *> *URLs = [enabled probeURLsForHost:candidate[@"host"]];
            Check(URLs.count > 0, @"every candidate receives an actual probe, including unoffered hosts");
            for (NSURL *URL in URLs) Check([URL.host isEqual:candidate[@"host"]], @"probe remains on candidate host");
        }
        Check([[[enabled probeURLsForHost:@"replacement.example"] firstObject].absoluteString isEqual:native[@"replacement.example"]],
              @"native backup is tried before substituted samples");
        Check([[[enabled probeURLsForHost:@"unoffered.example"] firstObject].absoluteString isEqual:@"https://unoffered.example/video.m4s?token=a%2Fb&x=1&x=2"],
              @"full candidate test preserves signed path and query bytes");
        NSDictionary *rewritten = reply.vodInfo[@"streamListArray"][0][@"dashVideo"];
        Check([rewritten[@"baseURL"] isEqual:native[@"replacement.example"]], @"playback promotes exact native backup");
        Check([rewritten[@"backupURLArray"] containsObject:url], @"playback retains original fallback");
        Check([[enabled.candidates valueForKey:@"host"] containsObject:@"original.example"], @"native host appears in candidate list");
        NSLog(@"PASS: CDN sample selection regression tests");
    }
    return 0;
}
