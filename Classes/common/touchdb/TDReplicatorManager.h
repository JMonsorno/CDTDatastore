//
//  TDReplicatorManager.h
//  TouchDB
//
//  Created by Jens Alfke on 2/15/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//
//  Modifications for this distribution by Cloudant, Inc., Copyright (c) 2014 Cloudant, Inc.
//

#import "TD_Database.h"
@class TD_DatabaseManager;
@protocol TDAuthorizer;


extern NSString* const kTDReplicatorDatabaseName;


/** Manages the _replicator database for persistent replications.
    It doesn't really have an API; it works on its own by monitoring the '_replicator' database, and docs in it, for changes. Applications use the regular document APIs to manage replications.
    A TD_Server owns an instance of this class. */
@interface TDReplicatorManager : NSObject
{
    TD_DatabaseManager* _dbManager;
    TD_Database* _replicatorDB;
    NSThread* _thread;
    NSMutableDictionary* _replicatorsByDocID;
    BOOL _updateInProgress;

    NSThread* _serverThread;
    BOOL _stopRunLoop;
}

- (id) initWithDatabaseManager: (TD_DatabaseManager*)dbManager;

- (void) start;
- (void) stop;

@end
