//
//  CloudantReplicationBase+CompareDb.h
//  ReplicationAcceptance
//
//  Created by Michael Rhodes on 03/02/2014.
//
//

#import "CloudantReplicationBase.h"

@class CDTDatastore;

/*!
 * This category is a helper which is intended to compare the contents of a
 * remote CouchDB database and a local CDTDatastore instance.
 *
 * After replication tests, we can check that the local and remote databases
 * are the same.
 */
@interface CloudantReplicationBase (CompareDb)

-(BOOL) compareDatastore:(CDTDatastore*)local withDatabase:(NSURL*)databaseUrl;

@end
