## Replicating Data Between Many Devices

Replication is used to synchronise data between the local datastore and a
remote database, either a CouchDB instance or a Cloudant database. Many
datastores can replicate with the same remote database, meaning that
cross-device syncronisation is acheived by setting up replications from each
device to the remote database.

### Setting Up For Sync

Currently, the replication process requires a remote database to exist already.
To avoid exposing credentials for the remote system on each device, we recommend
creating a web service to authenticate users and set up databases for client
devices. This web service needs to:

* Handle sign in/sign up for users.
* Create a new remote database for a new user.
* Grant access to the new database for the new device (e.g., via [API keys][keys]
  on Cloudant or the `_users` database in CouchDB).
* Return the database URL and credentials to the device.

[keys]: https://cloudant.com/for-developers/faq/auth/

### Replication on the Device

From the device side, replication is straightforward. You can replicate from a
local datastore to a remote database, from a remote database to a local
datastore, or both ways to implement synchronisation.

Replicating a local datastore to a remote database:

```objc
#import <CloudantSync.h>

// Create and start the replicator -- -start is essential!
CDTReplicatorFactory *replicatorFactory =
[[CDTReplicatorFactory alloc] initWithDatastoreManager:manager];
[self.replicatorFactory start];

// username/password can be Cloudant API keys
NSString *s = @"https://username:password@username.cloudant.com/my_database";
NSURL *remoteDatabaseURL = [NSURL URLWithString:s];
CDTDatastore ds = [manager datastoreNamed:@"my_datastore"];

// Create a replicator that replicates changes from the local
// datastore to the remote database.
CDTReplicator *replicator =
[self.replicatorFactory onewaySourceDatastore:datastore
                                    targetURI:remoteDatabaseURL];

// Start the replication and wait for it to complete
[replicator start];
while (replicator.isActive) {
    [NSThread sleepForTimeInterval:1.0f];
    NSLog(@" -> %@", [CDTReplicator stringForReplicatorState:replicator.state]);
}
```

And getting data from a remote database to a local one:

```objc
#import <CloudantSync.h>

// Create and start the replicator -- start is essential!
CDTReplicatorFactory *replicatorFactory =
[[CDTReplicatorFactory alloc] initWithDatastoreManager:manager];
[self.replicatorFactory start];

// username/password can be Cloudant API keys
NSString *s = @"https://username:password@username.cloudant.com/my_database";
NSURL *remoteDatabaseURL = [NSURL URLWithString:s];
CDTDatastore ds = [manager datastoreNamed:@"my_datastore"];

// Create a replicator that replicates changes from the local
// datastore to the remote database.
CDTReplicator *replicator =
[self.replicatorFactory onewaySourceURI:remoteDatabaseURL
                        targetDatastore:datastore];

// Start the replication and wait for it to complete
[replicator start];
while (replicator.isActive) {
    [NSThread sleepForTimeInterval:1.0f];
    NSLog(@" -> %@", [CDTReplicator stringForReplicatorState:replicator.state]);
}
```
