//
//  ClientViewController.h
//  SimpleConfig
//
//  Created by Realsil on 14/11/13.
//  Copyright (c) 2014年 Realtek. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Defines.h"

@interface ClientViewController : UIViewController

@property (strong, nonatomic) NSValue               *dev_val;

@property (retain, nonatomic) IBOutlet UILabel      *name_label;
@property (retain, nonatomic) IBOutlet UILabel      *ip_label;
@property (retain, nonatomic) IBOutlet UILabel      *mac_label;
@property (retain, nonatomic) IBOutlet UIImageView  *type_img;
@end
