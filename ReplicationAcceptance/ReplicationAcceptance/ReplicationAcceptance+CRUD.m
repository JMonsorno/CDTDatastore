//
//  CloudantReplicationBase+CRUD.m
//  ReplicationAcceptance
//
//  Created by Michael Rhodes on 05/02/2014.
//
//

#import "ReplicationAcceptance+CRUD.h"

#import <CloudantSync.h>
#import <UNIRest.h>

@implementation ReplicationAcceptance (CRUD)

#pragma mark - Doc CRUD helpers

-(void) createLocalDocs:(NSInteger)count
{
    [self createLocalDocs:count suffixFrom:0];
}

-(void) createLocalDocs:(NSInteger)count suffixFrom:(NSInteger)start
{
    [self createLocalDocs:count suffixFrom:start reverse:NO updates:NO];
}

/**
 * Create a given number local documents, with IDs of the form doc-1, doc-2 etc.
 *
 * @param count number of documents to create
 * @param start the number to start the suffix numbering, e.g., start = 100, first doc doc-101
 * @param reverse go from doc-100 -> doc-1
 * @param updates check for and update current doc if there is one
 */
-(void) createLocalDocs:(NSInteger)count
             suffixFrom:(NSInteger)start
                reverse:(BOOL)reverse
                updates:(BOOL)updates
{

    for (long i = 1; i < count+1; i++) {

        NSError *error;

        NSString *docId;
        NSInteger currentIndex = start + i;

        if (!reverse) {
            docId = [NSString stringWithFormat:@"doc-%li", (long)currentIndex];
        } else {
            NSInteger endIndex = start + count;
            docId = [NSString stringWithFormat:@"doc-%li", endIndex-currentIndex+1];
        }

        CDTDocumentRevision *rev;
        if (updates) {
            rev = [self.datastore getDocumentWithId:docId error:&error];
            if (error.code != 404) {  // new doc, so not error
                STAssertNil(error, @"Error creating docs: %@", error);
                STAssertNotNil(rev, @"Error creating docs: rev was nil");
            }
        }

        error = nil;

        NSDictionary *dict = @{@"hello": @"world"};
        CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:dict];
        if (rev == nil) {  // we need to update an existing rev
            rev = [self.datastore createDocumentWithId:docId
                                                  body:body
                                                 error:&error];
            //            NSLog(@"Created %@", docId);
            STAssertNil(error, @"Error creating doc: %@", error);
            STAssertNotNil(rev, @"Error creating doc: rev was nil");
        } else {
            rev = [self.datastore updateDocumentWithId:docId
                                               prevRev:rev.revId
                                                  body:body
                                                 error:&error];
            //            NSLog(@"Updated %@", docId);
            STAssertNil(error, @"Error updating doc: %@", error);
            STAssertNotNil(rev, @"Error updating doc: rev was nil");
        }


        if (i % 1000 == 0) {
            NSLog(@" -> %li documents created", i);
        }
    }
}

-(void) createLocalDocWithId:(NSString*)docId revs:(NSInteger)n_revs
{
    NSError *error;

    NSDictionary *dict = @{@"hello": @"world"};
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:dict];
    CDTDocumentRevision *rev = [self.datastore createDocumentWithId:docId
                                                               body:body
                                                              error:&error];
    STAssertNil(error, @"Error creating docs: %@", error);
    STAssertNotNil(rev, @"Error creating docs: rev was nil, but so was error");

    // Create revisions of document in local store
    rev = [self addRevsToDocumentRevision:rev count:n_revs];

    NSString *revPrefix = [NSString stringWithFormat:@"%li", (long)n_revs];
    STAssertTrue([rev.revId hasPrefix:revPrefix], @"Unexpected current rev in local document, %@", rev.revId);
}

-(CDTDocumentRevision*) addRevsToDocumentRevision:(CDTDocumentRevision*)rev count:(NSInteger)n_revs
{
    NSError *error;
    NSDictionary *dict = @{@"hello": @"world"};
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:dict];
    for (long i = 0; i < n_revs-1; i++) {
        rev = [self.datastore updateDocumentWithId:rev.docId
                                           prevRev:rev.revId
                                              body:body
                                             error:&error];
    }
    return rev;
}

-(void) createRemoteDocs:(NSInteger)count
{
    NSMutableArray *docs = [NSMutableArray array];
    for (long i = 1; i < count+1; i++) {
        NSString *docId = [NSString stringWithFormat:@"doc-%li", i];
        NSDictionary *dict = @{@"_id": docId, @"hello": @"world"};
        [docs addObject:dict];
    }

    NSDictionary *bulk_json = @{@"docs": docs};

    NSURL *bulk_url = [self.primaryRemoteDatabaseURL URLByAppendingPathComponent:@"_bulk_docs"];

    NSDictionary* headers = @{@"accept": @"application/json",
                              @"content-type": @"application/json"};
    UNIHTTPJsonResponse* response = [[UNIRest postEntity:^(UNIBodyRequest* request) {
        [request setUrl:[bulk_url absoluteString]];
        [request setHeaders:headers];
        [request setBody:[NSJSONSerialization dataWithJSONObject:bulk_json
                                                         options:0
                                                           error:nil]];
    }] asJson];
    //    NSLog(@"%@", response.body.array);
    STAssertTrue([response.body.array count] == count, @"Remote db has wrong number of docs");
}

-(void) createRemoteDocWithId:(NSString*)docId revs:(NSInteger)n_revs
{
    NSString *revId;
    NSDictionary *dict = @{@"hello": @"world"};

    NSURL *docURL = [self.primaryRemoteDatabaseURL URLByAppendingPathComponent:docId];

    NSDictionary* headers = @{@"accept": @"application/json",
                              @"content-type": @"application/json"};
    UNIHTTPJsonResponse* response = [[UNIRest putEntity:^(UNIBodyRequest* request) {
        [request setUrl:[docURL absoluteString]];
        [request setHeaders:headers];
        [request setBody:[NSJSONSerialization dataWithJSONObject:dict
                                                         options:0
                                                           error:nil]];
    }] asJson];
    STAssertTrue([response.body.object objectForKey:@"ok"] != nil, @"Create document failed");
    revId = [response.body.object objectForKey:@"rev"];

    // Create revisions of document in remote store
    for (long i = 0; i < n_revs-1; i++) {
        headers = @{@"accept": @"application/json",
                    @"content-type": @"application/json",
                    @"If-Match": revId};
        response = [[UNIRest putEntity:^(UNIBodyRequest* request) {
            [request setUrl:[docURL absoluteString]];
            [request setHeaders:headers];
            [request setBody:[NSJSONSerialization dataWithJSONObject:dict
                                                             options:0
                                                               error:nil]];
        }] asJson];
        revId = [response.body.object objectForKey:@"rev"];
    }

    NSString *revPrefix = [NSString stringWithFormat:@"%li", (long)n_revs];
    STAssertTrue([revId hasPrefix:revPrefix], @"Unexpected current rev in local document, %@", revId);
}

-(NSDictionary*) remoteDbMetadata
{
    // Check document count in the remote DB
    NSDictionary* headers = @{@"accept": @"application/json"};
    return [[UNIRest get:^(UNISimpleRequest* request) {
        [request setUrl:[self.primaryRemoteDatabaseURL absoluteString]];
        [request setHeaders:headers];
    }] asJson].body.object;
}

-(void) assertRemoteDatabaseHasDocCount:(NSInteger)count deletedDocs:(NSInteger)deleted
{
    NSDictionary *dbMeta = [self remoteDbMetadata];
    STAssertEquals(count,
                   [dbMeta[@"doc_count"] integerValue],
                   @"Wrong number of remote docs");
    STAssertEquals(deleted,
                   [dbMeta[@"doc_del_count"] integerValue],
                   @"Wrong number of remote deleted docs");
}

@end
