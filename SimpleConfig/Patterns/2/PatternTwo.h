//
//  PatternTwo.h
//  SimpleConfig
//
//  Created by Realsil on 14/11/6.
//  Copyright (c) 2014年 Realtek. All rights reserved.
//

#ifndef SimpleConfig_PatternTwo_h
#define SimpleConfig_PatternTwo_h
#import "../Common/PatternBase.h"

#define PATTERN_TWO_DBG     1
#define PATTERN_TWO_NAME    @"sc_mcast_udp"

/* Description:
 * Pattern 2 use multicast to send wifi profile with default PIN code
 */

typedef enum{
    MODE_INIT = 0,
    MODE_CONFIG,
    MODE_WAIT_FOR_IP,
    MODE_DISCOVER,
    MODE_CONTROL,
    MODE_ALERT,
}PatternModes;

@interface PatternTwo : PatternBase 
{
@private
    unsigned char m_rand[4];
}

@property (nonatomic, strong) AsyncUdpSocket *m_configSocket;
@property (nonatomic, strong) AsyncUdpSocket *m_controlSocket;

@end
#endif
