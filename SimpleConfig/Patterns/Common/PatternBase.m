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
    // children will implement this function
    return [super init];
}

- (unsigned int)rtk_sc_get_mode
{
    return m_mode;
}

// simple config
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
- (int)rtk_pattern_send_ack_packets
{
    // children will implement this function
    return RTK_FAILED;
}
- (int)rtk_pattern_send_ack_packets:(unsigned int) ip
{
    // children will implement this function
    return RTK_FAILED;
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

#if 0
// device control
- (void)rtk_sc_clear_device_list
{
    // children will implement this function
}
- (NSData *)rtk_sc_gen_discover_packet
{
    // children will implement this function
    return nil;
}
- (void)rtk_sc_send_discover_packet: (NSData *)data ip:(unsigned int)ip
{
    // children will implement this function
}
- (NSMutableArray *)rtk_sc_get_discovered_devices
{
    // children will implement this function
    return nil;
}
- (NSData *)rtk_sc_gen_control_packet: (unsigned int)control_type
{
    // children will implement this function
    return nil;
}
- (void)rtk_sc_send_control_packet: (NSData *)data ip:(unsigned int)ip
{
    // children will implement this function
}
- (NSData *)rtk_sc_gen_rename_dev_packet: (NSString *)dev_name
{
    // children will implement this function
    return nil;
}
- (void)rtk_sc_send_rename_dev_packet: (NSData *)data ip:(unsigned int)ip
{
    // children will implement this function
}
- (void)rtk_sc_set_control_pin: (NSString *)pin
{
    // children will implement this function
}
- (void)rtk_sc_reset_control_pin
{
    // children will implement this function
}
- (int)rtk_sc_get_control_result
{
    // children will implement this function
    return RTK_FAILED;
}
- (void)rtk_sc_reset_control_result
{
    // children will implement this function
}
#endif

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
    return nil;
}

- (void)rtk_sc_close_sock
{
    // children will implement this function
}

- (void)rtk_sc_reopen_sock
{
    // children will implement this function
}
@end
