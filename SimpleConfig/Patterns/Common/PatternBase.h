//
//  PatternBase.h
//  SimpleConfig
//
//  Created by Realsil on 14/11/6.
//  Copyright (c) 2014年 Realtek. All rights reserved.
//

#ifndef SimpleConfig_PatternBase_h
#define SimpleConfig_PatternBase_h
#import "Defines.h"
#import "AsyncUdpSocket.h"
#import "AsyncSocket.h"

@interface PatternBase : NSObject <AsyncUdpSocketDelegate>
{
@public
    NSString            *m_pattern_name;                        //pattern name
    NSNumber            *m_pattern_flag;                        //pattern flag, indicating using encrpytion and else
    
    unsigned int        m_key_len;                              //length of AES Key
    unsigned int        m_crypt_len;                            //length of crypted profile
    unsigned int        m_plain_len;                            //length of plain profile
    unsigned char       m_aes_key_buf[MAX_AES_KEY_LEN];         //store Key for AES
    unsigned char       m_crypt_buf[MAX_BUF_LEN];               //store crytped profile
    unsigned char       m_plain_buf[MAX_BUF_LEN];               //store plain profile
    
    unsigned char       m_security_level;                       //security level for control
    
    unsigned char       m_send_buf[MAX_BUF_LEN];                //data to send
    
    unsigned int        m_mode;                                 //current mode
    NSString            *m_pin;                                 //PIN code if needed
    NSMutableArray      *m_config_list;                         //clients list that sent config ack
    AsyncUdpSocket      *m_configSocket;                        //multicast socket
    AsyncUdpSocket      *m_controlSocket;                       //unicast socket(for ack)
}

// External APIs
// initial
- (id)    init: (unsigned int)pattern_flag;
- (unsigned int)rtk_sc_get_mode;

// simple config
- (int)     rtk_pattern_build_profile: (NSString *)ssid psw:(NSString *)password pin:(NSString *)pin;
- (int)     rtk_pattern_send: (NSNumber *)times;
- (int)     rtk_pattern_send_ack_packets;
- (int)     rtk_pattern_send_ack_packets: (unsigned int) ip;
- (void)    rtk_pattern_stop;
- (NSMutableArray *)rtk_pattern_get_config_list;

// discovery
- (int)     rtk_get_connected_sta_num;
- (NSMutableArray *) rtk_get_connected_sta_mac;

// helper functions
- (unsigned int)getLocalIPAddress;
- (NSString *)getMACAddress: (char *)if_name;
- (unsigned char)format_change: (unsigned char)ch0 ch1:(unsigned char)ch1;
- (void)gen_random: (unsigned char *)m_random;
- (void)rtk_dump_buffer:(unsigned char *)arr len:(int)len;
- (unsigned char)CKSUM:(unsigned char *)data len:(int)len;
- (int)CKSUM_OK:(unsigned char *)data len:(int)len;
- (void)rtk_sc_close_sock;
- (void)rtk_sc_reopen_sock;
- (void)rtk_sc_set_mode: (unsigned int)mode;
- (void)rtk_sc_set_pin: (NSString *)pin;
- (AsyncUdpSocket *)rtk_sc_get_config_sock;
- (AsyncUdpSocket *)rtk_sc_get_control_sock;
- (int)udp_send_multi_data_interface: (unsigned int)ip len:(unsigned char)len;
- (int)udp_send_multi_data_interface: (unsigned int)ip payload: (NSData *)payload;
- (int)udp_send_unicast_interface: (unsigned int)ip payload: (NSData *)payload;
- (int)udp_send_bro_data_interface: (unsigned int)length;

// debug functions
@end
#endif
