#import "BLCCDNSpeedProbe.h"

static NSUInteger const BLCCDNProbeByteLimit = 2 * 1024 * 1024;
static NSTimeInterval const BLCCDNProbeTimeout = 8.0;

static NSError *BLCCDNSpeedProbeError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:@"com.imlr.biliclean.cdn.probe"
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message ?: @"CDN 测速失败"}];
}

@interface BLCCDNSpeedProbe () <NSURLSessionDataDelegate>
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURLSessionDataTask *task;
@property (nonatomic, copy) BLCCDNSpeedProbeCompletion completion;
@property (nonatomic, assign) NSUInteger receivedBytes;
@property (nonatomic, assign) CFAbsoluteTime startedAt;
@property (nonatomic, assign) NSInteger statusCode;
@property (nonatomic, assign) BOOL finished;
@property (nonatomic, copy) NSArray<NSURL *> *URLs;
@property (nonatomic, assign) NSUInteger attempt;
@end

@implementation BLCCDNSpeedProbe

- (void)startWithURL:(NSURL *)URL completion:(BLCCDNSpeedProbeCompletion)completion {
    [self startWithURLs:@[URL] completion:completion];
}

- (NSURLSessionConfiguration *)sessionConfiguration {
    return [NSURLSessionConfiguration ephemeralSessionConfiguration];
}

- (void)startWithURLs:(NSArray<NSURL *> *)URLs completion:(BLCCDNSpeedProbeCompletion)completion {
    self.completion = completion;
    self.URLs = [URLs subarrayWithRange:NSMakeRange(0, MIN(URLs.count, (NSUInteger)3))];
    if (!self.URLs.count) {
        [self finishWithError:BLCCDNSpeedProbeError(-1, @"无有效测速样本")];
        return;
    }
    NSURLSessionConfiguration *configuration = [self sessionConfiguration];
    configuration.timeoutIntervalForRequest = BLCCDNProbeTimeout;
    configuration.timeoutIntervalForResource = BLCCDNProbeTimeout;
    configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    configuration.URLCache = nil;
    configuration.HTTPCookieStorage = nil;
    configuration.HTTPShouldSetCookies = NO;

    NSOperationQueue *delegateQueue = [[NSOperationQueue alloc] init];
    delegateQueue.maxConcurrentOperationCount = 1;
    self.session = [NSURLSession sessionWithConfiguration:configuration
                                                 delegate:self
                                            delegateQueue:delegateQueue];
    [self startNextAttempt];
}

- (void)startNextAttempt {
    BOOL webHeaders = self.attempt % 2 != 0;
    NSURL *URL = self.URLs[self.attempt / 2];
    self.attempt += 1;
    self.receivedBytes = 0;
    self.statusCode = 0;

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    request.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    request.timeoutInterval = BLCCDNProbeTimeout;
    [request setValue:@"bytes=0-2097151" forHTTPHeaderField:@"Range"];
    if (webHeaders) {
        [request setValue:@"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/126 Safari/537.36"
       forHTTPHeaderField:@"User-Agent"];
        [request setValue:@"https://www.bilibili.com/" forHTTPHeaderField:@"Referer"];
    } else {
        // Match the existing in-app media downloader; web headers remain a
        // bounded fallback for samples obtained from the anonymous web API.
        [request setValue:@"Bilibili/8.76.0 (iPhone; iOS 16.7.12; Scale/3.00)" forHTTPHeaderField:@"User-Agent"];
    }
    [request setValue:@"identity" forHTTPHeaderField:@"Accept-Encoding"];
    [request setValue:@"no-cache" forHTTPHeaderField:@"Cache-Control"];

    self.startedAt = CFAbsoluteTimeGetCurrent();
    self.task = [self.session dataTaskWithRequest:request];
    [self.task resume];
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    if (self.finished || dataTask != self.task) {
        completionHandler(NSURLSessionResponseCancel);
        return;
    }
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        self.statusCode = ((NSHTTPURLResponse *)response).statusCode;
    }
    if (self.statusCode < 200 || self.statusCode >= 300) {
        completionHandler(NSURLSessionResponseCancel);
        if ((self.statusCode == 403 || self.statusCode == 404) && self.attempt < self.URLs.count * 2) {
            [self startNextAttempt];
            return;
        }
        [self finishWithError:BLCCDNSpeedProbeError(
            self.statusCode,
            self.statusCode == 403
                ? @"HTTP 403：节点拒绝所有测速样本，无法测得速度"
                : [NSString stringWithFormat:@"HTTP %ld", (long)self.statusCode]
        )];
        return;
    }
    NSString *mime = response.MIMEType.lowercaseString;
    if ([mime hasPrefix:@"text/"] || [mime containsString:@"json"]) {
        completionHandler(NSURLSessionResponseCancel);
        [self finishWithError:BLCCDNSpeedProbeError(-4, @"节点返回非媒体内容，无法测得速度")];
        return;
    }
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request
 completionHandler:(void (^)(NSURLRequest *))completionHandler {
    if (self.finished || task != self.task) {
        completionHandler(nil);
    } else if (![request.URL.host.lowercaseString isEqual:self.URLs.firstObject.host.lowercaseString]) {
        completionHandler(nil);
        [self finishWithError:BLCCDNSpeedProbeError(-5, @"节点跳转至其他 CDN，无法归属测速结果")];
    } else {
        completionHandler(request);
    }
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
    if (self.finished || dataTask != self.task) {
        return;
    }
    self.receivedBytes += data.length;
    if (self.receivedBytes >= BLCCDNProbeByteLimit) {
        [self finishWithError:nil];
        [dataTask cancel];
    }
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
    if (self.finished || task != self.task) {
        return;
    }
    if (self.receivedBytes >= 64 * 1024 &&
        self.statusCode >= 200 &&
        self.statusCode < 300) {
        [self finishWithError:nil];
        return;
    }
    [self finishWithError:error ?: BLCCDNSpeedProbeError(-3, @"未收到足够的媒体数据")];
}

- (void)finishWithError:(NSError *)error {
    if (self.finished) {
        return;
    }
    self.finished = YES;
    NSTimeInterval elapsed = MAX(CFAbsoluteTimeGetCurrent() - self.startedAt, 0.001);
    NSNumber *speed = nil;
    if (!error && self.receivedBytes > 0) {
        speed = @((double)self.receivedBytes / elapsed / 1000000.0);
    }
    BLCCDNSpeedProbeCompletion completion = self.completion;
    self.completion = nil;
    [self.session invalidateAndCancel];
    if (completion) {
        completion(speed, error);
    }
}

- (void)cancel {
    if (self.finished) {
        return;
    }
    [self.task cancel];
    [self finishWithError:BLCCDNSpeedProbeError(NSURLErrorCancelled, @"测速已取消")];
}

@end
