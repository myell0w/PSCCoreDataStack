//
//  NSManagedObject+PSCCoreDataHelper.m
//  Companion
//
//  Created by Philip Messlehner on 28.02.13.
//  Copyright (c) 2013 Philip Messlehner. All rights reserved.
//

#import "NSManagedObject+PSCCoreDataHelper.h"
#import "PSCContextWatcher.h"
#import "PSCLogging.h"


@implementation NSManagedObject (PSCCoreDataHelper)

////////////////////////////////////////////////////////////////////////
#pragma mark - Class Methods
////////////////////////////////////////////////////////////////////////

+ (instancetype)newObjectInContext:(NSManagedObjectContext *)context {
    NSParameterAssert(context != nil);

    return [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([self class]) inManagedObjectContext:context];
}

+ (instancetype)existingOrNewObjectWithAttribute:(NSString *)attribute matchingValue:(id)value inContext:(NSManagedObjectContext *)context {
    return [self existingOrNewObjectWithAttribute:attribute matchingValue:value inContext:context store:nil];
}

+ (instancetype)existingOrNewObjectWithAttribute:(NSString *)attribute matchingValue:(id)value inContext:(NSManagedObjectContext *)context store:(NSPersistentStore *)store {
    NSParameterAssert(attribute != nil);
    NSParameterAssert(context != nil);

    id object = nil;

    if (value != nil) {
        NSError *error = nil;
        NSFetchRequest *request = [self requestFirstMatchingPredicate:[NSPredicate predicateWithFormat:@"%K = %@", attribute, value] error:&error];

        if (request == nil) {
            PSCCDLog(@"Error fetching first object: %@ - %@", [error localizedDescription], [error userInfo]);
        } else {
            if (store != nil) {
                request.affectedStores = @[store];
            }
            object = [[context executeFetchRequest:request error:&error] lastObject];
        }
    }

    if (object == nil) {
        object = [[self class] newObjectInContext:context];
        if (store != nil) {
            [context assignObject:object toPersistentStore:store];
        }
        
        [object setValue:value forKey:attribute];
    }
    
    return object;
}

+ (NSUInteger)deleteAllMatchingPredicate:(NSPredicate *)predicate requestConfiguration:(psc_request_block)requestConfigurationBlock inContext:(NSManagedObjectContext *)context error:(__autoreleasing NSError **)error {
    NSParameterAssert(context != nil);

    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass([self class])];

    request.predicate = predicate;
    request.returnsObjectsAsFaults = YES;
    request.includesPropertyValues =  NO;
    request.includesSubentities = NO;

    if (requestConfigurationBlock != nil) {
        requestConfigurationBlock(request);
    }

    NSArray *objects = [context executeFetchRequest:request error:error];

    if (objects.count > 0) {
        for (NSManagedObject *object in objects) {
            [context deleteObject:object];
        }
    }

    return objects.count;
}

+ (NSUInteger)deleteAllMatchingPredicate:(NSPredicate *)predicate inContext:(NSManagedObjectContext *)context error:(__autoreleasing NSError **)error {
    return [self deleteAllMatchingPredicate:predicate requestConfiguration:nil inContext:context error:error];
}

+ (NSFetchRequest *)requestAllMatchingPredicate:(NSPredicate *)predicate error:(__autoreleasing NSError **)error {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass([self class])];

    request.predicate = predicate;

    return request;
}

+ (NSFetchRequest *)requestFirstMatchingPredicate:(NSPredicate *)predicate error:(NSError **)error {
    NSFetchRequest *request = [self requestAllMatchingPredicate:predicate error:error];

    request.fetchLimit = 1;
    return request;
}

+ (NSArray *)fetchAllMatchingPredicate:(NSPredicate *)predicate requestConfiguration:(psc_request_block)requestConfigurationBlock inContext:(NSManagedObjectContext *)context error:(__autoreleasing NSError **)error {
    NSFetchRequest *request = [self requestAllMatchingPredicate:predicate error:error];

    if (requestConfigurationBlock != nil) {
        requestConfigurationBlock(request);
    }

    NSArray *objects = [context executeFetchRequest:request error:error];

    return objects;
}

+ (NSArray *)fetchAllMatchingPredicate:(NSPredicate *)predicate inContext:(NSManagedObjectContext *)context error:(__autoreleasing NSError **)error {
    return [self fetchAllMatchingPredicate:predicate requestConfiguration:nil inContext:context error:error];
}

+ (instancetype)fetchFirstMatchingPredicate:(NSPredicate *)predicate
                       requestConfiguration:(psc_request_block)requestConfigurationBlock
                                  inContext:(NSManagedObjectContext *)context
                                      error:(NSError **)error {
    NSFetchRequest *fetchRequest = [self requestFirstMatchingPredicate:predicate error:error];

    if (fetchRequest != nil) {
        if (requestConfigurationBlock != nil) {
            requestConfigurationBlock(fetchRequest);
        }
        
        return [[context executeFetchRequest:fetchRequest error:error] lastObject];
    } else {
        return nil;
    }
}

+ (instancetype)fetchFirstMatchingPredicate:(NSPredicate *)predicate inContext:(NSManagedObjectContext *)context error:(NSError **)error {
    return [self fetchFirstMatchingPredicate:predicate requestConfiguration:nil inContext:context error:error];
}

+ (NSUInteger)countOfObjectsMatchingPredicate:(NSPredicate *)predicate inContext:(NSManagedObjectContext *)context error:(__autoreleasing NSError **)error {
    return [self countOfObjectsMatchingPredicate:predicate requestConfiguration:nil inContext:context error:error];
}

+ (NSUInteger)countOfObjectsMatchingPredicate:(NSPredicate *)predicate
                         requestConfiguration:(psc_request_block)requestConfigurationBlock
                                    inContext:(NSManagedObjectContext *)context error:(NSError **)error {
    NSFetchRequest *request = [self requestAllMatchingPredicate:predicate error:error];

    if (request != nil) {
        if (requestConfigurationBlock != nil) {
            requestConfigurationBlock(request);
        }
        return [context countForFetchRequest:request error:error];
    } else {
        return 0;
    }
}

+ (BOOL)persistEntityDictionaries:(NSArray *)data
    deleteEntitiesNotInDictionary:(BOOL)deleteEntitiesNotInDictionary
            entityKeyInDictionary:(NSString *)dictionaryIDKeyPath
              entityKeyInDatabase:(NSString *)databaseIDKey
                          context:(NSManagedObjectContext *)context
                      updateBlock:(void(^)(id managedObject, NSDictionary *data))updateBlock
                            error:(NSError **)error {

    NSParameterAssert([data isKindOfClass:[NSArray class]]);
    NSParameterAssert(dictionaryIDKeyPath != nil);
    NSParameterAssert(databaseIDKey != nil);
    NSParameterAssert(context != nil);
    NSParameterAssert(updateBlock != nil);

    NSArray *entitiesAlreadyInDatabase = nil;
    NSMutableArray *newEntityIDs = nil;
    NSUInteger deletedObjectsCount = 0, insertedObjectsCount = 0, updatedObjectsCount = 0;

    // get all IDs of the entities in the dictionary (new data)
    NSArray *entityIDs = [data valueForKeyPath:dictionaryIDKeyPath] ?: [NSArray new];
    // Use a dictionary to access the data entries by their ID in O(1)
    NSDictionary *dataDictionary = entityIDs.count > 0 ? [NSDictionary dictionaryWithObjects:data forKeys:entityIDs] : [NSDictionary new];


    // remove all entities that are not in the new data set
    if (deleteEntitiesNotInDictionary) {
        deletedObjectsCount = [self deleteAllMatchingPredicate:[NSPredicate predicateWithFormat:@"NOT (%K IN %@)", databaseIDKey, entityIDs]
                                                     inContext:context
                                                         error:error];
        if (*error != nil) {
            PSCCDLog(@"Error deleting objects with databaseIDKey '%@' that are not contained in the entityIDs: %@", databaseIDKey, entityIDs);
            return NO;
        }
    }

    // retreive all entities with one of these IDs in the database
    {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K IN %@", databaseIDKey, entityIDs];
        entitiesAlreadyInDatabase = [self fetchAllMatchingPredicate:predicate
                                                          inContext:context
                                                              error:error];
        if (entitiesAlreadyInDatabase == nil) {
            PSCCDLog(@"Error fetching objects with databaseIDKey '%@' and entityIDs: %@", databaseIDKey, entityIDs);
            return NO;
        }

        updatedObjectsCount = entitiesAlreadyInDatabase.count;
    }

    // retreive only the new IDs of the objects that are not yet in the database
    {
        newEntityIDs = [entityIDs mutableCopy];
        [newEntityIDs removeObjectsInArray:[entitiesAlreadyInDatabase valueForKey:databaseIDKey]];

        insertedObjectsCount = newEntityIDs.count;
    }


    // update entities that are already present in database
    for (id entityToUpdate in entitiesAlreadyInDatabase) {
        // get corresponding data-dictionary for entity to update
        NSDictionary *entityToUpdateDictionary = dataDictionary[[entityToUpdate valueForKey:databaseIDKey]];

        updateBlock(entityToUpdate, entityToUpdateDictionary);
    }

    // insert entities not yet in database
    for (id newEntityID in newEntityIDs) {
        // get data-dictionary of new entity to insert
        NSDictionary *newEntityDictionary = dataDictionary[newEntityID];

        id newEntity = [self newObjectInContext:context];
        [newEntity setValue:newEntityID forKey:databaseIDKey];

        updateBlock(newEntity, newEntityDictionary);
    }

    PSCCDLog(@"[%@] - deleted: %d, updated: %d, inserted:%d", NSStringFromClass([self class]), deletedObjectsCount, updatedObjectsCount, insertedObjectsCount);

    return YES;
}

////////////////////////////////////////////////////////////////////////
#pragma mark - Instance Methods
////////////////////////////////////////////////////////////////////////

- (void)reset {
    if (self.hasChanges && !self.objectID.isTemporaryID) {
        [self.managedObjectContext refreshObject:self mergeChanges:NO];
    }
}

- (void)deleteFromContext {
    [self.managedObjectContext deleteObject:self];
}

- (NSManagedObjectID *)permanentObjectID {
	if ([self.objectID isTemporaryID]) {
        NSError *error = nil;
		if (![self.managedObjectContext obtainPermanentIDsForObjects:@[self] error:&error]) {
            PSCCDLog(@"Error obtaining permanent object id: %@", error);
        }
	}
    
	return [self objectID];
}


- (id)userInfoValueForKey:(NSString *)key ofProperty:(NSString *)property {
    for (NSPropertyDescription *propertyDescription in self.entity.properties) {
        if ([propertyDescription.name isEqualToString:property]) {
            return [[propertyDescription userInfo] valueForKey:key];
        }
    }
    
    return nil;
}

@end
