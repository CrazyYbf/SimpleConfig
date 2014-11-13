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

#define SC_USE_ENCRYPTION           0
#define SC_NO_ENCRYPTION            PATTERN_USING_PLAIN

#define SC_SEND_ROUND_PER_SEC       10                      // send round per second
#define SC_MAX_PATTERN_NUM          4                       // currently only supports at most 4 patterns

@interface SimpleConfig : NSObject{
@private
    unsigned int    m_mode;                                 // simple config state machine
    unsigned int    m_current_pattern;                      // pattern in use
    BOOL            m_shouldStop;
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

@end

#endif
