#import "BLCCDNSpeedProbe.h"

static NSMutableArray<NSURLRequest *> *requests;
static void Check(BOOL ok, NSString *message) {
    if (!ok) { NSLog(@"FAIL: %@", message); exit(1); }
}

@interface MockCDN : NSURLProtocol
@end
@implementation MockCDN
+ (BOOL)canInitWithRequest:(NSURLRequest *)request { return YES; }
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request { return request; }
- (void)startLoading {
    @synchronized (requests) { [requests addObject:self.request]; }
    NSString *path = self.request.URL.path;
    BOOL web = [[self.request valueForHTTPHeaderField:@"User-Agent"] hasPrefix:@"Mozilla"];
    NSInteger status = [path isEqual:@"/deny"] || ([path isEqual:@"/web"] && !web) ? 403 : 206;
    NSString *type = [path isEqual:@"/html"] ? @"text/html" : @"video/mp4";
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL statusCode:status
        HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type": type}];
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    if (status == 206) [self.client URLProtocol:self didLoadData:[NSMutableData dataWithLength:65536]];
    [self.client URLProtocolDidFinishLoading:self];
}
- (void)stopLoading {}
@end

@interface MockProbe : BLCCDNSpeedProbe
@end
@implementation MockProbe
- (NSURLSessionConfiguration *)sessionConfiguration {
    NSURLSessionConfiguration *config = NSURLSessionConfiguration.ephemeralSessionConfiguration;
    config.protocolClasses = @[MockCDN.class];
    return config;
}
@end

static void Run(NSArray<NSString *> *paths, NSUInteger count, NSInteger errorCode) {
    requests = [NSMutableArray array];
    NSMutableArray *URLs = [NSMutableArray array];
    for (NSString *path in paths) [URLs addObject:[NSURL URLWithString:[@"https://cdn.invalid" stringByAppendingString:path]]];
    MockProbe *probe = [MockProbe new];
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    __block NSNumber *speed;
    __block NSError *failure;
    __block NSInteger completions = 0;
    [probe startWithURLs:URLs completion:^(NSNumber *value, NSError *error) {
        speed = value; failure = error; completions++;
        dispatch_semaphore_signal(done);
    }];
    Check(dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) == 0, @"probe completed");
    Check(completions == 1, @"one completion despite cancelled retry tasks");
    Check(requests.count == count, @"bounded request count");
    Check(failure.code == errorCode, @"expected result");
    Check(errorCode ? speed == nil : speed.doubleValue > 0, @"only media transfers receive speeds");
    for (NSURLRequest *request in requests) {
        Check([[request valueForHTTPHeaderField:@"Range"] isEqual:@"bytes=0-2097151"], @"bounded media download");
        Check([request.URL.host isEqual:@"cdn.invalid"], @"all attempts target requested CDN");
    }
}

int main(void) {
    @autoreleasepool {
        Run(@[@"/ok"], 1, 0);
        Run(@[@"/web"], 2, 0);
        Check([requests[0] valueForHTTPHeaderField:@"Referer"] == nil, @"App sample uses App headers first");
        Check([requests[1] valueForHTTPHeaderField:@"Referer"] != nil, @"403 retries web headers");
        Run(@[@"/deny", @"/ok"], 3, 0);
        Run(@[@"/deny", @"/deny"], 4, 403);
        Run(@[@"/html"], 1, -4);
        NSLog(@"PASS: CDN probe retries, media validation and failure reporting");
    }
    return 0;
}
