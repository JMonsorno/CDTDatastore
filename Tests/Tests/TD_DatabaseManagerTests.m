//
//  TD_DatabaseManagerTests.m
//  Tests
//
//  Created by Adam Cox on 1/15/14.
//  Copyright (c) 2014 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import <Foundation/Foundation.h>
#import <SenTestingKit/SenTestingKit.h>
#import "CollectionUtils.h"
#import "TD_DatabaseManager.h"
#import "TD_Database.h"

@interface TD_DatabaseManagerTests : SenTestCase


@end

@implementation TD_DatabaseManagerTests

- (void)testManager
{
    //RequireTestCase(TD_Database); how can I do this in XCode?
    
    TD_DatabaseManager* dbm = [TD_DatabaseManager createEmptyAtTemporaryPath: @"TD_DatabaseManagerTest"];
    TD_Database* db = [dbm databaseNamed: @"foo"];
    
    STAssertNotNil(db, @"TD_Database is nil in %s", __PRETTY_FUNCTION__);
    STAssertEqualObjects(db.name, @"foo", @"TD_Database.name is not \"foo\" in %s", __PRETTY_FUNCTION__);
    STAssertEqualObjects(db.path.stringByDeletingLastPathComponent, dbm.directory, @"TD_Database path is not equal to path supplied by TD_DatabaseManager in %s", __PRETTY_FUNCTION__);
    
    STAssertTrue(!db.exists, @"TD_Database already exists in %s", __PRETTY_FUNCTION__);
    
    STAssertEquals([dbm databaseNamed: @"foo"], db, @"TD_DatabaseManager is not aware of a database named \"foo\" in %s", __PRETTY_FUNCTION__);
    
    STAssertEqualObjects(dbm.allDatabaseNames, @[], @"TD_DatabaseManager reports some database already exists in %s", __PRETTY_FUNCTION__);    // because foo doesn't exist yet
    
    STAssertTrue([db open], @"TD_Database.open returned NO in %s", __PRETTY_FUNCTION__);
    STAssertTrue(db.exists, @"TD_Database does not exist in %s", __PRETTY_FUNCTION__);
    
    STAssertEqualObjects(dbm.allDatabaseNames, @[@"foo"], @"TD_DatabaseManager reports some database other than \"foo\" in %s", __PRETTY_FUNCTION__);  // because foo should now exist and be the only database here
}




@end
