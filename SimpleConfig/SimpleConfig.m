//
//  SimpleConfig.m
//  SimpleConfig
//
//  Created by Realsil on 14/11/6.
//  Copyright (c) 2014年 Realtek. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SimpleConfig.h"

@implementation SimpleConfig
@synthesize config_list, discover_list;

-(id)init
{
    m_mode = MODE_INIT;
    m_current_pattern = -1;
    m_shouldStop = false;
    m_timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(timerHandler:) userInfo:nil repeats:YES];
    config_list = [[NSMutableArray alloc] initWithObjects:nil];
    discover_list = [[NSMutableArray alloc] initWithObjects:nil];

    return [super init];
}

-(void)dealloc
{
    [config_list dealloc];
    [discover_list dealloc];
    for (int i=0; i<SC_MAX_PATTERN_NUM; i++) {
        if (m_pattern[i]!=nil) {
            [m_pattern[i] dealloc];
        }
    }
    
    // must stop timer!
    [m_timer invalidate];
    [m_timer release];
    [super dealloc];
}

-(void)rtk_sc_close_sock
{
    [m_pattern[m_current_pattern] rtk_sc_close_sock];
}

-(void)rtk_sc_reopen_sock
{
    [m_pattern[m_current_pattern] rtk_sc_reopen_sock];
}

-(int)rtk_sc_config_start: (NSString *)ssid psw:(NSString *)password pin:(NSString *)pin
{
    // actually we don't send here. It's timer handler's duty to send
    int ret;
    
    NSLog(@"rtk_sc_start_config");

    // base on the PIN input, decide to use Pattern
    if (pin==nil || [pin isEqualToString:@""] || [pin intValue]==0){
        m_pattern[PATTERN_TWO] = [[PatternTwo alloc] init:SC_USE_ENCRYPTION];
        m_current_pattern = PATTERN_TWO;
        m_pattern[PATTERN_THREE] = nil;
    }
    else{
        m_pattern[PATTERN_THREE] = [[PatternThree alloc] init:SC_USE_ENCRYPTION];
        m_current_pattern = PATTERN_THREE;
        m_pattern[PATTERN_TWO] = nil;
    }
    
    NSLog(@"simpleconfig: set pattern %d", m_current_pattern+1);
    ret = [m_pattern[m_current_pattern] rtk_pattern_build_profile:ssid psw:password pin:pin];
    if (ret==RTK_FAILED)
        return ret;
    
    [config_list removeAllObjects];
    m_shouldStop = false;
    m_mode = MODE_CONFIG;
    return ret;
}

-(void)rtk_sc_config_stop
{
    m_shouldStop = true;
}

-(int)rtk_sc_discover_start:(unsigned int)scan_time
{
    int ret = RTK_FAILED;
    // TODO
    return ret;
}

-(int) rtk_sc_control_start:(NSString *)client_mac type:(unsigned char)control_type
{
    int ret = RTK_FAILED;
    // TODO
    return ret;
}

-(unsigned int)rtk_sc_get_mode
{
    return m_mode;
}

/*-----------Private Funcs-------------*/
-(BOOL)haveSameMac:(unsigned char *)mac1 mac2:(unsigned char *)mac2
{
    if(mac1==nil || mac2==nil)
        return false;
    
    for(int i=0; i<MAC_ADDR_LEN; i++){
        if(mac1[i]==mac2[i])
            continue;
        else
            return false;
    }
    return true;
}

-(void)timerHandler:(id)sender
{
    int status = RTK_FAILED;
    unsigned int pattern_mode = [m_pattern[m_current_pattern] rtk_sc_get_mode];
    
    switch (m_mode) {
        case MODE_INIT:
            //NSLog(@"Standing by...");
            break;
            
        case MODE_CONFIG:
            if(m_shouldStop==false){
                // upper layer allows configuring
                if (pattern_mode==MODE_CONFIG) {
                    // send config profile
                    status = [m_pattern[m_current_pattern] rtk_pattern_send:[NSNumber numberWithInt:SC_SEND_ROUND_PER_SEC]];
                    if (status == RTK_FAILED) {
                        NSLog(@"Err1");
                        m_mode = MODE_ALERT;
                    }
                }else if(pattern_mode==MODE_WAIT_FOR_IP || pattern_mode==MODE_INIT){
                    m_mode = MODE_WAIT_FOR_IP;
                    // update config_list
                    NSMutableArray *recv_list = [m_pattern[m_current_pattern] rtk_pattern_get_config_list];
                    struct dev_info recv_dev;
                    NSValue *recv_dev_val = [recv_list objectAtIndex:[recv_list count]-1];
                    [recv_dev_val getValue:&recv_dev];
                    
                    if ([config_list count]>0) {
                        struct dev_info config_dev;
                        NSValue *config_dev_val = [config_list objectAtIndex:[config_list count]-1];
                        [config_dev_val getValue:&config_dev];
                        
                        if([self haveSameMac:recv_dev.mac mac2:config_dev.mac]==false)
                            [config_list addObject:[recv_list objectAtIndex:[recv_list count]-1]];
                    }else
                        [config_list addObject:[recv_list objectAtIndex:[recv_list count]-1]];
                }
                else{
                    NSLog(@"Err2");
                    m_mode = MODE_ALERT;
                }
            }else{
                // upper layer orders to stop, reset m_shouldStop flag
                m_shouldStop = false;
                m_mode = MODE_INIT;
            }
            break;
            
        case MODE_WAIT_FOR_IP:
            if(pattern_mode==MODE_INIT){
                // update config_list
                NSMutableArray *recv_list = [m_pattern[m_current_pattern] rtk_pattern_get_config_list];
                struct dev_info recv_dev;
                NSValue *recv_dev_val = [recv_list objectAtIndex:[recv_list count]-1];
                [recv_dev_val getValue:&recv_dev];
                
                struct dev_info config_dev;
                NSValue *config_dev_val = [config_list objectAtIndex:[config_list count]-1];
                [config_dev_val getValue:&config_dev];
                
                // check have same mac and have got ip address. If so, update
                if([self haveSameMac:recv_dev.mac mac2:config_dev.mac]==true && recv_dev.ip!=0){
                    [config_list replaceObjectAtIndex:[config_list count]-1 withObject:[recv_list objectAtIndex:[recv_list count]-1]];
                    m_mode = MODE_INIT;
                }
            }
            break;
            
        case MODE_DISCOVER:
            break;
            
        case MODE_ALERT:
            [self showAlert];
            m_mode = MODE_INIT;
            break;
            
        default:
            NSLog(@"Error UI mode!");
            break;
    }
}

-(void)showAlert
{
    if (m_mode == MODE_ALERT) {
        // garantee only MODE_ALERT can do this
        UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"Error" message:m_error delegate:self cancelButtonTitle:@"Stop" otherButtonTitles:nil, nil];
        [alert show];
    }
}
@end
