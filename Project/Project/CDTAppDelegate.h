//
//  CDTAppDelegate.h
//  Project
//
//  Created by Michael Rhodes on 03/12/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//

#import <UIKit/UIKit.h>

@class CDTDatastore;
@class CDTReplicatorFactory;

@interface CDTAppDelegate : UIResponder <UIApplicationDelegate>

@property (nonatomic, strong) CDTDatastore *datastore;
@property (nonatomic, strong) CDTReplicatorFactory *replicatorFactory;

@property (strong, nonatomic) UIWindow *window;

@end
