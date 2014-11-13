//
//  PatternThree.m
//  SimpleConfig
//
//  Created by Realsil on 14/11/12.
//  Copyright (c) 2014年 Realtek. All rights reserved.
//

#import "PatternThree.h"
#import <Foundation/Foundation.h>
#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonHMAC.h>

// private definitions
const char *pattern_three_nonce_buffer="8CmT/ J(3_aE R_UFR}`mtwF=)Qfjtn^S_1/ffg<_C7yw's}?'_'n&2~Blm&_k?6";
unsigned char pattern_three_key_iv[] = {0xA6,0xA6,0xA6,0xA6,0xA6,0xA6,0xA6,0xA6,0xA6};
#define BLKSIZE8                    (8)
#define BLKSIZE                     (16)
#define AES_WRAP_TIME               (6)
typedef union _block{
    unsigned int x[BLKSIZE/4];
    unsigned char b[BLKSIZE];
}block;

#define PATTERN_THREE_SYNC_PKT_NUM    9
#define PATTERN_THREE_SEQ_IDX         3
#define PATTERN_THREE_ID_IDX          5
#define PATTERN_THREE_DATA_IDX        5
#define PATTERN_THREE_RANDOM_IDX      5
#define PATTERN_THREE_CKSUM_IDX       4
#define PATTERN_THREE_MAGIC_IDX0      3
#define PATTERN_THREE_MAGIC_IDX1      4
#define PATTERN_THREE_MAGIC_IDX2      5
#define PATTERN_THREE_MAGIC_IDX3      5
#define PATTERN_THREE_SEND_TIME       10
#define PATTERN_THREE_RECEIVE_TIMEOUT 120

@implementation PatternThree
@synthesize m_configSocket, m_controlSocket;

// initial
- (id)init: (unsigned int)pattern_flag
{
    NSLog(@"PATTERN 3: init, &m_mode=%p", &m_mode);
    NSError *err;
    
    /* init arguments */
    m_pattern_name = PATTERN_THREE_NAME;
    m_pattern_flag = [NSNumber numberWithInt: pattern_flag];
    m_mode = MODE_INIT;
    
    m_plain_len = m_key_len = m_crypt_len = 0;
    memset(m_aes_key_buf, 0x0, MAX_AES_KEY_LEN);
    memset(m_crypt_buf, 0x0, MAX_BUF_LEN);
    memset(m_plain_buf, 0x0, MAX_BUF_LEN);
    memset(m_send_buf, 0x0, MAX_BUF_LEN);
    
    m_config_list = [[NSMutableArray alloc] initWithObjects:nil];
    m_discover_list = [[NSMutableArray alloc] initWithObjects:nil];
    
    /* init udp socket(multicast) */
    m_configSocket = [[AsyncUdpSocket alloc]initWithDelegate:self];
    [m_configSocket bindToPort:(LOCAL_PORT_NUM) error:&err]; //this port is udpSocket's port instead of dport
    [m_configSocket enableBroadcast:true error:&err];
    [m_configSocket receiveWithTimeout:-1 tag:0];
    
    /* init control socket(unicast) */
    m_controlSocket = [[AsyncUdpSocket alloc]initWithDelegate:self];
    [m_controlSocket bindToPort:(LOCAL_PORT_NUM+1) error:&err];
    [m_controlSocket receiveWithTimeout:-1 tag:0];
    
    return [super init];
}

- (unsigned int)rtk_sc_get_mode
{
    return m_mode;
}

// Internal Functions
/* Add an interger value to m_plain_buf with TLV format */
- (int)add_tlv_int:(unsigned int)offset tag:(unsigned char)tag value:(unsigned int)value
{
    unsigned char size = (sizeof(value)) & 0xFF;
    int ret;
    
    //    NSLog(@"Add TLV at offset %d: tag:%d len:%d value:%u", offset, tag, size, value);
    memcpy(m_plain_buf+offset, &tag, TLV_T_BYTES);
    memcpy(m_plain_buf+offset+TLV_T_BYTES, &size, TLV_L_BYTES);
    memcpy(m_plain_buf+offset+TLV_T_L_BYTES, &value, sizeof(value));
    
    ret = (TLV_T_L_BYTES + sizeof(value));
    m_plain_len += ret;
    
    return ret;
}


/* Add an string to m_plain_buf with TLV format */
- (int)add_tlv_string:(unsigned int)offset tag:(unsigned char)tag len:(int)len value:(const char *)value
{
    unsigned char size = len & 0xFF;
    int ret;
    
    //    NSLog(@"ADD TLV at offset %d: tag:%d len:%d value:%s", offset, tag, len, value);
    memcpy(m_plain_buf+offset, &tag, TLV_T_BYTES);
    memcpy(m_plain_buf+offset+TLV_T_BYTES, &size, TLV_L_BYTES);
    NSLog(@"len=%d, value=%s", len, value);
    memcpy(m_plain_buf+offset+TLV_T_L_BYTES, value, len);
    
    ret = (TLV_T_L_BYTES + len);
    m_plain_len += ret;
    
    NSLog(@"ret=%d",ret);
    return ret;
}

/* Add SSID to m_plain_buf */
- (int)profile_add_ssid:(unsigned int)buf_offset ssid:(NSString *)ssid
{
    const char *_ssid = [ssid UTF8String];
    unsigned char len = (strlen(_ssid)) & 0xFF;
    unsigned char tag = TAG_SSID & 0xFF;
    int ret;
#if PATTERN_THREE_DBG
    NSLog(@"offset:%d, ssid:%s", buf_offset, _ssid);
#endif
    ret = [self add_tlv_string:buf_offset tag:tag len:len value:_ssid];
    return ret;
}

/* Add password(if exist) to m_plain_buf */
- (int)profile_add_psw:(unsigned int)buf_offset psw:(NSString *)password
{
    const char *_psw = [password UTF8String];
    if(_psw==nil){ //no passwd input
        NSLog(@"No Password!");
        return 0;
    }
    
    unsigned char len = (strlen(_psw)) & 0xFF;
    unsigned char tag = TAG_PSW & 0xFF;
    int ret;
#if PATTERN_THREE_DBG
    NSLog(@"offset:%d, password:%s", buf_offset, _psw);
#endif
    ret = [self add_tlv_string:buf_offset tag:tag len:len value:_psw];
    return ret;
}

/* Add IP address to m_plain_buf */
- (int)profile_add_ip:(unsigned int)buf_offset ip:(unsigned int)ip
{
#if PATTERN_THREE_DBG
    NSLog(@"offset:%d, ip:%x", buf_offset, ip);
#endif
    unsigned int _ip = htonl(ip);
    unsigned char tag = TAG_IP & 0xFF;
    int ret;
    
    ret = [self add_tlv_int:buf_offset tag:tag value:_ip];
    return ret;
}

- (void)gen_random: (unsigned char *)random
{
#if 0
    /* calculate random value, will be used in sync packets and for generating HMAC_SHA key(using MD5) */
    random[0] = (SC_RAND_MIN + rand()%(SC_RAND_MAX - SC_RAND_MIN)) & 0xFF;
    random[1] = (SC_RAND_MIN + rand()%(SC_RAND_MAX - SC_RAND_MIN)) & 0xFF;
    random[2] = (SC_RAND_MIN + rand()%(SC_RAND_MAX - SC_RAND_MIN)) & 0xFF;
    random[3] = (SC_RAND_MIN + rand()%(SC_RAND_MAX - SC_RAND_MIN)) & 0xFF;
#else
    random[0] = 50;
    random[1] = 51;
    random[2] = 52;
    random[3] = 53;
#endif
    NSLog(@"random number: %d %d %d %d", random[0], random[1], random[2], random[3]);
    
    return;
}

/* Build m_plain_buf */
- (int)build_plain_buf:(NSString *)ssid psw:(NSString *)password
{
    int step = 0, ip = [self getLocalIPAddress];
    if(ip==0){
        NSLog(@"build_plain_buf: get IP failed");
        return RTK_FAILED;
    }
    
    NSLog(@"build_plain_buf: step=%d", step);
    step += [self profile_add_ssid:step ssid:ssid];
    NSLog(@"build_plain_buf: step=%d", step);
    step += [self profile_add_psw:step psw:password];
    NSLog(@"build_plain_buf: step=%d", step);
    step += [self profile_add_ip:step ip:ip];
    NSLog(@"build_plain_buf: step=%d", step);
    
    return RTK_SUCCEED;
}

/* Generate key to m_aes_key_buf */
- (int)generate_key
{
    int len = 0, pin_length = 0;
    unsigned char buffer[128];
    unsigned char md5_result[16];
    memset(buffer, '\0', 128);
    const char *tmp;
    //NSString *default_pin = m_pin;
    
    /* get SA */
    NSString *mac_addr = [self getMACAddress:"en0"];
    unsigned char sa[6] = {0x0};
    /* change NSString to char */
    tmp = [mac_addr UTF8String];
    sa[0] = [self format_change:tmp[0] ch1:tmp[1]];
    sa[1] = [self format_change:tmp[2] ch1:tmp[3]];
    sa[2] = [self format_change:tmp[4] ch1:tmp[5]];
    sa[3] = [self format_change:tmp[6] ch1:tmp[7]];
    sa[4] = [self format_change:tmp[8] ch1:tmp[9]];
    sa[5] = [self format_change:tmp[10] ch1:tmp[11]];
    NSLog(@"mac_addr=%@\tsa:%02x:%02x:%02x:%02x:%02x:%02x", mac_addr, sa[0],sa[1],sa[2],sa[3],sa[4],sa[5]);
    /* copy SA to buffer */
#if 1
    memcpy(buffer, sa, 6);
    len+=6;
#else //For MD5 test
    memcpy(buffer, tmp, 12);
    len+=12;
#endif
    
    /* PIN */
    tmp = [m_pin UTF8String];
    pin_length = (int)strlen(tmp);
    NSLog(@"pin(%d): %s(PIN)",pin_length, tmp);
    memcpy(buffer+len, tmp, pin_length);
    len+=pin_length;
    
    /* Nonce */
    tmp = pattern_three_nonce_buffer;
    NSLog(@"Nonce(%lubytes): %s", strlen(tmp), tmp);
    memcpy(buffer+len, tmp, strlen(tmp));
    len+=strlen(tmp);
    
    /* Random Value */
    [self gen_random:m_rand];
    memcpy(buffer+len, m_rand, 4);
    len+=4;
    
    /* Generate key for HMAC_SHA1, using MD5_digest*/
    CC_MD5(buffer, len, md5_result);
#if PATTERN_THREE_DBG
    NSLog(@"MD5 buffer(%d): %s", len, buffer);
    NSLog(@"MD5 result: %02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
          md5_result[0], md5_result[1], md5_result[2], md5_result[3],
          md5_result[4], md5_result[5], md5_result[6], md5_result[7],
          md5_result[8], md5_result[9], md5_result[10], md5_result[11],
          md5_result[12], md5_result[13], md5_result[14], md5_result[15]
          );
#endif
    
    /* Pattern name */
    NSLog(@"Pattern name: %@", m_pattern_name);
    tmp = [m_pattern_name UTF8String];
    NSLog(@"Pattern name: %s", tmp);
    memcpy(buffer+len, tmp, strlen(tmp));
    len += strlen(tmp);
    
    /* Generate AES key, using HMAC_SHA1. Digest is 20 bytes */
    memset(m_aes_key_buf, 0x0, MAX_AES_KEY_LEN);
    NSLog(@"HMAC_SHA1 buffer: %d bytes", len);
    NSLog(@"HMAC_SHA1 key:  %02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
          md5_result[0], md5_result[1], md5_result[2], md5_result[3],
          md5_result[4], md5_result[5], md5_result[6], md5_result[7],
          md5_result[8], md5_result[9], md5_result[10], md5_result[11],
          md5_result[12], md5_result[13], md5_result[14], md5_result[15]);
    
    //CC_SHA1(buffer, len, m_aes_key_buf);
    CCHmac(kCCHmacAlgSHA1, md5_result, 16, buffer, len, m_aes_key_buf);
    
#if PATTERN_THREE_DBG
    NSLog(@"After SHA1, got AES key: %02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X", m_aes_key_buf[0], m_aes_key_buf[1], m_aes_key_buf[2], m_aes_key_buf[3],m_aes_key_buf[4], m_aes_key_buf[5], m_aes_key_buf[6], m_aes_key_buf[7],
          m_aes_key_buf[8], m_aes_key_buf[9], m_aes_key_buf[10], m_aes_key_buf[11],
          m_aes_key_buf[12], m_aes_key_buf[13], m_aes_key_buf[14], m_aes_key_buf[15],m_aes_key_buf[16], m_aes_key_buf[17], m_aes_key_buf[18], m_aes_key_buf[19],
          m_aes_key_buf[20], m_aes_key_buf[21], m_aes_key_buf[22], m_aes_key_buf[23],
          m_aes_key_buf[24], m_aes_key_buf[25], m_aes_key_buf[26], m_aes_key_buf[27],
          m_aes_key_buf[28], m_aes_key_buf[29], m_aes_key_buf[30], m_aes_key_buf[31]);
#endif
    //set AES Key length as a fixed number 16
    m_key_len = 16;
    
    return RTK_SUCCEED;
}

/* encrypt plain wifi profile */
- (int)encrypt_profile
{
    unsigned int pattern_flag = [m_pattern_flag intValue];
    if(pattern_flag & PATTERN_USING_PLAIN)
    {
        memcpy(m_crypt_buf, m_plain_buf, m_plain_len);
        m_crypt_len = m_plain_len;
        NSLog(@"Using Plain, length=%d", m_crypt_len);
        
        return RTK_SUCCEED;
    }
    memset(m_crypt_buf, 0x0, MAX_BUF_LEN); // clear the crypted buffer.
    
    // ensure 8-bit alignment
    //int padding = 8 - (m_plain_len%8);
    /*
     * AES Encryption:
     *      orig        +       key         =   encryted result
     *  m_plain_buf     +   m_aes_key_buf   =   m_crypt_buf
     *  m_plain_len         m_key_len           m_crypt_len
     */
    
    // 8-byte alignment for m_plain_buffer
    int padding = (8-(m_plain_len%8));
    //padding = (padding==8)?0:padding;
    if(padding==8)
        padding = 0;
    else{
        memset(m_plain_buf+m_plain_len, 0x0, padding);
        m_plain_len += padding;
    }
    NSLog(@"Use AES Wrap, %d bytes plain buffer, %d is padding", m_plain_len, padding);
    NSLog(@"%s", m_plain_buf);
    
    int i,j,k,nblk=m_plain_len/BLKSIZE8;
    static unsigned char R[32][BLKSIZE8], A[BLKSIZE8], xor[BLKSIZE8]; //max possible length of plain_buffer is 32*8=256 bytes
    static block m,x;
    unsigned char _x[32];
    size_t numBytesEncrypted = 0;
    
    memset(x.b, 0x0, BLKSIZE);
    memset(_x, 0x0, 32);
    memcpy(A, pattern_three_key_iv, BLKSIZE8);
    for(i=0; i<nblk; i++)
        memcpy(&R[i], m_plain_buf + i*BLKSIZE8, BLKSIZE8);
    
    for(j=0; j<AES_WRAP_TIME; j++){
        for (i=0; i<nblk; i++) {
            memset(_x, 0x0, 32);
            memcpy(&m.b, A, BLKSIZE8); // put the iv to m.b[0]
            memcpy((&m.b[0])+BLKSIZE8, &(R[i]), BLKSIZE8); // put the first i byte of plain buffer to m.b[1]
            //NSLog(@"========j=%d,i=%d========",j,i);
            //NSLog(@"Input");
            //[self sc_dump:m.b len:16];
            // do AES encrypt
            CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt, kCCAlgorithmAES128,
                                                  kCCOptionPKCS7Padding | kCCOptionECBMode,
                                                  m_aes_key_buf, kCCBlockSizeAES128,
                                                  NULL,
                                                  m.b, BLKSIZE,
                                                  _x, 32,
                                                  &numBytesEncrypted);
            if (cryptStatus != kCCSuccess) {
                NSLog(@"Error at AES crypt!!!");
                return -1;
            }
            //NSLog(@"AES success,encrypted=%d bytes", (int)numBytesEncrypted);
            memcpy(&x.b, _x, 16);
            //[self sc_dump:x.b len:16];
            
            memset(xor, 0x0, sizeof(xor));
            xor[7] |= ((nblk * j) + i + 1);
            for (k=0; k<8; k++) {
                A[k]=x.b[k] ^ xor[k];
            }
            for (k=0; k<8; k++) {
                R[i][k] = x.b[k+BLKSIZE8];
            }
            //[self sc_dump:R[i] len:8];
        }
    }
    
    // copy the result to m_crypt_buf
    memcpy(m_crypt_buf, A, BLKSIZE8);
    for (i=0; i<nblk; i++) {
        memcpy(m_crypt_buf+(i+1)*BLKSIZE8, &R[i], BLKSIZE8);
    }
    m_crypt_len = m_plain_len + 8;
    
    /* Dump AES result */
    NSLog(@"===========Plain:%dbytes===========", m_plain_len);
    [self rtk_dump_buffer:m_plain_buf len:m_plain_len];
    NSLog(@"===========Key:%dbytes===========", m_key_len);
    [self rtk_dump_buffer:m_aes_key_buf len:m_key_len];
    NSLog(@"===========Cipher:%dbytes===========",m_crypt_len);
    [self rtk_dump_buffer:m_crypt_buf len:m_crypt_len];
    
    return RTK_SUCCEED;
}

/* Send interface 1 : send multicast data with payload length len */
- (int)udp_send_multi_data_interface: (unsigned int)ip len:(unsigned char)len
{
    if(m_configSocket == nil){
        NSLog(@"udpSocket doesn't exist!!!");
        return RTK_FAILED;
    }
    
    int ret;
    NSError *err;
    
    char *payload = (char*)malloc((unsigned int)len);
    memset(payload, 0x31, len);
    NSData *data = [NSData dataWithBytes: payload length:(unsigned int)len];
    
    NSString *host = [[NSString alloc] initWithString:[NSString stringWithFormat:@"%d.%d.%d.%d", (ip>>24)&0xFF, (ip>>16)&0xFF, (ip>>8)&0xFF, ip&0xFF]];
    
    NSLog(@"P3: sendData 1......host=%@, port=%d", host, MCAST_PORT_NUM);
    [m_configSocket joinMulticastGroup:host error:&err];
    [m_configSocket receiveWithTimeout:-1 tag:0];
    BOOL result = [m_configSocket sendData:data toHost:host port:MCAST_PORT_NUM withTimeout:-1 tag:0];
    
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
    int ret;
    if(m_configSocket == nil){
        NSLog(@"udpSocket doesn't exist!!!");
        return -1;
    }
    NSError *err;
    NSString *host = [[NSString alloc] initWithString:[NSString stringWithFormat:@"%d.%d.%d.%d", (ip>>24)&0xFF, (ip>>16)&0xFF, (ip>>8)&0xFF, ip&0xFF]];
    
    NSLog(@"P3: sendData 2......host=%@, port=%d", host, MCAST_PORT_NUM);
    // send data by multicast
    [m_configSocket joinMulticastGroup:host error:&err];
    [m_configSocket receiveWithTimeout:-1 tag:0];
    BOOL result = [m_configSocket sendData:payload toHost:host  port:MCAST_PORT_NUM withTimeout:-1 tag:0];
    
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
    int ret = RTK_FAILED;
    
    NSString *host = [[NSString alloc] initWithString:[NSString stringWithFormat:@"%d.%d.%d.%d", (ip>>24)&0xFF, (ip>>16)&0xFF, (ip>>8)&0xFF, ip&0xFF]];
    //debug
    NSLog(@"P3: sendData 3......host=%@, port=%d", host, UNICAST_PORT_NUM);
    
    [m_controlSocket receiveWithTimeout:-1 tag:0];
    BOOL result = [m_controlSocket sendData:payload toHost:host port:UNICAST_PORT_NUM withTimeout:-1 tag:0];
    if(!result)
        ret=RTK_FAILED;
    else
        ret=RTK_SUCCEED;
    
    host = nil;
    [host release];
    return ret;
}

/* create and send sync */
- (int)create_sync: (unsigned char *)buffer len:(int)len
{
    unsigned char seq, *ptr;
    unsigned char mac[6] = {0x0};
    unsigned int i = 0;
    unsigned char mac_prefix[] = {0x01, 0x00, 0x5e};
    unsigned int m_index = PATTERN_THREE_IDX;
    
    ptr = buffer;
    seq = 0;
    for(; i<PATTERN_THREE_SYNC_PKT_NUM; i++)
    {
        memset(mac, 0x0, sizeof(mac));
        memcpy(mac, mac_prefix, sizeof(mac_prefix));
        // the 4th byte of mac
        mac[PATTERN_THREE_SEQ_IDX] = seq;
        // the 6th byte of mac
        if(i<=2)
            mac[PATTERN_THREE_ID_IDX] = (m_index >> ((2-i)*8)) & 0xFF;
        else if(i==3)
            mac[PATTERN_THREE_DATA_IDX] = (PATTERN_THREE_SYNC_PKT_NUM + len);
        else if(i==4)
            mac[PATTERN_THREE_DATA_IDX] = ptr[PATTERN_THREE_MAGIC_IDX0-3]+ptr[3*1+PATTERN_THREE_MAGIC_IDX1-3]+ptr[3*2+PATTERN_THREE_MAGIC_IDX2-3]+ptr[3*3+PATTERN_THREE_MAGIC_IDX3-3];
        else if(i>=5){
            //NSLog(@"m_random[%d] = %d", (i-5), m_random[i-5]);
            mac[PATTERN_THREE_RANDOM_IDX] = m_rand[i-5];
        }
        // the 5th byte of mac
        mac[PATTERN_THREE_CKSUM_IDX] = [self CKSUM: mac len:6];
        
        //NSLog(@"[sync]mac[3] %02x mac[4] %02x mac[5] %02x\n",mac[3],mac[4],mac[5]);
        memcpy(buffer, &mac[3], 3);
        buffer += 3;
        seq++;
    }
    return RTK_SUCCEED;
}

/* send sync packets */
- (int)send_sync
{
    int i, ret=RTK_FAILED;
    unsigned int ip;
    unsigned char buffer[32];
    //put sync information in MAC addr
    [self create_sync:buffer len:m_crypt_len];
    
    for(i=0;i<PATTERN_THREE_SYNC_PKT_NUM;i++)
    {
        // build multicast IP from MAC addr we just created
        ip=(MCAST_ADDR_PREFIX <<24) + (buffer[(3*i)]<<16)+(buffer[(3*i)+1]<<8)+(buffer[(3*i)+2]);
        ret = [self udp_send_multi_data_interface:ip len: buffer[3*i]];
        if(ret==RTK_FAILED)
            break;
    }
    
    return ret;
}

/* send wifi profile */
- (int)send_data
{
    unsigned int i, ip, ret=RTK_FAILED;
    unsigned char mac[6];
    mac[0]=0x1;
    mac[1]=0x0;
    mac[2]=0x5e;
    for(i=0; i<m_crypt_len; i++)
    {
        mac[PATTERN_THREE_CKSUM_IDX]=0;
        mac[PATTERN_THREE_SEQ_IDX]=(i+PATTERN_THREE_SYNC_PKT_NUM);
        mac[PATTERN_THREE_DATA_IDX]=m_crypt_buf[i];
        mac[PATTERN_THREE_CKSUM_IDX]=[self CKSUM:mac len:6];
        ip=((MCAST_ADDR_PREFIX)<<24) + (mac[3]<<16) + (mac[4]<<8) + (mac[5]);
        //NSLog(@"[data]mac[3] %02x mac[4] %02x mac[5] %02x\n",mac[3],mac[4],mac[5]);
        ret = [self udp_send_multi_data_interface:ip len:mac[PATTERN_THREE_SEQ_IDX]];
        if (ret==RTK_FAILED)
            break;
    }
    return ret;
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
    NSLog(@"m_pin : %@", m_pin);
    NSString *pin = m_pin;
    const unsigned char *default_pin_char = (const unsigned char *)[pin cStringUsingEncoding:NSUTF8StringEncoding];
    unsigned int default_pin_len = (unsigned int)(strlen(default_pin_char));
    NSLog(@"default_pin_char is(%d) %s", default_pin_len, default_pin_char);
    unsigned char md5_buffer[64+64] = {0x0};//note: default pin max length is 64 bytes
    memcpy(md5_buffer, nonce, 64);
    memcpy(md5_buffer+64, default_pin_char, default_pin_len);
    NSLog(@"md5_plain buffer is(%d) %s", (int)strlen(md5_buffer), md5_buffer);
    CC_MD5(md5_buffer, 64+default_pin_len , md5_result);
    NSLog(@"md5_encrypt result: %02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x", md5_result[0],md5_result[1],md5_result[2],md5_result[3],md5_result[4],md5_result[5],md5_result[6],md5_result[7],md5_result[8],md5_result[9],md5_result[10],md5_result[11],md5_result[12],md5_result[13],md5_result[14],md5_result[15]);
    
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
    NSLog(@"m_pin : %@", m_pin);
    NSString *pin = m_pin;
    const unsigned char *default_pin_char = (const unsigned char *)[pin cStringUsingEncoding:NSUTF8StringEncoding];
    unsigned int default_pin_len = (unsigned int)(strlen(default_pin_char));
    NSLog(@"default_pin_char is(%d) %s", default_pin_len, default_pin_char);
    unsigned char md5_buffer[64+64] = {0x0};//note: default pin max length is 64 bytes
    memcpy(md5_buffer, nonce, 64);
    memcpy(md5_buffer+64, default_pin_char, default_pin_len);
    NSLog(@"md5_plain buffer is(%d) %s", (int)strlen(md5_buffer), md5_buffer);
    CC_MD5(md5_buffer, 64+default_pin_len , md5_result);
    NSLog(@"md5_encrypt result: %02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x", md5_result[0],md5_result[1],md5_result[2],md5_result[3],md5_result[4],md5_result[5],md5_result[6],md5_result[7],md5_result[8],md5_result[9],md5_result[10],md5_result[11],md5_result[12],md5_result[13],md5_result[14],md5_result[15]);
    
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
    
    ret = [self udp_send_unicast_interface:ip payload:ack_data];
    
    return ret;
}

#if PATTERN_THREE_DBG
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
#endif

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
#if PATTERN_THREE_DBG
    [self dump_dev_info:new_dev];
#endif
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
#if PATTERN_THREE_DBG
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

/* ***********************Receive Delegate************************** */
- (BOOL)onUdpSocket:(AsyncSocket *)sock didReceiveData:(NSData *)data withTag:(long)tag fromHost:(NSString *)host port:(UInt16)port
{
    if (host==nil) {
        return false;
    }
    NSLog(@"=============P3: Receive from host %@ port %d==================", host, port);
    NSLog(@"m_mode(%p)=%d", &m_mode, m_mode);
    
    /* step 1: get the received data */
    unsigned char flag;
    unsigned char *data_p = (unsigned char*)[data bytes];
    if (data_p == nil) {
        NSLog(@"data received is nil!!!");
        return false;
    }
    unsigned int data_length = (unsigned int)(data_p[2]);
    flag = data_p[0];
    
#if PATTERN_THREE_DBG
    // for debug
    NSLog(@"data in udp is %ld bytes: ", (unsigned long)[data length]);
    
    int recv_idx = 0;
    for (recv_idx=0; recv_idx<(data_length+3); recv_idx++) {
        NSLog(@"[%d]: %02x", recv_idx, data_p[recv_idx]);
    }
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

/* ***********************EXTERNAL API************************** */
- (int)rtk_pattern_build_profile: (NSString *)ssid psw:(NSString *)password pin:(NSString *)pin
{
    NSLog(@"PATTERN 3: build profile");
    int ret = RTK_FAILED;
    // set pin
    m_pin = [[NSString alloc] initWithString:pin];
    
    // build plain buf
    ret = [self build_plain_buf:ssid psw:password];
    if(ret==RTK_FAILED){
        NSLog(@"Pattern 3: rtk_sc_build_profile error 1");
        return ret;
    }
    
    // generate key, only return succeed
    ret = [self generate_key];
    
    // encrypt plain buf
    ret = [self encrypt_profile];
    
    m_mode = MODE_CONFIG;
    NSLog(@"Pattern3: build_profile: m_mode(%p)=%d", &m_mode, m_mode);
    [m_config_list removeAllObjects];
    
    return ret;
}

- (int)rtk_pattern_send: (NSNumber *)times
{
    int ret = RTK_FAILED;
    unsigned int _times;
    _times = [times intValue];
    
    NSLog(@"======================Pattern 3:rtk_sc_start=======================");
    
    for(int i=0; i<_times; i++){
        NSLog(@"------Send %d-------", i);
        /* step1: send sync */
        ret = [self send_sync];
        if(ret==RTK_FAILED)
            break;
        
        /* step2: send data */
        ret = [self send_data];
        if(ret==RTK_FAILED)
            break;
    }
    
    if (ret==RTK_FAILED) {
        NSLog(@"rtk_sc_send failed");
    }
    
    return ret;
}

- (void)rtk_pattern_stop
{
    [super rtk_pattern_stop];
}

- (NSMutableArray *)rtk_pattern_get_config_list
{
    return m_config_list;
}
- (NSMutableArray *)rtk_pattern_get_discover_list
{
    return m_discover_list;
}

@end
