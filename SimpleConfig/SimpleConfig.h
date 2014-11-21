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
#import "PatternTwo.h"
#import "PatternThree.h"
#import "PatternFour.h"

#define SC_SEND_ROUND_PER_SEC       10                      // send round per second
#define SC_MAX_PATTERN_NUM          4                       // currently only supports at most 4 patterns

#define SC_SUPPORT_2X2              1                       // support 2x2 wifi
#define SC_PATTERN_SWITCH_THRESHOLD 5                      // time(in seconds) to switch configuring mode

@interface SimpleConfig : NSObject{
@private
    BOOL            m_shouldStop;
    unsigned int    m_mode;                                 // simple config state machine
    unsigned int    m_current_pattern;                      // pattern in use
#if SC_SUPPORT_2X2
    int             m_config_duration;                      // duration of MODE_CONFIG
    NSString        *m_ssid;                                // must record to rebuild profile
    NSString        *m_password;
    NSString        *m_pin;
    NSString        *m_idev_model;                          // iDevice model
#endif

    NSTimer         *m_timer;
    NSString        *m_error;
    PatternBase     *m_pattern[SC_MAX_PATTERN_NUM];
}

@property (strong, nonatomic) NSMutableArray *config_list;    // clients list that sent config ack
@property (strong, nonatomic) NSMutableArray *discover_list;  // clients list that send discover ack

-(id)  init;
-(int) rtk_sc_config_start:(NSString *)ssid psw:(NSString *)password pin:(NSString *)pin;
-(void)rtk_sc_config_stop;
-(int) rtk_sc_discover_start:(unsigned int)scan_time;
-(int) rtk_sc_control_start:(NSString *)client_mac type:(unsigned char)control_type;

-(unsigned int)rtk_sc_get_mode;
-(void)rtk_sc_close_sock;
-(void)rtk_sc_reopen_sock;

@end

#endif
