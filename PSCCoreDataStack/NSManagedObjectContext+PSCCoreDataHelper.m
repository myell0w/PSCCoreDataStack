//
//  NSManagedObjectContext+PSCCoreDataHelper.m
//  Companion
//
//  Created by Philip Messlehner on 28.02.13.
//  Copyright (c) 2013 Philip Messlehner. All rights reserved.
//

#import "NSManagedObjectContext+PSCCoreDataHelper.h"
#import "PSCLogging.h"


@implementation NSManagedObjectContext (PSCCoreDataHelper)

- (NSManagedObjectContext *)newChildContextWithConcurrencyType:(NSUInteger)concurrencyType {
    NSManagedObjectContext *childContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:concurrencyType];
    childContext.parentContext = self;

    return childContext;
}

- (void)saveAndPropagateToParentContextBlocking:(BOOL)wait {
    void(^saveContext)(NSManagedObjectContext *) = ^(NSManagedObjectContext *context) {
        NSError *error = nil;
        if (![context save:&error]) {
            PSCCDLog(@"Error saving context: %@", error);
        }
    };

    if (self.hasChanges) {
        if (self.concurrencyType == NSConfinementConcurrencyType) {
            saveContext(self);
        } else {
            [self performBlockAndWait:^{
                saveContext(self);
            }];
        }
    }
    
    if (self.parentContext.hasChanges) {
        if (self.parentContext.concurrencyType == NSConfinementConcurrencyType) {
            saveContext(self.parentContext);
        } else if (wait) {
            [self.parentContext performBlockAndWait:^{
                saveContext(self.parentContext);
            }];
        } else {
            [self.parentContext performBlock:^{
                saveContext(self.parentContext);
            }];
        }
    }
}

- (void)saveAndPropagateToParentContext {
    [self saveAndPropagateToParentContextBlocking:NO];
}

@end
