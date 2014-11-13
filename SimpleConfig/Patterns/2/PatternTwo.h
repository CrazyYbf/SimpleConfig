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

@interface PatternTwo : PatternBase 
{
@private
    unsigned char m_rand[4];
    NSString      *m_pin;
}
@property (nonatomic, strong) AsyncUdpSocket *m_configSocket;
@property (nonatomic, strong) AsyncUdpSocket *m_controlSocket;

@end
#endif
