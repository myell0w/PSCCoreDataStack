//
//  PSCFetchedResultsControllerUpdater.h
//  PSCCoreDataStack
//
//  Created by Matthias Tretter on 22.03.13.
//  Copyright (c) 2013 PocketScience. All rights reserved.
//
//  Derived from MrRooni's Gist: https://gist.github.com/MrRooni/4988922


/**
 Controller that can be used to gather information about animated updates in a UITableView/UICollectionView.
 You need to forward every method of your NSFetchedResultsController to an updater instance.
 
 Sample code in your NSFetchedResultsControllerDelegate's controllerDidChangeContent:
 
 - (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
        [self.updater controllerDidChangeContent];
    
        if (self.updater.numberOfTotalChanges > 50) {
            [self.tableView reloadData];
        } else {
            [self.tableView beginUpdates];

            [self.tableView deleteSections:self.deletedSectionIndexes withRowAnimation:UITableViewRowAnimationAutomatic];
            [self.tableView insertSections:self.insertedSectionIndexes withRowAnimation:UITableViewRowAnimationAutomatic];

            [self.tableView deleteRowsAtIndexPaths:self.deletedRowIndexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
            [self.tableView insertRowsAtIndexPaths:self.insertedRowIndexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
            [self.tableView reloadRowsAtIndexPaths:self.updatedRowIndexPaths withRowAnimation:UITableViewRowAnimationAutomatic];

            [self.tableView endUpdates];
        }
 }

 */
@interface PSCFetchedResultsControllerUpdater : NSObject <NSFetchedResultsControllerDelegate>

@property (nonatomic, readonly) NSUInteger numberOfTotalChanges;

@property (nonatomic, readonly) NSIndexSet *deletedSectionIndexes;
@property (nonatomic, readonly) NSIndexSet *insertedSectionIndexes;

@property (nonatomic, readonly) NSArray *deletedRowIndexPaths;
@property (nonatomic, readonly) NSArray *insertedRowIndexPaths;
@property (nonatomic, readonly) NSArray *updatedRowIndexPaths;

@end