//
//  PSCFetchedResultsControllerUpdater.m
//  PSCCoreDataStack
//
//  Created by Matthias Tretter on 22.03.13.
//  Copyright (c) 2013 PocketScience. All rights reserved.
//

#import "PSCFetchedResultsControllerUpdater.h"


@implementation PSCFetchedResultsControllerUpdater {
    NSMutableIndexSet *_insertedSectionIndexes;
    NSMutableIndexSet *_deletedSectionIndexes;
    NSMutableArray *_deletedObjectIndexPaths;
    NSMutableArray *_insertedObjectIndexPaths;
    NSMutableArray *_updatedObjectIndexPaths;
    NSMutableArray *_movedObjectIndexPaths;
}

////////////////////////////////////////////////////////////////////////
#pragma mark - PSCFetchedResultsControllerUpdater
////////////////////////////////////////////////////////////////////////

- (void)reset {
    _insertedSectionIndexes = [[NSMutableIndexSet alloc] init];
    _deletedSectionIndexes = [[NSMutableIndexSet alloc] init];
    
    _deletedObjectIndexPaths = [[NSMutableArray alloc] init];
    _insertedObjectIndexPaths = [[NSMutableArray alloc] init];
    _updatedObjectIndexPaths = [[NSMutableArray alloc] init];
    _movedObjectIndexPaths = [[NSMutableArray alloc] init];
}

- (NSUInteger)numberOfTotalChanges {
    return ([self.deletedSectionIndexes count] + [self.insertedSectionIndexes count] +
            [self.deletedObjectIndexPaths count] + [self.insertedObjectIndexPaths count] +
            [self.updatedObjectIndexPaths count] + [self.movedObjectIndexPaths count]);
}

- (NSUInteger)numberOfSectionChanges {
    return ([self.deletedSectionIndexes count] + [self.insertedSectionIndexes count]);
}

////////////////////////////////////////////////////////////////////////
#pragma mark - NSFetchedResultsControllerDelegate
////////////////////////////////////////////////////////////////////////

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    [self reset];
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    // do nothing specific here
}

- (NSString *)controller:(NSFetchedResultsController *)controller sectionIndexTitleForSectionName:(NSString *)sectionName {
    // only implemented for safety, if every delegate method gets forwarded
    return sectionName;
}

- (void)controller:(NSFetchedResultsController *)controller
   didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath {
    if (type == NSFetchedResultsChangeInsert) {
        if (![_insertedSectionIndexes containsIndex:newIndexPath.section]) {
            [_insertedObjectIndexPaths addObject:newIndexPath];
        }        
    } else if (type == NSFetchedResultsChangeDelete) {
        if (![_deletedSectionIndexes containsIndex:indexPath.section]) {
            [_deletedObjectIndexPaths addObject:indexPath];
        }
    } else if (type == NSFetchedResultsChangeMove) {
        if (![_insertedSectionIndexes containsIndex:newIndexPath.section] || ![_deletedSectionIndexes containsIndex:indexPath.section]) {
            [_movedObjectIndexPaths addObject:@[newIndexPath, indexPath]];
        }
    } else if (type == NSFetchedResultsChangeUpdate) {
        [_updatedObjectIndexPaths addObject:indexPath];
    }
}

- (void)controller:(NSFetchedResultsController *)controller
  didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex
     forChangeType:(NSFetchedResultsChangeType)type {
    switch (type) {
        case NSFetchedResultsChangeInsert: {
            [_insertedSectionIndexes addIndex:sectionIndex];
            break;
        }

        case NSFetchedResultsChangeDelete: {
            [_deletedSectionIndexes addIndex:sectionIndex];
            break;
        }

        default: {
            // Shouldn't have a default
            break;
        }
    }
}

@end
