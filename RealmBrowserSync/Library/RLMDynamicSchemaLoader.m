//
//  RLMDynamicSchemaLoader.m
//  RealmBrowser
//
//  Created by Dmitry Obukhov on 17/08/16.
//  Copyright © 2016 Realm inc. All rights reserved.
//

@import Realm;
@import Realm.Private;

#import "RLMDynamicSchemaLoader.h"

static NSTimeInterval const schemaLoadTimeout = 5;

NSString * const errorDomain = @"RLMDynamicSchemaLoader";

@interface RLMDynamicSchemaLoader()

@property (nonatomic, strong) RLMRealmConfiguration *configuration;
@property (nonatomic, strong) RLMNotificationToken *notificationToken;
@property (nonatomic, strong) RLMSchemaLoadCompletionHandler completionHandler;

@end

@implementation RLMDynamicSchemaLoader

- (instancetype)initWithSyncURL:(NSURL *)syncURL user:(RLMUser *)user {
    NSAssert(user.isLoggedIn, @"User must be logged in");

    self = [super init];

    if (self != nil) {
        self.configuration = [[RLMRealmConfiguration alloc] init];
        self.configuration.dynamic = YES;

        [self.configuration setObjectServerPath:syncURL.path forUser:user];
    }

    return self;
}

- (void)loadSchemaToURL:(NSURL *)fileURL completionHandler:(RLMSchemaLoadCompletionHandler)handler {
    self.completionHandler = handler;
    self.configuration.fileURL = fileURL;

    NSError *error;

    RLMRealm *realm = [RLMRealm realmWithConfiguration:self.configuration error:&error];

    if (error != nil) {
        [self schemaDidLoadWithError:error];
        return;
    }

    if (realm.schema.objectSchema.count > 0) {
        [self schemaDidLoadWithError:nil];
        return;
    }

    __weak typeof(self) weakSelf = self;
    self.notificationToken = [realm addNotificationBlock:^(RLMNotification notification, RLMRealm *realm) {
        [NSObject cancelPreviousPerformRequestsWithTarget:weakSelf];

        [weakSelf.notificationToken stop];
        [weakSelf schemaDidLoadWithError:nil];
    }];

    [self performSelector:@selector(schemaDidLoadWithError:) withObject:[self errorWithCode:0 description:@"Failed to connect to Object Server." recoverySuggestion:@"Check the URL and that the server is accessible."] afterDelay:schemaLoadTimeout];
}

- (void)schemaDidLoadWithError:(NSError *)error {
    if (self.completionHandler != nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.completionHandler(error);
            self.completionHandler = nil;
        });
    }
}

- (NSError *)errorWithCode:(NSInteger)code description:(NSString *)description recoverySuggestion:(NSString *)recoverySuggestion {
    NSDictionary *userInfo = @{
        NSLocalizedDescriptionKey: description,
        NSLocalizedRecoverySuggestionErrorKey: recoverySuggestion
    };

    return [NSError errorWithDomain:errorDomain code:code userInfo:userInfo];
}

@end
