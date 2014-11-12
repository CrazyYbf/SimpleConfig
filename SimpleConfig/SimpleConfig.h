//
//  SimpleConfig.h
//  SimpleConfig
//
//  Created by Realsil on 14/11/6.
//  Copyright (c) 2014年 Realtek. All rights reserved.
//

#ifndef SimpleConfig_SimpleConfig_h
#define SimpleConfig_SimpleConfig_h
#import <UIKit/UIKit.h>
#import "Defines.h"
#import "PatternBase.h"
#import "PatternTwo.h"

#define SC_USE_ENCRYPTION           0
#define SC_NO_ENCRYPTION            PATTERN_USING_PLAIN

#define PATTERN_TWO_SEND_PER_SEC    1                       // send round per second
#define MAX_PATTERN_NUM             4                       // currently only supports at most 4 patterns

@interface SimpleConfig : NSObject{
@private
    unsigned int    m_mode;
    BOOL            m_shouldStop;
    NSTimer         *m_timer;
    NSString        *m_error;
    PatternBase     *m_pattern[MAX_PATTERN_NUM];
}

@property (strong, nonatomic) NSMutableArray *config_list;    // clients list that sent config ack
@property (strong, nonatomic) NSMutableArray *discover_list;  // clients list that send discover ack

-(id)  init;
-(int) rtk_sc_config_start:(NSString *)ssid psw:(NSString *)password pin:(NSString *)pin;
-(void)rtk_sc_config_stop;
-(int) rtk_sc_discover_start:(unsigned int)scan_time;
-(int) rtk_sc_control_start:(NSString *)client_mac type:(unsigned char)control_type;
-(unsigned int)rtk_sc_get_mode;

@end


#if 0
-(id)   initPattern: (unsigned int)pattern_num;             // init pattern
-(int)  rtk_sc_start_config: (NSString *)ssid psw:(NSString *)password pin:(NSString *)pin; //generate profile and send one round(SEND_ROUND times)
-(int)  rtk_sc_keep_config;                                 // only send profile! Be careful when using
-(void) rtk_sc_stop_config;                                 // stop configuring manually
-(unsigned char *)rtk_sc_check_receive: (unsigned int *)len;// fetch receive information
-(int)  rtk_sc_multi_ack_resp;                              // multicast ack-ack
-(int)  rtk_sc_unicast_ack_resp: (unsigned int)ip;          // unicast ack-ack
#endif

#endif
