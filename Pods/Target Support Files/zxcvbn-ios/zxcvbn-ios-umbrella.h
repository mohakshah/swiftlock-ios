#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "DBMatcher.h"
#import "DBPasswordStrengthMeterView.h"
#import "DBScorer.h"
#import "DBZxcvbn.h"

FOUNDATION_EXPORT double zxcvbn_iosVersionNumber;
FOUNDATION_EXPORT const unsigned char zxcvbn_iosVersionString[];

