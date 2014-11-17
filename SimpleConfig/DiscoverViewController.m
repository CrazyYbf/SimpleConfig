//
//  DiscoverViewController.m
//  SimpleConfig
//
//  Created by Realsil on 14/11/13.
//  Copyright (c) 2014年 Realtek. All rights reserved.
//

#import "DiscoverViewController.h"

@interface DiscoverViewController ()

@end

@implementation DiscoverViewController
@synthesize discover_table, dev_array;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    m_isLoading = false;
    m_scanner = [[Scanner alloc] init];
    [m_scanner rtk_sc_build_scan_data:SC_USE_ENCRYPTION];
    dev_array = [m_scanner rtk_sc_get_scan_list];
    m_updateTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(timerHandler:) userInfo:nil repeats:YES];
    
    // auto refresh
    for (int i = 0; i<20; i++) {
        [m_scanner rtk_sc_start_scan];
    }
    [discover_table reloadData];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

///*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    if (m_picked>[dev_array count]) {
        return;
    }
    ClientViewController *client_vc = segue.destinationViewController;
    struct dev_info dev;
    NSValue *dev_val = [dev_array objectAtIndex:m_picked];
    [dev_val getValue:&dev];
    
    client_vc.sharedData = [[NSValue alloc] initWithBytes:&dev objCType:@encode(struct dev_info)];
}
//*/

- (void)dealloc {
    [discover_table release];
    [m_scanner dealloc];
    [super dealloc];
}

- (void)viewDidDisappear:(BOOL)animated
{
    // Must release simpleConfig, so that its asyncUDPSocket delegate won't receive data
    [m_scanner rtk_sc_close_sock];
    [super viewDidDisappear:animated];
}

- (void)viewWillAppear:(BOOL)animated
{
    NSLog(@"reopen socket");
    [m_scanner rtk_sc_reopen_sock];
}

/* -------------TableView DataSouce and Delegate-------------- */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (dev_array!=nil) {
        return [dev_array count];
    }
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    int index = (int)indexPath.row;
    struct dev_info dev;
    NSValue *dev_val;
    ClientListCell *cell = (ClientListCell *)[tableView dequeueReusableCellWithIdentifier:@"DiscoverCell"];
    
    if (dev_array == nil) {
        cell.cell_dev_name.text = @"Device Name";
        cell.cell_dev_mac.text = @"Device MAC";
        return cell;
    }
    
    switch (index) {
        default:
            dev_val = [dev_array objectAtIndex:index];
            [dev_val getValue:&dev];
            
            NSString *dev_name = [NSString stringWithCString:(const char *)dev.extra_info encoding:NSUTF8StringEncoding];
            if ([dev_name isEqualToString:@""] || [dev_name isEqualToString:@"\n"])
                dev_name = @"Untitled";
            
            NSString *dev_mac = [NSString stringWithFormat:@"%02x:%02x:%02x:%02x:%02x:%02x", dev.mac[0], dev.mac[1], dev.mac[2], dev.mac[3], dev.mac[4], dev.mac[5]];
            
            [cell setContent:dev_name mac:dev_mac type:0];
            
            break;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"Select at row %d", indexPath.row);
    m_picked = indexPath.row;
    
    return;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    NSLog(@"start to scan, &m_scanner=%p", &m_scanner);
    [m_scanner rtk_sc_start_scan];
    [discover_table reloadData];
    NSLog(@"done");
}

/*-----------------Handler timer-------------------*/
-(void)timerHandler: (id)sender
{
    [discover_table reloadData];
}
@end
