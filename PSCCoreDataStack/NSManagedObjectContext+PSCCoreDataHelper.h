//
//  NSManagedObjectContext+PSCCoreDataHelper.h
//  Companion
//
//  Created by Philip Messlehner on 28.02.13.
//  Copyright (c) 2013 Philip Messlehner. All rights reserved.
//


@interface NSManagedObjectContext (PSCCoreDataHelper)

- (NSManagedObjectContext *)newChildContextWithConcurrencyType:(NSUInteger)concurrencyType;

- (void)saveAndPropagateToParentContextBlocking:(BOOL)wait;
- (void)saveAndPropagateToParentContext;

@end
