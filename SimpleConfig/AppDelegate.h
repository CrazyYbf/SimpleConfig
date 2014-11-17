//
//  AppDelegate.h
//  SimpleConfig
//
//  Created by Realsil on 14/11/6.
//  Copyright (c) 2014年 Realtek. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Defines.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow                 *window;
@property (strong, nonatomic) id<UIApplicationDelegate>delagete;
@property (strong, nonatomic) NSValue                  *sharedData;
@end

