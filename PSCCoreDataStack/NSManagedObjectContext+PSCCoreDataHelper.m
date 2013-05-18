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

- (BOOL)saveAndPropagateToParentContextBlocking:(BOOL)wait error:(__autoreleasing NSError **)error {
    __block BOOL success = NO;

    if (self.hasChanges) {
        if (self.concurrencyType == NSConfinementConcurrencyType) {
            success = [self save:error];
        } else {
            [self performBlockAndWait:^{
                success = [self save:error];
            }];
        }
    }
    
    if (!success) {
        return NO;
    }
    
    if (self.parentContext.hasChanges) {
        dispatch_block_t saveParent = ^{
            success = [self.parentContext save:error];
        };
        
        if (self.parentContext.concurrencyType == NSConfinementConcurrencyType) {
            saveParent();
        } else if (wait) {
            [self.parentContext performBlockAndWait:saveParent];
        } else {
            success = YES;
            [self.parentContext performBlock:^{
                // This get's executed asynchronously, so we don't use the error parameter or the success variable to not crash
                NSError *saveError = nil;
                if (![self.parentContext save:&saveError]) {
                    PSCCDLog(@"Error persisting parent context: %@", saveError);
                }
            }];
        }
    }

    return success;
}

- (BOOL)saveAndPropagateToParentContext:(__autoreleasing NSError **)error {
    return [self saveAndPropagateToParentContextBlocking:NO error:error];
}

@end
