 //
//  CDTDatastore.m
//  CloudantSync
//
//  Created by Michael Rhodes on 02/07/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//

#import "CDTDatastore.h"
#import "CDTDocumentRevision.h"
#import "CDTDatastoreManager.h"
#import "CDTDocumentBody.h"

#import "TD_Database.h"
#import "TD_View.h"
#import "TD_Body.h"
#import "TD_Database+Insertion.h"


NSString* const CDTDatastoreChangeNotification = @"CDTDatastoreChangeNotification";


@interface CDTDatastore ()

+(dispatch_queue_t)storeSerialQueue;

- (void) TDdbChanged:(NSNotification*)n;

@property (nonatomic,strong,readonly) TD_Database *database;

@end

@implementation CDTDatastore

+(NSString*)versionString
{
    return @"0.1.0";
}

// Used internally to ensure serial access to datastore
// (ensures read-your-writes in a trivial way).
+(dispatch_queue_t)storeSerialQueue
{
    static dispatch_once_t pred;
    static dispatch_queue_t storeDispatchQueue = NULL;
    dispatch_once(&pred, ^{
        storeDispatchQueue = dispatch_queue_create("com.cloudant.cloudantsync.IOQueue", NULL);
    });
    return storeDispatchQueue;
}


-(id)initWithDatabase:(TD_Database*)database
{
    self = [super init];
    if (self) {
        _database = database;

        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(TDdbChanged:)
                                                     name: TD_DatabaseChangeNotification
                                                   object: _database];
    }
    return self;
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

#pragma mark Observer methods

/**
 * Notified that a document has been created/modified/deleted in the
 * database we're wrapping. Wrap it up into a notification containing
 * CDT* classes and re-notify.
 *
 * All this wrapping is to prevent TD* types escaping.
 */
- (void) TDdbChanged:(NSNotification*)n {

    // Notification structure:

    /** NSNotification posted when a document is updated.
     UserInfo keys: 
      - @"rev": the new TD_Revision,
      - @"source": NSURL of remote db pulled from,
      - @"winner": new winning TD_Revision, _if_ it changed (often same as rev). 
    */

    LogTo(CDTReplicatorLog, @"CDTReplicator: dbChanged");

    NSDictionary *nUserInfo = n.userInfo;
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];

    if (nil != nUserInfo[@"rev"]) {
        userInfo[@"rev"] = [[CDTDocumentRevision alloc]
                            initWithTDRevision:nUserInfo[@"rev"]];
    }

    if (nil != nUserInfo[@"winner"]) {
        userInfo[@"winner"] = [[CDTDocumentRevision alloc]
                            initWithTDRevision:nUserInfo[@"rev"]];
    }

    if (nil != nUserInfo[@"source"]) {
        userInfo[@"winner"] = nUserInfo[@"source"];
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:CDTDatastoreChangeNotification
                                                        object:self
                                                      userInfo:userInfo];
}

#pragma mark Datastore implementation

-(NSUInteger)documentCount {
    if (![self ensureDatabaseOpen]) {
        return -1;
    }
    return self.database.documentCount;
}

- (NSString*)name {
    return self.database.name;
}

-(CDTDocumentRevision *) createDocumentWithId:(NSString*)docId
                                         body:(CDTDocumentBody*)body
                                        error:(NSError * __autoreleasing *)error
{
    __block CDTDocumentRevision *ob = nil;
    __block TDStatus status = kTDStatusException;
    __weak CDTDatastore *weakSelf = self;
    
    dispatch_sync([CDTDatastore storeSerialQueue], ^{
        CDTDatastore *strongSelf = weakSelf;
        if (![strongSelf ensureDatabaseOpen]) {
            return;
        }

        TD_Revision *revision = [[TD_Revision alloc] initWithDocID:docId
                                                             revID:nil
                                                           deleted:NO];
        revision.body = body.td_body;
        TD_Revision *new = [strongSelf.database putRevision:revision
                                             prevRevisionID:nil
                                              allowConflict:NO
                                                     status:&status];
        if (!TDStatusIsError(status)) {
            ob = [[CDTDocumentRevision alloc] initWithTDRevision:new];
        }
    });
    
    if (TDStatusIsError(status)) {
        *error = TDStatusToNSError(status, nil);
    }
    
    return ob;
}


-(CDTDocumentRevision *) createDocumentWithBody:(CDTDocumentBody*)body
                                          error:(NSError * __autoreleasing *)error
{
    __block CDTDocumentRevision *ob = nil;
    __block TDStatus status = kTDStatusException;
    __weak CDTDatastore *weakSelf = self;
    
    dispatch_sync([CDTDatastore storeSerialQueue], ^{
        CDTDatastore *strongSelf = weakSelf;
        if (![strongSelf ensureDatabaseOpen]) {
            return;
        }

        TD_Revision *new = [strongSelf.database putRevision:[body TD_RevisionValue]
                                             prevRevisionID:nil
                                              allowConflict:NO
                                                     status:&status];
        if (!TDStatusIsError(status)) {
            ob = [[CDTDocumentRevision alloc] initWithTDRevision:new];
        }
    });
    
    if (TDStatusIsError(status)) {
        *error = TDStatusToNSError(status, nil);
    }
    
    return ob;
}


-(CDTDocumentRevision *) getDocumentWithId:(NSString*)docId
                                     error:(NSError * __autoreleasing *)error
{
    return [self getDocumentWithId:docId rev:nil error: error];
}


-(CDTDocumentRevision *) getDocumentWithId:(NSString*)docId
                                       rev:(NSString*)revId
                                     error:(NSError * __autoreleasing *)error
{
    __block CDTDocumentRevision *ob = nil;
    __block TDStatus status = kTDStatusException;
    __weak CDTDatastore *weakSelf = self;
    dispatch_sync([CDTDatastore storeSerialQueue], ^{
        CDTDatastore *strongSelf = weakSelf;
        if (![strongSelf ensureDatabaseOpen]) {
            return;
        }

        TD_Revision *rev = [strongSelf.database getDocumentWithID:docId
                                                       revisionID:revId
                                                          options:0
                                                           status:&status];
        if (!TDStatusIsError(status)) {
            ob = [[CDTDocumentRevision alloc] initWithTDRevision:rev];
        }
    });
    
    if (TDStatusIsError(status)) {
        *error = TDStatusToNSError(status, nil);
    }
    
    return ob;
}


-(NSArray*) getAllDocumentsOffset:(NSInteger)offset
                            limit:(NSInteger)limit
                       descending:(BOOL)descending
{
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:limit];
    __weak CDTDatastore *weakSelf = self;
    dispatch_sync([CDTDatastore storeSerialQueue], ^{
        CDTDatastore *strongSelf = weakSelf;
        if (![strongSelf ensureDatabaseOpen]) {
            return ;
        }

        struct TDQueryOptions query = {
            .limit = limit,
            .inclusiveEnd = YES,
            .skip = offset,
            .descending = descending,
            .includeDocs = YES
        };
        NSDictionary *dictResults = [strongSelf.database getAllDocs:&query];

        for (NSDictionary *row in dictResults[@"rows"]) {
//            NSLog(@"%@", row);
            NSString *docId = row[@"id"];
            NSString *revId = row[@"value"][@"rev"];

            TD_Revision *revision = [[TD_Revision alloc] initWithDocID:docId
                                                                 revID:revId
                                                               deleted:NO];
            revision.body = [[TD_Body alloc] initWithProperties:row[@"doc"]];

            CDTDocumentRevision *ob = [[CDTDocumentRevision alloc] initWithTDRevision:revision];
            [result addObject:ob];
        }
    });
    return result;
}


-(NSArray*) getDocumentsWithIds:(NSArray*)docIds
                          error:(NSError * __autoreleasing *)error

{
    NSError *innerError = nil;
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:docIds.count];

    for (NSString *docId in docIds) {
        CDTDocumentRevision *ob = [self getDocumentWithId:docId
                                                    error:&innerError];
        if (innerError != nil) {
            *error = innerError;
            return nil;
        }
        [result addObject:ob];
    }

    return result;
}


-(CDTDocumentRevision *) updateDocumentWithId:(NSString*)docId
                                      prevRev:(NSString*)prevRev
                                         body:(CDTDocumentBody*)body
                                        error:(NSError * __autoreleasing *)error
{
    __block CDTDocumentRevision *ob = nil;
    __block TDStatus status = kTDStatusException;
    __weak CDTDatastore *weakSelf = self;
    
    dispatch_sync([CDTDatastore storeSerialQueue], ^{
        CDTDatastore *strongSelf = weakSelf;
        if (![strongSelf ensureDatabaseOpen]) {
            return ;
        }

        TD_Revision *revision = [[TD_Revision alloc] initWithDocID:docId
                                                             revID:nil
                                                           deleted:NO];
        revision.body = body.td_body;
        TD_Revision *new = [strongSelf.database putRevision:revision
                                             prevRevisionID:prevRev
                                              allowConflict:NO
                                                     status:&status];
        if (!TDStatusIsError(status)) {
            ob = [[CDTDocumentRevision alloc] initWithTDRevision:new];
        }
    });
    
    if (TDStatusIsError(status)) {
        *error = TDStatusToNSError(status, nil);
    }
    
    return ob;
}


-(BOOL) deleteDocumentWithId:(NSString*)docId
                         rev:(NSString*)rev
                       error:(NSError * __autoreleasing *)error
{
    __block NSNumber *result = [NSNumber numberWithBool:NO];
    __block TDStatus status = kTDStatusException;
    __weak CDTDatastore *weakSelf = self;
    
    dispatch_sync([CDTDatastore storeSerialQueue], ^{
        CDTDatastore *strongSelf = weakSelf;
        if (![strongSelf ensureDatabaseOpen]) {
            return ;
        }

        TD_Revision *revision = [[TD_Revision alloc] initWithDocID:docId
                                                             revID:nil
                                                           deleted:YES];
        [strongSelf.database putRevision:revision
                          prevRevisionID:rev
                           allowConflict:NO
                                  status:&status];
        if (!TDStatusIsError(status)) {
            result = [NSNumber numberWithBool:YES];
        }
    });
    
    if (TDStatusIsError(status)) {
        *error = TDStatusToNSError(status, nil);
    }
    
    return [result boolValue];
}


#pragma mark Helper methods

-(BOOL)ensureDatabaseOpen
{
    return [self.database open];
}


@end
