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
    
    NSMutableArray      *m_config_list;                         // clients list that sent config ack
    NSMutableArray      *m_discover_list;                       // clients list that send discover ack
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
- (NSMutableArray *)rtk_pattern_get_discover_list;

// discovery
- (int)     rtk_get_connected_sta_num;
- (NSMutableArray *) rtk_get_connected_sta_mac;

// device control
- (void)    rtk_sc_clear_device_list;
- (NSData *)rtk_sc_gen_discover_packet;
- (void)    rtk_sc_send_discover_packet: (NSData *)data ip:(unsigned int)ip;
- (NSMutableArray *)rtk_sc_get_discovered_devices;
- (NSData *)rtk_sc_gen_control_packet: (unsigned int)control_type;
- (void)    rtk_sc_send_control_packet: (NSData *)data ip:(unsigned int)ip;
- (NSData *)rtk_sc_gen_rename_dev_packet: (NSString *)dev_name;
- (void)    rtk_sc_send_rename_dev_packet: (NSData *)data ip:(unsigned int)ip;
- (void)    rtk_sc_set_control_pin: (NSString *)pin;
- (void)    rtk_sc_reset_control_pin;
- (int)     rtk_sc_get_control_result;
- (void)    rtk_sc_reset_control_result;

// helper functions
- (unsigned int)getLocalIPAddress;
- (NSString *)getMACAddress: (char *)if_name;
- (unsigned char)format_change: (unsigned char)ch0 ch1:(unsigned char)ch1;
- (void)gen_random: (unsigned char *)m_random;
- (void)rtk_dump_buffer:(unsigned char *)arr len:(int)len;
- (unsigned char)CKSUM:(unsigned char *)data len:(int)len;
- (int)CKSUM_OK:(unsigned char *)data len:(int)len;

// debug functions
@end
#endif
