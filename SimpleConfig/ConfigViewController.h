//
//  ConfigViewController.h
//  SimpleConfig
//
//  Created by Realsil on 14/11/11.
//  Copyright (c) 2014年 Realtek. All rights reserved.
//

#ifndef SimpleConfig_ConfigViewController_h
#define SimpleConfig_ConfigViewController_h

#import <UIKit/UIKit.h>
#import "SimpleConfig.h"
#import "String.h"
#import "ZBarSDK.h"

typedef struct rtk_sc_context{
    unsigned int    m_mode;
    NSTimer         *m_timer;
    
    unsigned int    m_recv_len;
    unsigned char   m_recv_buf[MAX_BUF_LEN];
}SC_CONTEXT;

@interface ConfigViewController : UIViewController <ZBarReaderDelegate>
{
@private
    // SC Related
    SC_CONTEXT  m_context;
    
    // QRCode Related
    int         m_num ;
    BOOL        m_upOrdown;
    NSTimer     *m_qrcode_timer;
}

@property (retain, nonatomic) IBOutlet UITextField *m_input_ssid;
@property (retain, nonatomic) IBOutlet UITextField *m_input_password;
@property (retain, nonatomic) IBOutlet UITextField *m_input_pin;
@property (retain, nonatomic) IBOutlet UIButton    *m_config_button;

@property (strong, nonatomic) UIImageView          *m_qrscan_line;

@property (strong, nonatomic) SimpleConfig         *simpleConfig;

- (IBAction)rtk_start_listener:(id)sender;
- (IBAction)rtk_scan_listener:(id)sender;

@end

#endif
