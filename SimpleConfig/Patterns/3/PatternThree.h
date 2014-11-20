//
//  PatternThree.h
//  SimpleConfig
//
//  Created by Realsil on 14/11/12.
//  Copyright (c) 2014年 Realtek. All rights reserved.
//

#import "PatternBase.h"

/* Description:
 * Pattern 3 use multicast to send wifi profile with user-defined PIN code
 */
#define PATTERN_THREE_DBG       1
#define PATTERN_THREE_NAME      @"sc_mcast_udp"

@interface PatternThree : PatternBase
{
@private
    unsigned char m_rand[4];
}

@end
