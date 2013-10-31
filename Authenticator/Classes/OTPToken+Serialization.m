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
#import "NSData+Base32.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundef"
#pragma clang diagnostic ignored "-Wauto-import"
#import <GTMNSString+URLArguments.h>
#import <GTMNSDictionary+URLArguments.h>
#import <GTMNSScanner+Unsigned.h>
#pragma clang diagnostic pop


static NSString *const kOTPAuthScheme = @"otpauth";
static NSString *const kTOTPAuthScheme = @"totp";
static NSString *const kQueryAlgorithmKey = @"algorithm";
static NSString *const kQuerySecretKey = @"secret";
static NSString *const kQueryCounterKey = @"counter";
static NSString *const kQueryDigitsKey = @"digits";
static NSString *const kQueryPeriodKey = @"period";


@implementation OTPToken (Serialization)

+ (instancetype)tokenWithURL:(NSURL *)url
                        secret:(NSData *)secret {
    OTPToken *token = nil;
    NSString *urlScheme = [url scheme];
    if ([urlScheme isEqualToString:kTOTPAuthScheme]) {
        // Convert totp:// into otpauth://
// TODO:        authURL = [[TOTPAuthURL alloc] initWithTOTPURL:url];
    } else if (![urlScheme isEqualToString:kOTPAuthScheme]) {
        // Required (otpauth://)
        _GTMDevLog(@"invalid scheme: %@", [url scheme]);
    } else {
        NSString *path = [url path];
        if ([path length] > 1) {
            token = [[OTPToken alloc] init];
            // Optional UTF-8 encoded human readable description (skip leading "/")
            NSString *name = [[url path] substringFromIndex:1];

            NSDictionary *query =
            [NSDictionary gtm_dictionaryWithHttpArgumentsString:[url query]];

            // Optional algorithm=(SHA1|SHA256|SHA512|MD5) defaults to SHA1
            NSString *algorithm = [query objectForKey:kQueryAlgorithmKey];
            if (!algorithm) {
                algorithm = [NSString stringForAlgorithm:[OTPToken defaultAlgorithm]];
            }
            if (!secret) {
                // Required secret=Base32EncodedKey
                NSString *secretString = [query objectForKey:kQuerySecretKey];
                secret = [secretString base32DecodedData];
            }
            // Optional digits=[68] defaults to 8
            NSString *digitString = [query objectForKey:kQueryDigitsKey];
            NSUInteger digits = 0;
            if (!digitString) {
                digits = [OTPToken defaultDigits];
            } else {
                digits = [digitString intValue];
            }

            token.name = name;
            token.secret = secret;
            token.algorithm = [algorithm algorithmValue];
            token.digits = digits;

            NSString *type = [url host];
            if ([type isEqualToString:@"hotp"]) {
                token.type = OTPTokenTypeCounter;

                NSString *counterString = [query objectForKey:kQueryCounterKey];
                if ([self isValidCounter:counterString]) {
                    NSScanner *scanner = [NSScanner scannerWithString:counterString];
                    uint64_t counter;
                    BOOL goodScan = [scanner gtm_scanUnsignedLongLong:&counter];
                    // Good scan should always be good based on the isValidCounter check above.
                    NSAssert(goodScan, @"goodscan should be true: %c", goodScan);

                    token.counter = counter;
                } else {
                    _GTMDevLog(@"invalid counter: %@", counterString);
                    token = nil;
                }
            } else if ([type isEqualToString:@"totp"]) {
                token.type = OTPTokenTypeTimer;

                NSString *periodString = [query objectForKey:kQueryPeriodKey];
                NSTimeInterval period = 0;
                if (periodString) {
                    period = [periodString doubleValue];
                } else {
                    period = [OTPToken defaultPeriod];
                }
                
                token.period = period;
            }
        }
    }

    return token;
}

+ (BOOL)isValidCounter:(NSString *)counter {
    NSCharacterSet *nonDigits =
    [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    NSRange pos = [counter rangeOfCharacterFromSet:nonDigits];
    return pos.location == NSNotFound;
}


- (NSURL *)url
{
    NSMutableDictionary *query = [NSMutableDictionary dictionary];
    NSString *typeString;

    query[kQueryAlgorithmKey] = [NSString stringForAlgorithm:self.algorithm];
    query[kQueryDigitsKey] = @(self.digits);

    if (self.type == OTPTokenTypeTimer) {
        query[kQueryPeriodKey] = @(self.period);

        typeString = @"totp";
    } else if (self.type == OTPTokenTypeCounter) {
        query[kQueryCounterKey] = @(self.counter);

        typeString = @"hotp";
    }

    return [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@/%@?%@",
                                 kOTPAuthScheme,
                                 typeString,
                                 [self.name gtm_stringByEscapingForURLArgument],
                                 [query gtm_httpArgumentsString]]];
}

@end
