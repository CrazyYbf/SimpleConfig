//
//  PatternFour.h
//  SimpleConfig
//
//  Created by Realsil on 14/11/20.
//  Copyright (c) 2014年 Realtek. All rights reserved.
//

#import "PatternBase.h"

#define PATTERN_FOUR_DBG        0
#define PATTERN_FOUR_NAME       @"sc_mcast_udp"

@interface PatternFour : PatternBase
{
@private
    unsigned char m_rand[4];
}

@end
