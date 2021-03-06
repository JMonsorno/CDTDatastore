//
//  CDTReplicatorFactory.m
//  
//
//  Created by Michael Rhodes on 10/12/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "CDTReplicatorFactory.h"

#import "CDTDatastoreManager.h"
#import "CDTDatastore.h"
#import "CDTReplicator.h"
#import "CDTDocumentRevision.h"
#import "CDTDocumentBody.h"

#import "TDReplicatorManager.h"

@interface CDTReplicatorFactory ()

@property (nonatomic,strong) CDTDatastoreManager *manager;

@property (nonatomic,strong) TDReplicatorManager *replicatorManager;

@end

@implementation CDTReplicatorFactory

#pragma mark Manage our TDReplicatorManager instance

- (id) initWithDatastoreManager: (CDTDatastoreManager*)dsManager {

    self = [super init];
    if (self) {
        self.manager = dsManager;
        TD_DatabaseManager *dbManager = dsManager.manager;
        self.replicatorManager = [[TDReplicatorManager alloc] initWithDatabaseManager:dbManager];
    }
    return self;
}

- (void) start {
    [self.replicatorManager start];
}

- (void) stop {
    [self.replicatorManager stop];
}

#pragma mark CDTReplicatorFactory interface methods

- (CDTReplicator*)onewaySourceDatastore:(CDTDatastore*)source
                              targetURI:(NSURL*)target {
    NSError *error;

    NSDictionary *replicationDoc = @{
        @"source": source.name,
        @"target": [target absoluteString]
        };
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:replicationDoc];

    CDTDatastoreManager *m = self.manager;
    CDTDatastore *datastore = [m datastoreNamed:kTDReplicatorDatabaseName error:&error];

    if (datastore == nil) {
        NSLog(@"Error getting replication db: %@", error);
    }

    CDTReplicator *replicator = [[CDTReplicator alloc] initWithReplicatorDatastore:datastore
                                                           replicationDocumentBody:body];

    return replicator;
}

- (CDTReplicator*)onewaySourceURI:(NSURL*)source
                  targetDatastore:(CDTDatastore*)target {
    NSError *error;

    NSDictionary *replicationDoc = @{
        @"source": [source absoluteString],
        @"target": target.name
    };
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:replicationDoc];

    CDTDatastoreManager *m = self.manager;
    CDTDatastore *datastore = [m datastoreNamed:kTDReplicatorDatabaseName error:&error];

    if (datastore == nil) {
        NSLog(@"Error getting replication db: %@", error);
    }

    CDTReplicator *replicator = [[CDTReplicator alloc] initWithReplicatorDatastore:datastore
                                                           replicationDocumentBody:body];

    return replicator;
}

@end
