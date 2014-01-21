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

- (void) TDdbChanged:(NSNotification*)n;

@property (nonatomic,strong,readonly) TD_Database *database;

@end

@implementation CDTDatastore

+(NSString*)versionString
{
    return @"0.1.0";
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

//    LogTo(CDTReplicatorLog, @"CDTReplicator: dbChanged");

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
    if (![self ensureDatabaseOpen]) {
        *error = TDStatusToNSError(kTDStatusException, nil);
        return nil;
    }


    TD_Revision *revision = [[TD_Revision alloc] initWithDocID:docId
                                                         revID:nil
                                                       deleted:NO];
    revision.body = body.td_body;

    TDStatus status;
    TD_Revision *new = [self.database putRevision:revision
                                   prevRevisionID:nil
                                    allowConflict:NO
                                           status:&status];
    if (TDStatusIsError(status)) {
        *error = TDStatusToNSError(status, nil);
        return nil;
    }

    return [[CDTDocumentRevision alloc] initWithTDRevision:new];
}


-(CDTDocumentRevision *) createDocumentWithBody:(CDTDocumentBody*)body
                                          error:(NSError * __autoreleasing *)error
{

    if (![self ensureDatabaseOpen]) {
        *error = TDStatusToNSError(kTDStatusException, nil);
        return nil;
    }

    TDStatus status;
    TD_Revision *new = [self.database putRevision:[body TD_RevisionValue]
                                   prevRevisionID:nil
                                    allowConflict:NO
                                           status:&status];

    if (TDStatusIsError(status)) {
        *error = TDStatusToNSError(status, nil);
        return nil;
    }

    return [[CDTDocumentRevision alloc] initWithTDRevision:new];
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
    if (![self ensureDatabaseOpen]) {
        *error = TDStatusToNSError(kTDStatusException, nil);
        return nil;
    }

    TDStatus status;
    TD_Revision *rev = [self.database getDocumentWithID:docId
                                             revisionID:revId
                                                options:0
                                                 status:&status];
    if (TDStatusIsError(status)) {
        *error = TDStatusToNSError(status, nil);
        return nil;
    }

    return [[CDTDocumentRevision alloc] initWithTDRevision:rev];
}


-(NSArray*) getAllDocumentsOffset:(NSInteger)offset
                            limit:(NSInteger)limit
                       descending:(BOOL)descending
{
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:limit];

    if (![self ensureDatabaseOpen]) {
        return nil;
    }

    struct TDQueryOptions query = {
        .limit = limit,
        .inclusiveEnd = YES,
        .skip = offset,
        .descending = descending,
        .includeDocs = YES
    };
    NSDictionary *dictResults = [self.database getAllDocs:&query];

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
    if (![self ensureDatabaseOpen]) {
        *error = TDStatusToNSError(kTDStatusException, nil);
        return nil;
    }

    TD_Revision *revision = [[TD_Revision alloc] initWithDocID:docId
                                                         revID:nil
                                                       deleted:NO];
    revision.body = body.td_body;

    TDStatus status;
    TD_Revision *new = [self.database putRevision:revision
                                   prevRevisionID:prevRev
                                    allowConflict:NO
                                           status:&status];
    if (TDStatusIsError(status)) {
        *error = TDStatusToNSError(status, nil);
        return nil;
    }

    return [[CDTDocumentRevision alloc] initWithTDRevision:new];
}


-(BOOL) deleteDocumentWithId:(NSString*)docId
                         rev:(NSString*)rev
                       error:(NSError * __autoreleasing *)error
{
    if (![self ensureDatabaseOpen]) {
        *error = TDStatusToNSError(kTDStatusException, nil);
        return NO;
    }

    TD_Revision *revision = [[TD_Revision alloc] initWithDocID:docId
                                                         revID:nil
                                                       deleted:YES];
    TDStatus status;
    [self.database putRevision:revision
                prevRevisionID:rev
                 allowConflict:NO
                        status:&status];
    if (TDStatusIsError(status)) {
        *error = TDStatusToNSError(status, nil);
        return NO;
    }

    return YES;
}


#pragma mark Helper methods

-(BOOL)ensureDatabaseOpen
{
    return [self.database open];
}


@end
