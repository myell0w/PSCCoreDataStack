//
//  PSCCoreDataHelper.m
//  Companion
//
//  Created by Philip Messlehner on 28.02.13.
//  Copyright (c) 2013 Philip Messlehner. All rights reserved.
//

#import "PSCCoreDataStack.h"
#import "PSCLogging.h"


static NSManagedObjectContext *psc_mainContext = nil;
static NSManagedObjectContext *psc_privateContext = nil;
static NSURL *psc_storeDirectoryURL = nil;
static NSPersistentStore *psc_defaultStore = nil;


@implementation PSCCoreDataStack

////////////////////////////////////////////////////////////////////////
#pragma mark - Setup
////////////////////////////////////////////////////////////////////////

+ (void)setupWithModelURL:(NSURL *)modelURL
            storeFileName:(NSString *)storeFileName
                     type:(NSString *)storeType
            configuration:(NSString *)configuration
                  options:(NSDictionary *)options
                  success:(void(^)())successBlock
                    error:(void(^)(NSError *error, NSURL *URL))errorBlock {

    NSParameterAssert(modelURL != nil);
    NSParameterAssert([storeType isEqualToString:NSSQLiteStoreType] || [storeType isEqualToString:NSBinaryStoreType] || [storeType isEqualToString:NSInMemoryStoreType]);
    if (![storeType isEqualToString:NSInMemoryStoreType]) {
        NSParameterAssert(storeFileName != nil);
    }

    NSManagedObjectModel *model = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    NSAssert(model != nil, @"Failed to initialize model with URL: %@", modelURL);

    NSPersistentStoreCoordinator *persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
    NSAssert(persistentStoreCoordinator != nil, @"Failed to initialize persistent store coordinator with model: %@", model);

    psc_privateContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    psc_privateContext.persistentStoreCoordinator = persistentStoreCoordinator;

    psc_mainContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    psc_mainContext.parentContext = psc_privateContext;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        psc_defaultStore = [self addPersistentStoreWithFileName:storeFileName
                                                                   type:storeType
                                                          configuration:configuration
                                                                options:options
                                                                  error:&error];

        if (psc_defaultStore == nil) {
            PSCCDLog(@"Error adding persistent store to coordinator %@\n%@", [error localizedDescription], [error userInfo]);

            if (errorBlock != nil) {
                NSURL *storeURL = [self storeURLWithFileName:storeFileName];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    errorBlock(error, storeURL);
                });
            }
        } else {
            if (successBlock != nil) {
                dispatch_async(dispatch_get_main_queue(),successBlock);
            }
        }
    });
}

+ (void)setupWithModelURL:(NSURL *)modelURL autoMigratedSQLiteStoreFileName:(NSString *)storeFileName success:(void(^)())successBlock error:(void(^)(NSError *error, NSURL *URL))errorBlock {
    NSDictionary *options = @{NSMigratePersistentStoresAutomaticallyOption: @(YES), NSInferMappingModelAutomaticallyOption: @(YES)};

    [self setupWithModelURL:modelURL
              storeFileName:storeFileName
                       type:NSSQLiteStoreType
              configuration:nil
                    options:options
                    success:successBlock
                      error:errorBlock];
}

+ (NSPersistentStore *)addPersistentStoreWithFileName:(NSString *)storeFileName
                                                 type:(NSString *)storeType
                                        configuration:(NSString *)configuration
                                              options:(NSDictionary *)options
                                                error:(NSError **)error {

    NSURL *storeURL = [self storeURLWithFileName:storeFileName];
    NSPersistentStore *store = [[self persistentStoreCoordinator] addPersistentStoreWithType:storeType
                                                                               configuration:configuration
                                                                                         URL:storeURL
                                                                                     options:options
                                                                                       error:error];

    if (store == nil) {
        PSCCDLog(@"Error adding persistent store to coordinator %@\n%@", [error localizedDescription], [error userInfo]);

    }

    return store;
}

////////////////////////////////////////////////////////////////////////
#pragma mark - Saving
////////////////////////////////////////////////////////////////////////

+ (void)saveAndPersistContextBlocking:(BOOL)wait {
    [[self mainContext] saveAndPropagateToParentContextBlocking:wait];
}

+ (void)saveAndPersistContext {
    [self saveAndPersistContextBlocking:NO];
}

////////////////////////////////////////////////////////////////////////
#pragma mark - Parent-Child-Context for Threading
////////////////////////////////////////////////////////////////////////

+ (NSManagedObjectContext *)mainContext {
    return psc_mainContext;
}

+ (NSManagedObjectContext *)newChildContextWithPrivateQueue {
    return [[self mainContext] newChildContextWithConcurrencyType:NSPrivateQueueConcurrencyType];
}

+ (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    return psc_privateContext.persistentStoreCoordinator;
}

+ (NSPersistentStore *)defaultStore {
    return psc_defaultStore;
}

////////////////////////////////////////////////////////////////////////
#pragma mark - Private
////////////////////////////////////////////////////////////////////////

+ (NSURL *)storeURLWithFileName:(NSString *)fileName {
    if (fileName == nil) {
        return nil;
    } else {
        if (psc_storeDirectoryURL == nil) {
            psc_storeDirectoryURL = [[[NSFileManager new] URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] lastObject];
        }
        
        return [psc_storeDirectoryURL URLByAppendingPathComponent:fileName];
    }
}

@end
