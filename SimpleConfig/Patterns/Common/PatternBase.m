//
//  PatternBase.m
//  SimpleConfig
//
//  Created by Realsil on 14/11/6.
//  Copyright (c) 2014年 Realtek. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PatternBase.h"
#import <SystemConfiguration/CaptiveNetwork.h>

#include <errno.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/sysctl.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <net/if_dl.h>
#include <net/if.h>
#include <unistd.h>
#include <netdb.h>
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <fcntl.h>
#include <dlfcn.h>
#include <stdlib.h>
#include <string.h>

@implementation PatternBase

// initial
- (id)init: (unsigned int)pattern_flag
{
    NSLog(@"Base: init");
    // children will implement this function
    NSError *err;
    
    m_mode = MODE_INIT;
    /* init udp socket(multicast) */
    m_configSocket = [[AsyncUdpSocket alloc]initWithDelegate:self];
    [m_configSocket bindToPort:(LOCAL_PORT_NUM) error:&err]; //this port is udpSocket's port instead of dport
    [m_configSocket enableBroadcast:true error:&err];
    [m_configSocket receiveWithTimeout:-1 tag:0];
    
    /* init control socket(unicast) */
    m_controlSocket = [[AsyncUdpSocket alloc]initWithDelegate:self];
    [m_controlSocket bindToPort:(LOCAL_PORT_NUM) error:&err];
    [m_controlSocket receiveWithTimeout:-1 tag:0];
    
    /* init config result list */
    m_config_list = [[NSMutableArray alloc] initWithObjects:nil];
    m_security_level = SC_USE_ENCRYPTION;
    
    return [super init];
}

- (void)dealloc
{
    [m_configSocket dealloc];
    [m_controlSocket dealloc];
    [m_config_list dealloc];
    [m_pin release];
    
    [super dealloc];
}

- (unsigned int)rtk_sc_get_mode
{
    return m_mode;
}

- (void)rtk_sc_set_mode:(unsigned int)mode
{
    m_mode = mode;
}

- (void)rtk_sc_set_pin:(NSString *)pin
{
    m_pin = [[[NSString alloc] initWithString:pin] retain];
}

- (void)rtk_sc_close_sock
{
    NSLog(@"Base: rtk_sc_close_sock");
    [m_config_list removeAllObjects];
    
    if (![m_configSocket isClosed]) {
        NSLog(@"close config socket");
        [m_configSocket close];
        [m_configSocket release];
        m_configSocket = nil;
    }
    
    if (![m_controlSocket isClosed]) {
        NSLog(@"close control socket");
        [m_controlSocket close];
        [m_controlSocket release];
        m_controlSocket = nil;
    }
}

- (void)rtk_sc_reopen_sock
{
    NSLog(@"Base: rtk_sc_reopen_sock");
    m_mode = MODE_INIT;
    
    NSError *err;
    if ([m_configSocket isClosed]) {
        /* init udp socket(multicast) */
        NSLog(@"reopen config socket");
        m_configSocket = [[AsyncUdpSocket alloc]initWithDelegate:self];
        [m_configSocket bindToPort:(LOCAL_PORT_NUM) error:&err]; //this port is udpSocket's port instead of dport
        [m_configSocket enableBroadcast:true error:&err];
        [m_configSocket receiveWithTimeout:-1 tag:0];
    }
    
    if ([m_controlSocket isClosed]) {
        NSLog(@"reopen control socket");
        /* init control socket(unicast) */
        m_controlSocket = [[AsyncUdpSocket alloc]initWithDelegate:self];
        [m_controlSocket bindToPort:(LOCAL_PORT_NUM) error:&err];
        [m_controlSocket receiveWithTimeout:-1 tag:0];
    }
}

// simple config
/* Send interface 1 : send multicast data with payload length len */
- (int)udp_send_multi_data_interface: (unsigned int)ip len:(unsigned char)len
{
    AsyncUdpSocket *sock = [self rtk_sc_get_config_sock];
    if(sock == nil || [sock isClosed]){
        NSLog(@"udpSocket doesn't exist!!!");
        return RTK_FAILED;
    }
    
    int ret;
    NSError *err;
    
    char *payload = (char*)malloc((unsigned int)len);
    memset(payload, 0x31, len);
    NSData *data = [NSData dataWithBytes: payload length:(unsigned int)len];
    
    NSString *host = [[NSString alloc] initWithString:[NSString stringWithFormat:@"%d.%d.%d.%d", (ip>>24)&0xFF, (ip>>16)&0xFF, (ip>>8)&0xFF, ip&0xFF]];
    
    //NSLog(@"sendData 1......host=%@, port=%d", host, MCAST_PORT_NUM);
    [sock joinMulticastGroup:host error:&err];
    [sock receiveWithTimeout:-1 tag:0];
    BOOL result = [sock sendData:data toHost:host port:MCAST_PORT_NUM withTimeout:-1 tag:0];
    
    // deal with multicast send result
    if(!result)
        ret = RTK_FAILED;
    else
        ret = RTK_SUCCEED;
    
    host = nil;
    [host release];
    return ret;
}

/* Send interface 2 : send multicast data with payload */
- (int)udp_send_multi_data_interface: (unsigned int)ip payload: (NSData *)payload
{
    AsyncUdpSocket *sock = [self rtk_sc_get_config_sock];
    int ret;
    if(sock == nil){
        NSLog(@"udpSocket doesn't exist!!!");
        return -1;
    }
    NSError *err;
    NSString *host = [[NSString alloc] initWithString:[NSString stringWithFormat:@"%d.%d.%d.%d", (ip>>24)&0xFF, (ip>>16)&0xFF, (ip>>8)&0xFF, ip&0xFF]];
    
    //NSLog(@"sendData 2......host=%@, port=%d", host, MCAST_PORT_NUM);
    // send data by multicast
    [sock joinMulticastGroup:host error:&err];
    [sock receiveWithTimeout:-1 tag:0];
    BOOL result = [sock sendData:payload toHost:host  port:MCAST_PORT_NUM withTimeout:-1 tag:0];
    
    // deal with multicast send result
    if(!result)
        ret=RTK_FAILED;
    else
        ret=RTK_SUCCEED;
    
    host = nil;
    [host release];
    return ret;
}

/* Send interface 3 : send unicast data */
- (int)udp_send_unicast_interface: (unsigned int)ip payload: (NSData *)payload
{
    AsyncUdpSocket *sock = [self rtk_sc_get_control_sock];
    int ret = RTK_FAILED;
    
    NSString *host = [[NSString alloc] initWithString:[NSString stringWithFormat:@"%d.%d.%d.%d", (ip>>24)&0xFF, (ip>>16)&0xFF, (ip>>8)&0xFF, ip&0xFF]];
    //debug
    NSLog(@"sendData 3......host=%@, port=%d", host, UNICAST_PORT_NUM);
    
    [sock receiveWithTimeout:-1 tag:0];
    BOOL result = [sock sendData:payload toHost:host port:UNICAST_PORT_NUM withTimeout:-1 tag:0];
    if(!result)
        ret=RTK_FAILED;
    else
        ret=RTK_SUCCEED;
    
    host = nil;
    [host release];
    return ret;
}

/* Send interface 4: send broadcast data */
- (int)udp_send_bro_data_interface: (unsigned int)length
{
    int retval= RTK_FAILED;
    AsyncUdpSocket *sock = [self rtk_sc_get_config_sock];
    
    unsigned int ip = 0xffffffff;   // using broadcast ip 255.255.255.255

    unsigned char raw_msg[length];
    int val = 0;
    for (val=0; val<length; val++) {
        raw_msg[val] = 'a';
    }

    //NSString *msg = [[NSString alloc] initWithUTF8String:(const char *)raw_msg];
    
    //NSData *data = [msg dataUsingEncoding:NSUTF8StringEncoding];
    NSData *data = [NSData dataWithBytes:raw_msg length:length];
    NSString *host = [[NSString alloc] initWithString:[NSString stringWithFormat:@"%d.%d.%d.%d", (ip>>24)&0xFF, (ip>>16)&0xFF, (ip>>8)&0xFF, ip&0xFF]];
    
    // send data by broadcast
    //NSLog(@"sendData, length=0x%x(%d)", length, length);
    //[sock enableBroadcast:true error:&err];
    [sock receiveWithTimeout:-1 tag:0];
    
    BOOL ret = [sock sendData:data toHost:host  port:MCAST_PORT_NUM withTimeout:-1 tag:0];
    
    // deal with multicast send result
    if(!ret)
        retval = RTK_FAILED;
    else
        retval = RTK_SUCCEED;

    host = nil;
    [host release];
    return retval;
}

- (int)rtk_pattern_build_profile: (NSString *)ssid psw:(NSString *)password pin:(NSString *)pin
{
    // children will implement this function
    return RTK_FAILED;
}
- (int)rtk_pattern_send: (NSNumber *)times
{
    // children will implement this function
    return RTK_FAILED;
}

/* Pattern two send ACK-ACK */
- (int)rtk_pattern_send_ack_packets
{
    unsigned int buffer[MAX_BUF_LEN] = {0x0};
    int len = 0, ret = RTK_FAILED;
    /* Flag */
    unsigned char flag = REQ_ACK; // full 0 char means request to report(scan)
    memcpy(buffer+len, &flag, 1);
    len += 1;
    
    /* Security Level */
    unsigned char security = m_security_level;
    memcpy(buffer+len, &security, 1);
    len += 1;
    
    /* Length: not included flag and length */
    unsigned char length[2] = {0x0};
    length[1] = SCAN_DATA_LEN-1-1-2; //exclude flag, security level and length
    memcpy(buffer+len, length, 2);
    len += 2;
    
    /* Nonce: a random value */
    unsigned char nonce[64] = {0x0};
    int nonce_idx = 0;
    for (nonce_idx=0; nonce_idx<64; nonce_idx++) {
        nonce[nonce_idx] = 65 + rand()%26;
        //NSLog(@"[%d]: %02x", nonce_idx, nonce[nonce_idx]);
    }
    memcpy(buffer+len, nonce, 64);
    len += 64;
    
    /* MD5 digest, plain buffer is nonce+default_pin */
    unsigned char md5_result[16] = {0x0};
    //NSLog(@"m_pin : %@", m_pin);
    NSString *pin = m_pin;
    const unsigned char *default_pin_char = (const unsigned char *)[pin cStringUsingEncoding:NSUTF8StringEncoding];
    unsigned int default_pin_len = (unsigned int)(strlen((const char *)default_pin_char));
    //NSLog(@"default_pin_char is(%d) %s", default_pin_len, default_pin_char);
    unsigned char md5_buffer[64+64] = {0x0};//note: default pin max length is 64 bytes
    memcpy(md5_buffer, nonce, 64);
    memcpy(md5_buffer+64, default_pin_char, default_pin_len);
    //NSLog(@"md5_plain buffer is(%d) %s", (int)strlen((const char *)md5_buffer), md5_buffer);
    CC_MD5(md5_buffer, 64+default_pin_len , md5_result);
    //NSLog(@"md5_encrypt result: %02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x", md5_result[0],md5_result[1],md5_result[2],md5_result[3],md5_result[4],md5_result[5],md5_result[6],md5_result[7],md5_result[8],md5_result[9],md5_result[10],md5_result[11],md5_result[12],md5_result[13],md5_result[14],md5_result[15]);
    
    memcpy(buffer+len, md5_result, 16);
    len += 16;
    
    /* Source MAC Address */
    unsigned char sa[6] = {0xff, 0xff, 0xff, 0xff, 0xff, 0xff}; // full FF means send to all possible devices
    memcpy(buffer+len, sa, 6);
    len += 6;
    
    /* Device Type */
    unsigned char deviceType[2] = {0xff, 0xff};
    memcpy(buffer+len, deviceType, 2);
    len += 2;
    
    /* save m_scan_buf to m_discover_data */
    NSInteger size = SCAN_DATA_LEN;
    NSData *ack_data = [NSData dataWithBytes:(const void*)buffer length:size];
    
    NSLog(@"Send ack multicast!");
    ret = [self udp_send_multi_data_interface:0xFFFFFFFF payload:ack_data];
    
    return ret;
}

/* send ack-ack unicast */
- (int)rtk_pattern_send_ack_packets:(unsigned int) ip
{
    unsigned int buffer[MAX_BUF_LEN] = {0x0};
    int len = 0, ret = RTK_FAILED;
    /* Flag */
    unsigned char flag = REQ_ACK; // full 0 char means request to report(scan)
    memcpy(buffer+len, &flag, 1);
    len += 1;
    
    /* Security Level */
    unsigned char security = m_security_level;
    memcpy(buffer+len, &security, 1);
    len += 1;
    
    /* Length: not included flag and length */
    unsigned char length[2] = {0x0};
    length[1] = SCAN_DATA_LEN-1-1-2; //exclude flag, security level and length
    memcpy(buffer+len, length, 2);
    len += 2;
    
    /* Nonce: a random value */
    unsigned char nonce[64] = {0x0};
    int nonce_idx = 0;
    for (nonce_idx=0; nonce_idx<64; nonce_idx++) {
        nonce[nonce_idx] = 65 + rand()%26;
        //NSLog(@"[%d]: %02x", nonce_idx, nonce[nonce_idx]);
    }
    memcpy(buffer+len, nonce, 64);
    len += 64;
    
    /* MD5 digest, plain buffer is nonce+default_pin */
    unsigned char md5_result[16] = {0x0};
    //NSLog(@"m_pin : %@", m_pin);
    NSString *pin = m_pin;
    const unsigned char *default_pin_char = (const unsigned char *)[pin cStringUsingEncoding:NSUTF8StringEncoding];
    unsigned int default_pin_len = (unsigned int)(strlen((const char *)default_pin_char));
    //NSLog(@"default_pin_char is(%d) %s", default_pin_len, default_pin_char);
    unsigned char md5_buffer[64+64] = {0x0};//note: default pin max length is 64 bytes
    memcpy(md5_buffer, nonce, 64);
    memcpy(md5_buffer+64, default_pin_char, default_pin_len);
    //NSLog(@"md5_plain buffer is(%d) %s", (int)strlen((const char *)md5_buffer), md5_buffer);
    CC_MD5(md5_buffer, 64+default_pin_len , md5_result);
    //NSLog(@"md5_encrypt result: %02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x", md5_result[0],md5_result[1],md5_result[2],md5_result[3],md5_result[4],md5_result[5],md5_result[6],md5_result[7],md5_result[8],md5_result[9],md5_result[10],md5_result[11],md5_result[12],md5_result[13],md5_result[14],md5_result[15]);
    
    memcpy(buffer+len, md5_result, 16);
    len += 16;
    
    /* Source MAC Address */
    unsigned char sa[6] = {0xff, 0xff, 0xff, 0xff, 0xff, 0xff}; // full FF means send to all possible devices
    memcpy(buffer+len, sa, 6);
    len += 6;
    
    /* Device Type */
    unsigned char deviceType[2] = {0xff, 0xff};
    memcpy(buffer+len, deviceType, 2);
    len += 2;
    
    /* save m_scan_buf to m_discover_data */
    NSInteger size = SCAN_DATA_LEN;
    NSData *ack_data = [NSData dataWithBytes:(const void*)buffer length:size];
    
    NSLog(@"Send ack to %x", ip);
    ret = [self udp_send_unicast_interface:ip payload:ack_data];
    
    return ret;
}

- (void)rtk_pattern_stop
{
    // empty
}

- (int)rtk_get_connected_sta_num
{
    // children will implement this function
    return RTK_FAILED;
}
- (NSMutableArray *)rtk_get_connected_sta_mac
{
    // children will implement this function
    return nil;
}

// helper functions
- (unsigned int)getLocalIPAddress
{
    NSString        *address = @"error";
    struct ifaddrs  *interfaces = NULL;
    struct ifaddrs  *temp_addr = NULL;
    const char      *wifi_ip_char;
    unsigned int    wifi_ip = 0;
    int             success = 0;
    
    int count = 0;
    int bits = 0; //for sub_wifi_ip
    int bytes = 0; //for sub
    char sub_wifi_ip[3] = {0x30};//at most 3 byte of IP address format, e,g 192.
    unsigned char sub[4] = {0x0}; // four bytes for wifi_ip
    
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    
    if (success == 0) {
        // Loop through linked list of interfaces
        
        temp_addr = interfaces;
        while(temp_addr != NULL) {
            
            if(temp_addr->ifa_addr->sa_family == AF_INET) {
                // Check if interface is en0 which is the wifi connection on the iPhone
                // it may also be en1 on your ipad3.
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    // Get NSString from C String
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            
            temp_addr = temp_addr->ifa_next;
        }
    }
    // Free memory
    freeifaddrs(interfaces);

    wifi_ip_char = [address UTF8String];
    NSLog(@"address=%@, wifi_ip_char=%s", address, wifi_ip_char);
    if ([address isEqualToString:@"error"]) {
#define SC_ERR_LOCAL_IP     0
        return SC_ERR_LOCAL_IP;
    }
    while(1)
    {
        if(((wifi_ip_char[count]!='.')&&(bytes<3)) || ((bytes==3)&&(wifi_ip_char[count]!='\0')) )
        {
            sub_wifi_ip[bits] = wifi_ip_char[count];
            //NSLog(@"sub_wifi_ip[%d]=%02x", bits, wifi_ip_char[count]);
            bits++;
            count++;
            continue;
        }else{
            int i = 0;
            for (i=0; i<3; i++) {
                //NSLog(@"sub_wifi_ip[%d]=%02x", i, sub_wifi_ip[i]);
            }
            if (bits==1) {
                sub[bytes] = sub_wifi_ip[0]-0x30;
            }else if(bits==2){
                sub[bytes] = 10 * (sub_wifi_ip[0]-0x30) + (sub_wifi_ip[1]-0x30);
            }else if(bits==3){
                sub[bytes] = 100 * (sub_wifi_ip[0]-0x30) + 10 * (sub_wifi_ip[1]-0x30) + (sub_wifi_ip[2]-0x30);
            }
            //NSLog(@"sub[%d]=%d",bytes, sub[bytes]);
            bits=0;
            bytes++;
            count++;
            memset(sub_wifi_ip, 0x30, 3);
        }
        if(bytes==4)
            break;
    }
    
    wifi_ip = (sub[0]<<24) + (sub[1]<<16) + (sub[2]<<8) + sub[3];
    NSLog(@"wifi ip=%x",wifi_ip);
    return wifi_ip;
}

- (NSString *)getMACAddress: (char *)if_name
{
    if(if_name==nil)
        return @"Error in getMACAddress: argument fault";
    int mib[6];
    size_t len;
    char *buf;
    unsigned char *ptr;
    struct if_msghdr *ifm;
    struct sockaddr_dl *sdl;
    
    mib[0] = CTL_NET;
    mib[1] = AF_ROUTE;
    mib[2] = 0;
    mib[3] = AF_LINK;
    mib[4] = NET_RT_IFLIST;
    
    if ((mib[5] = if_nametoindex(if_name)) == 0) {
        printf("Error: if_nametoindex error/n");
        return NULL;
    }
    
    if (sysctl(mib, 6, NULL, &len, NULL, 0) < 0) {
        printf("Error: sysctl, take 1/n");
        return NULL;
    }
    
    if ((buf = malloc(len)) == NULL) {
        printf("Could not allocate memory. error!/n");
        return NULL;
    }
    
    if (sysctl(mib, 6, buf, &len, NULL, 0) < 0) {
        printf("Error: sysctl, take 2");
        return NULL;
    }
    
    ifm = (struct if_msghdr *)buf;
    sdl = (struct sockaddr_dl *)(ifm + 1);
    ptr = (unsigned char *)LLADDR(sdl);
    //NSString *outstring = [NSString stringWithFormat:@"%02x:%02x:%02x:%02x:%02x:%02x", *ptr, *(ptr+1), *(ptr+2), *(ptr+3), *(ptr+4), *(ptr+5)];
    NSString *outstring = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x", *ptr, *(ptr+1), *(ptr+2), *(ptr+3), *(ptr+4), *(ptr+5)];
    NSLog(@"getMACAddress:%@", [outstring uppercaseString]);
    free(buf);
    return [outstring uppercaseString];
}

/* Format change: ch0 ch1 to one char,eg: ch0='A' ch1='4' ret='A4'
 * Note that ch0 and ch1 can both be 0-f in hex.
 */
- (unsigned char)format_change: (unsigned char)ch0 ch1:(unsigned char)ch1
{
    unsigned char ret = 0x0;
    if ((ch0>='0')&&(ch0<='9')) {
        ret = ret | (ch0<<4);
    }else
        ret = ret | ((ch0-0x37)<<4);
    
    if((ch1>='0')&&(ch1<='9'))
        ret = ret | (ch1&0x0F);
    else
        ret = ret | (ch1-0x37);
    
    return ret;
}

/* Checksum algorithem */
- (unsigned char)CKSUM:(unsigned char *)data len:(int)len
{
    int i;
    unsigned char sum = 0;
    for(i=0; i<len; i++)
        sum += data[i];
    sum = ~sum + 1;
    return sum;
}

- (int)CKSUM_OK:(unsigned char *)data len:(int)len
{
    int i;
    unsigned char sum=0;
    
    for (i=0; i<len; i++)
        sum += data[i];
    
    if (sum == 0)
        return 1;
    else
        return 0;
}

/* dump buffer with length len */
- (void)rtk_dump_buffer:(unsigned char *)arr len:(int)len
{
    if(arr==nil)
        return;
    
    int count=0;
    for (count=0; count<len; count++) {
        NSLog(@"[%d]%02x", count, arr[count]);
    }
}

/* generate 4 bytes randome number */
- (void)gen_random: (unsigned char *)m_random
{
    // children will implement this function
}

- (NSMutableArray *)rtk_pattern_get_config_list
{
    return m_config_list;
}

- (AsyncUdpSocket *)rtk_sc_get_config_sock
{
    return m_configSocket;
}

- (AsyncUdpSocket *)rtk_sc_get_control_sock
{
    return m_controlSocket;
}

/* ***********************Receive Delegate************************** */
-(void) dump_dev_info: (struct dev_info *)dev
{
    NSLog(@"======Dump dev_info======");
    NSLog(@"MAC: %02x:%02x:%02x:%02x:%02x:%02x", dev->mac[0], dev->mac[1],dev->mac[2],dev->mac[3],dev->mac[4],dev->mac[5]);
    NSLog(@"Status: %d", dev->status);
    NSLog(@"Device type: %d", dev->dev_type);
    NSLog(@"IP:%x", dev->ip);
    //NSLog(@"Name:%@", [NSString stringWithUTF8String:(const char *)(dev->extra_info)]);
    NSLog(@"Name:%@", [NSString stringWithCString:(const char *)(dev->extra_info) encoding:NSUTF8StringEncoding]);
}

-(void) build_dev_info:(struct dev_info *)new_dev data_p: (unsigned char *)data_p len: (unsigned int)len
{
    memcpy(new_dev->mac, data_p+ACK_OFFSET_MAC, MAC_ADDR_LEN);
    new_dev->status = data_p[ACK_OFFSET_STATUS];
    
    unsigned char type_translator[2]={0x0};
    type_translator[1] = *(data_p+ACK_OFFSET_DEV_TYPE);
    type_translator[0] = *(data_p+ACK_OFFSET_DEV_TYPE+1);
    memcpy(&new_dev->dev_type, type_translator, 2);
    
    unsigned char ip_translator[4]={0x0};
    ip_translator[3]=*(data_p+ACK_OFFSET_IP);
    ip_translator[2]=*(data_p+ACK_OFFSET_IP+1);
    ip_translator[1]=*(data_p+ACK_OFFSET_IP+2);
    ip_translator[0]=*(data_p+ACK_OFFSET_IP+3);
    memcpy(&new_dev->ip, ip_translator, 4);
    
    memcpy(&new_dev->extra_info, data_p+ACK_OFFSET_DEV_NAME, len-MAC_ADDR_LEN-1-2-4);
    
    [self dump_dev_info:new_dev];
}

/* update the received data to m_config_list */
-(int)updateConfigList: (unsigned char *)data_p len:(unsigned int)data_length
{
    int getIP = 0, exist = 0, i=0;
    struct dev_info old_dev;
    NSValue *old_dev_val;
    int dev_total_num = (int)[m_config_list count];
    
    // no dev_info exist
    if (dev_total_num==0)
        goto AddNewObj;
    
    // have dev_info
    for (i=0; i<dev_total_num; i++) {
        old_dev_val = [m_config_list objectAtIndex:i];
        [old_dev_val getValue:&old_dev];
        
        if(!memcmp(old_dev.mac, data_p+ACK_OFFSET_MAC, MAC_ADDR_LEN)){
            // have the same mac dev in list, index is i.
            exist = 1;
            break;
        }
    }
    
    if (exist) {
        // have dev with same mac
        NSLog(@"exist this mac at index %d", i);
        unsigned char ip_translator[4]={0x0};
        ip_translator[3]=*(data_p+ACK_OFFSET_IP);
        ip_translator[2]=*(data_p+ACK_OFFSET_IP+1);
        ip_translator[1]=*(data_p+ACK_OFFSET_IP+2);
        ip_translator[0]=*(data_p+ACK_OFFSET_IP+3);
        memcpy(&old_dev.ip, ip_translator, 4);
#if SC_DBG_CONFIG_RECV
        [self dump_dev_info:&old_dev];
#endif
        if (old_dev.ip!=0) {
            // ack2, got ip, update config_list at index i and send ack-ack2
            getIP = 1;
            NSValue *new_val = [NSValue valueWithBytes:&old_dev objCType:@encode(struct dev_info)];
            [m_config_list replaceObjectAtIndex:i withObject:new_val];
            [self rtk_pattern_send_ack_packets:old_dev.ip];
        }else{
            // ack-ack1, too many from client, just reply multicast
            getIP = 0;
            [self rtk_pattern_send_ack_packets];
        }
        
        return getIP;
    }
    
AddNewObj:
    {
        // new mac
        NSLog(@"Add new object");
        struct dev_info new_dev;
        [self build_dev_info:&new_dev data_p:data_p len:data_length];
        NSValue *new_val = [NSValue valueWithBytes:&new_dev objCType:@encode(struct dev_info)];
        [m_config_list addObject:new_val];
        
        // send ack-ack, and change operation mode
        if (new_dev.ip==0){
            getIP = 0;
            [self rtk_pattern_send_ack_packets];
        }
        else{
            getIP = 1;
            [self rtk_pattern_send_ack_packets:new_dev.ip];
        }
        
        return getIP;
    }
}

- (BOOL)onUdpSocket:(AsyncSocket *)sock didReceiveData:(NSData *)data withTag:(long)tag fromHost:(NSString *)host port:(UInt16)port
{
    if (host==nil) {
        return NO;
    }
    NSLog(@"=============Base: Receive from host %@ port %d==================", host, port);
    
    /* step 1: get the received data */
    unsigned char flag;
    unsigned char *data_p = (unsigned char*)[data bytes];
    if (data_p == nil) {
        NSLog(@"data received is nil!!!");
        return NO;
    }
    unsigned int data_length = (unsigned int)(data_p[2]);
    flag = data_p[0];
    
#if SC_DBG_CONFIG_RECV
    NSLog(@"data in udp is %ld bytes: ", (unsigned long)[data length]);
    for (int recv_idx=0; recv_idx<(data_length+3); recv_idx++) {
        NSLog(@"[%d]: %02x", recv_idx, data_p[recv_idx]);
    }
    NSLog(@"m_mode=%d", m_mode);
#endif
    
    /* step 2: parse the data flag */
    switch (m_mode) {
        case MODE_INIT:
            if (flag==RSP_CONFIG) {
                // whatever happens, don't update mode here.
                [self updateConfigList:data_p len:data_length];
            }
            break;
            
        case MODE_CONFIG:
            // configuring mode, wait for config ack1(maybe have ip, then it's ack2)
            if (flag==RSP_CONFIG) {
                // add new config device info to m_config_list
                if ([self updateConfigList:data_p len:data_length])
                    m_mode = MODE_INIT;
                else
                    m_mode = MODE_WAIT_FOR_IP;
            }// ignore other received data
            break;
            
        case MODE_WAIT_FOR_IP:
            if (flag==RSP_CONFIG) {
                /* 1. It's config ack2. check mac address is still the same. If so, only update ip address of dev_info
                 * 2. Other clients reply ack
                 */
                if ([self updateConfigList:data_p len:data_length])
                    m_mode = MODE_INIT;
            }
            break;
            
        default:
            break;
    }
    
    return TRUE;
}

@end
