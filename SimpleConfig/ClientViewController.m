//
//  ClientViewController.m
//  SimpleConfig
//
//  Created by Realsil on 14/11/13.
//  Copyright (c) 2014年 Realtek. All rights reserved.
//

#import "ClientViewController.h"

@interface ClientViewController ()

@end

@implementation ClientViewController
@synthesize sharedData;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    if (sharedData!=nil) {
        struct dev_info dev;
        [sharedData getValue:&dev];
        
        _name_label.text = [NSString stringWithUTF8String:(const char *)dev.extra_info];
        if([_name_label.text isEqualToString:@""] || [_name_label.text isEqualToString:@"\n"])
            _name_label.text = @"Untitled";
        _ip_label.text = [NSString stringWithFormat:@"%02d.%02d.%02d.%02d", 0xFF&(dev.ip>>24), 0xFF&(dev.ip>>16), 0xFF&(dev.ip>>8), 0xFF&dev.ip];
        _mac_label.text = [NSString stringWithFormat:@"%02x:%02x:%02x:%02x:%02x:%02x", dev.mac[0], dev.mac[1], dev.mac[2], dev.mac[3], dev.mac[4], dev.mac[5]];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (void)dealloc {
    [_name_label release];
    [_ip_label release];
    [_mac_label release];
    [_type_img release];
    [super dealloc];
}
@end
