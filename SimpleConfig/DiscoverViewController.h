//
//  DiscoverViewController.h
//  SimpleConfig
//
//  Created by Realsil on 14/11/13.
//  Copyright (c) 2014年 Realtek. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Scanner.h"

@interface DiscoverViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
{
@private
    Scanner *m_scanner;
    BOOL    m_isLoading;
    NSTimer *m_updateTimer;
}

@property (retain, nonatomic) IBOutlet UITableView  *discover_table;
@property (strong, nonatomic) NSMutableArray        *dev_array;

@end