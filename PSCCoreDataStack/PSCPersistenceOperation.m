#import "PSCPersistenceOperation.h"
#import "PSCCoreDataStack.h"
#import "NSManagedObjectContext+PSCCoreDataHelper.h"
#import "PSCLogging.h"


static dispatch_queue_t _psc_persistence_queue = NULL;


@interface PSCPersistenceOperation ()

@property (nonatomic, strong) NSManagedObjectContext *parentContext;
@property (nonatomic, copy) psc_persistence_block persistenceBlock;

@end


@implementation PSCPersistenceOperation

////////////////////////////////////////////////////////////////////////
#pragma mark - Lifecycle
////////////////////////////////////////////////////////////////////////

+ (instancetype)operationWithParentContext:(NSManagedObjectContext *)parentContext
                                     block:(psc_persistence_block)block
                                completion:(dispatch_block_t)completion {
    NSParameterAssert(block != nil);

    PSCPersistenceOperation *operation = [[self alloc] initWithParentContext:parentContext];

    operation.persistenceBlock = block;
    operation.completionBlock = completion;

    return operation;
}

- (instancetype)initWithParentContext:(NSManagedObjectContext *)parentContext {
    NSParameterAssert(parentContext != nil);

    if ((self = [super init])) {
        _parentContext = parentContext;
    }

    return self;
}

- (id)init {
    NSAssert(NO, @"Unable to create with plain init, use initWithParentContext: instead");
    return nil;
}

////////////////////////////////////////////////////////////////////////
#pragma mark - Class Methods
////////////////////////////////////////////////////////////////////////

+ (void)persistDataInBackgroundWithParentContext:(NSManagedObjectContext *)parentContext
                                           block:(psc_persistence_block)block
                                      completion:(dispatch_block_t)completion {
    NSParameterAssert(parentContext != nil);
    NSParameterAssert(block != nil);

    dispatch_async(psc_persistence_queue(), ^{
        NSManagedObjectContext *localContext = [parentContext newChildContextWithConcurrencyType:NSPrivateQueueConcurrencyType];

        if (block != nil) {
            block(localContext);
        }

        [localContext performBlockAndWait:^{
            NSError *error = nil;
            if (![localContext save:&error]) {
                PSCCDLog(@"Error persisting local context in PSCPersistenceAction: %@", error);
            }
        }];

        if (completion != nil) {
            dispatch_async(dispatch_get_main_queue(), completion);
        }
    });
}

////////////////////////////////////////////////////////////////////////
#pragma mark - PSCPersisteceOperation
////////////////////////////////////////////////////////////////////////

- (BOOL)persistWithContext:(NSManagedObjectContext *)localContext {
    // do nothing, subclasses can override
    return NO;
}

- (void)willSaveContext:(NSManagedObjectContext *)localContext {
    // do nothing, subclasses can override
}

- (void)didSaveContext:(NSManagedObjectContext *)localContext {
    // do nothing, subclasses can override
}

- (void)didFailToSaveContext:(NSManagedObjectContext *)localContext error:(NSError *)error {
    PSCCDLog(@"Error persisting local context in PSCPersistenceAction: %@", error);
}

- (void)didNotSaveContext:(NSManagedObjectContext *)localContext {
    // do nothing, subclasses can override
}

////////////////////////////////////////////////////////////////////////
#pragma mark - NSOperation
////////////////////////////////////////////////////////////////////////

- (void)main {
    if (self.parentContext == nil) {
        [self didFailToSaveContext:nil error:nil];
        return;
    }

    // There's a noticable performance penalty, when using Parent-Child Contexts to import data.
    // http://floriankugler.com/blog/2013/4/29/concurrent-core-data-stack-performance-shootout
    // By defining PSC_COREDATA_USE_INDEPENDENT_CONTEXTS_TO_IMPORT you can switch to the old way of using
    // independent Managed Object Contexts and merging the changes.
#ifdef PSC_COREDATA_USE_INDEPENDENT_CONTEXTS_TO_IMPORT
    PSCCDLog(@"Using independent contexts to import");
    NSAssert(self.parentContext == [PSCCoreDataStack mainContext], @"When using independent managed object contexts, the parent context must be [PSCCoreDataStack mainContext]");

    NSManagedObjectContext *localContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSConfinementConcurrencyType];
    localContext.persistentStoreCoordinator = self.parentContext.persistentStoreCoordinator;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(managedObjectContextDidSave:)
                                                 name:NSManagedObjectContextDidSaveNotification
                                               object:localContext];
#else
    PSCCDLog(@"Using parent-child contexts to import");
    NSManagedObjectContext *localContext = [self.parentContext newChildContextWithConcurrencyType:NSConfinementConcurrencyType];
#endif

    BOOL save = NO;

    // either persist via block (if set), or call method in subclass
    if (self.persistenceBlock != nil) {
        save = self.persistenceBlock(localContext);
    } else {
        save = [self persistWithContext:localContext];
    }

    if (save && localContext.hasChanges) {
        NSError *error = nil;

        [self willSaveContext:localContext];

        if (![localContext save:&error]) {
            [self didFailToSaveContext:localContext error:error];
        } else {
            [self didSaveContext:localContext];
        }
    } else {
        [self didNotSaveContext:localContext];
    }
}

////////////////////////////////////////////////////////////////////////
#pragma mark - NSNotification
////////////////////////////////////////////////////////////////////////

#ifdef PSC_COREDATA_USE_INDEPENDENT_CONTEXTS_TO_IMPORT
- (void)managedObjectContextDidSave:(NSNotification *)notification {
    NSManagedObjectContext *managedObjectContext = self.parentContext;

    dispatch_block_t mergeChanges = ^{
        [managedObjectContext mergeChangesFromContextDidSaveNotification:notification];
    };

    if ([NSThread isMainThread]) {
        mergeChanges();
    } else {
        dispatch_sync(dispatch_get_main_queue(), mergeChanges);
    }
}
#endif

@end

////////////////////////////////////////////////////////////////////////
#pragma mark - Functions
////////////////////////////////////////////////////////////////////////

dispatch_queue_t psc_persistence_queue(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _psc_persistence_queue = dispatch_queue_create("com.pocketscience.persistence-queue", 0);
    });
    
    return _psc_persistence_queue;
}

