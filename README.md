# CDTDatastore

[![Version](http://cocoapod-badges.herokuapp.com/v/CDTDatastore/badge.png)](http://cocoadocs.org/docsets/CDTDatastore)
[![Platform](http://cocoapod-badges.herokuapp.com/p/CDTDatastore/badge.png)](http://cocoadocs.org/docsets/CDTDatastore)
[![Build Status](https://travis-ci.org/cloudant/CDTDatastore.png?branch=master)](https://travis-ci.org/cloudant/CDTDatastore)

**Applications use Cloudant Sync to store, index and query local JSON data on a
device and to synchronise data between many devices. Synchronisation is under
the control of the application, rather than being controlled by the underlying
system. Conflicts are also easy to manage and resolve, either on the local
device or in the remote database.**

Cloudant Sync is an [Apache CouchDB&trade;][acdb]
replication-protocol-compatible datastore for
devices that don't want or need to run a full CouchDB instance. It's built
by [Cloudant](https://cloudant.com), building on the work of many others, and
is available under the [Apache 2.0 licence][ap2].

[ap2]: https://github.com/cloudant/sync-android/blob/master/LICENSE
[acdb]: http://couchdb.apache.org/

The API is quite different from CouchDB's; we retain the
[MVCC](http://en.wikipedia.org/wiki/Multiversion_concurrency_control) data
model but not the HTTP-centric API.

This library is for iOS, an [Android version][android] is also available.

[android]: https://github.com/cloudant/sync-android

If you have questions, please join our [mailing list][mlist] and drop us a 
line.

[mlist]: https://groups.google.com/forum/#!forum/cloudant-sync

## Using in your project

CDTDatastore is available through [CocoaPods](http://cocoapods.org), to install
it add the following line to your Podfile:

```ruby
pod "CDTDatastore"
```

[gs]: https://github.com/cloudant/CDTDatastore/wiki/Getting-Started

## Example project

There is an example project in the `Project` folder, for iOS 7. To get
this up and running independently of the main codebase, a Podfile is
included:

```bash
$ cd Project
$ pod install
$ open Project.xcworkspace
```

## Running the tests

See [CONTRIBUTING](CONTRIBUTING.md).

## Overview of the library

Once the libraries are added to a project, the basics of adding and reading
a document are:

```objc
#import <CloudantSync.h>

// Create a CDTDatastoreManager using application internal storage path
NSError *outError = nil;
NSFileManager *fileManager= [NSFileManager defaultManager];

NSURL *documentsDir = [[fileManager URLsForDirectory:NSDocumentDirectory
                                           inDomains:NSUserDomainMask] lastObject];
NSURL *storeURL = [documentsDir URLByAppendingPathComponent:@"cloudant-sync-datastore"];
NSString *path = [storeURL path];

CDTDatastoreManager *manager =
[[CDTDatastoreManager alloc] initWithDirectory:path
                                         error:&outError];

CDTDatastore *datastore = [manager datastoreNamed:@"my_datastore"
                                            error:&outError];

// Create a document
NSDictionary *doc = @{
    @"description": @"Buy milk",
    @"completed": @NO,
    @"type": @"com.cloudant.sync.example.task"
};
CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:doc];

NSError *error;
CDTDocumentRevision *revision = [datastore createDocumentWithBody:body
                                                            error:&error];

// Read a document
NSString *docId = revision.docId;
CDTDocumentRevision *retrieved = [datastore getDocumentWithId:docId
                                                        error:&error];
```

Read more in [the CRUD document](https://github.com/cloudant/CDTDatastore/blob/master/doc/crud.md).

You will also be able to subscribe for notifications of changes in the database, which
is described in [the events documentation for Android](https://github.com/cloudant/sync-android/blob/master/doc/events.md). The implementation is still in-flux on iOS.

### Replicating Data Between Many Devices

Replication is used to synchronise data between the local datastore and a
remote database, either a CouchDB instance or a Cloudant database. Many
datastores can replicate with the same remote database, meaning that
cross-device syncronisation is acheived by setting up replications from each
device the the remote database.

Replication is simple to get started in the common cases:

```objc
#import <CloudantSync.h>

// Create and start the replicator -- -start is essential!
CDTReplicatorFactory *replicatorFactory =
[[CDTReplicatorFactory alloc] initWithDatastoreManager:manager];
[replicatorFactory start];

NSString *s = @"https://apikey:apipassword@username.cloudant.com/my_database";
NSURL *remoteDatabaseURL = [NSURL URLWithString:s];
CDTDatastore *datastore = [manager datastoreNamed:@"my_datastore"];

// Replicate from the local to remote database
CDTReplicator *replicator =
[replicatorFactory onewaySourceDatastore:datastore
                               targetURI:remoteDatabaseURL];


// Fire-and-forget (there are easy ways to monitor the state too)
[replicator start];
```

Read more in [the replication docs](https://github.com/cloudant/CDTDatastore/blob/master/doc/replication.md).

### Finding data

Once you have thousands of documents in a database, it's important to have
efficient ways of finding them. We've added an easy-to-use querying API. Once
the appropriate indexes are set up, querying is as follows:

```objc
NSDictionary *query = @{
    @"name": @"John",       // name equals John
    @"age": @{@"min": @25}  // age greater than 25
};
CDTQueryResult *result = [indexManager queryWithDictionary:query
                                                     error:nil];

for(CDTDocumentRevision *revision in result) {
    // do something
}
```

See [Index and Querying Data](https://github.com/cloudant/CDTDatastore/blob/master/doc/index-query.md).

### Conflicts

An obvious repercussion of being able to replicate documents about the place
is that sometimes you might edit them in more than one place at the same time.
When the databases containing these concurrent edits replicate, there needs
to be some way to bring these divergent documents back together. Cloudant's
MVCC data-model is used to do this.

A document is really a tree of the document and its history. This is neat
because it allows us to store multiple versions of a document. In the main,
there's a single, linear tree -- just a single branch -- running from the
creation of the document to the current revision. It's possible, however,
to create further branches in the tree. At this point your document is
conflicted and needs some surgury to resolve the conflicts and bring it
back to full health.

This is coming up for iOS, so see the Android docs for the soon-to-be-complete
process:

- [Android conflicts documentation](https://github.com/cloudant/sync-android/blob/master/doc/conflicts.md).


## Requirements

All requirements are included in the source code or pulled in as dependecies
via `pod install`.

## Contributors

See [CONTRIBUTORS](CONTRIBUTORS).

## Contributing to the project

See [CONTRIBUTING](CONTRIBUTING.md).

## License

See [LICENSE](LICENSE)

### CDTDatastore classes and TouchDB classes

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

### Used libraries under different licences

* MYUtilities is licensed under the BSD licence (portions copied into vendor
  directory).
* FMDB, by Gus Mueller, is under the MIT License.
* Google Toolbox For Mac is under the Apache License 2.0.

