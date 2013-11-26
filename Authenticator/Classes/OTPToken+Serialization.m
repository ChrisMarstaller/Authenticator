//
//  OTPToken+Serialization.m
//  Authenticator
//
//  Copyright (c) 2013 Matt Rubin
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of
//  this software and associated documentation files (the "Software"), to deal in
//  the Software without restriction, including without limitation the rights to
//  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
//  the Software, and to permit persons to whom the Software is furnished to do so,
//  subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
//  FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
//  COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "OTPToken+Serialization.h"
#import "NSString+PercentEncoding.h"
#import "NSDictionary+QueryString.h"
#import "NSData+Base32.h"


static NSString *const kOTPAuthScheme = @"otpauth";
static NSString *const kQueryAlgorithmKey = @"algorithm";
static NSString *const kQuerySecretKey = @"secret";
static NSString *const kQueryCounterKey = @"counter";
static NSString *const kQueryDigitsKey = @"digits";
static NSString *const kQueryPeriodKey = @"period";


@implementation OTPToken (Serialization)

+ (instancetype)tokenWithURL:(NSURL *)url
{
    return [self tokenWithURL:url secret:nil];
}

+ (instancetype)tokenWithURL:(NSURL *)url secret:(NSData *)secret
{
    OTPToken *token = nil;

    if ([url.scheme isEqualToString:kOTPAuthScheme]) {
        // Modern otpauth:// URL
        token = [self tokenWithOTPAuthURL:url];
    }

    if (secret) token.secret = secret;

    return [token validate] ? token : nil;
}

+ (instancetype)tokenWithOTPAuthURL:(NSURL *)url
{
    OTPToken *token = [[OTPToken alloc] init];

    token.type = [url.host tokenTypeValue];
    token.name = (url.path.length > 1) ? [url.path substringFromIndex:1] : nil; // Skip the leading "/"

    NSDictionary *query = [NSDictionary dictionaryWithQueryString:url.query];

    NSString *algorithmString = query[kQueryAlgorithmKey];
    token.algorithm = algorithmString ? [algorithmString algorithmValue] : [OTPToken defaultAlgorithm];

    NSString *secretString = query[kQuerySecretKey];
    token.secret = [NSData dataWithBase32EncodedString:secretString];;

    NSString *digitString = query[kQueryDigitsKey];
    token.digits = digitString ? [digitString integerValue] : [OTPToken defaultDigits];

    NSString *counterString = query[kQueryCounterKey];
    token.counter = counterString ? strtoull([counterString UTF8String], NULL, 10) : [OTPToken defaultInitialCounter];

    NSString *periodString = query[kQueryPeriodKey];
    token.period = periodString ? [periodString doubleValue] : [OTPToken defaultPeriod];

    return token;
}

- (NSURL *)url
{
    NSMutableDictionary *query = [NSMutableDictionary dictionary];

    query[kQueryAlgorithmKey] = [NSString stringForAlgorithm:self.algorithm];
    query[kQueryDigitsKey] = @(self.digits);

    if (self.type == OTPTokenTypeTimer) {
        query[kQueryPeriodKey] = @(self.period);
    } else if (self.type == OTPTokenTypeCounter) {
        query[kQueryCounterKey] = @(self.counter);
    }

    NSURLComponents *urlComponents = [NSURLComponents new];
    urlComponents.scheme = kOTPAuthScheme;
    urlComponents.host = [NSString stringForTokenType:self.type];
    if (self.name)
        urlComponents.path = [@"/" stringByAppendingString:self.name];
    urlComponents.query = [query queryString];

    return urlComponents.URL;
}

@end