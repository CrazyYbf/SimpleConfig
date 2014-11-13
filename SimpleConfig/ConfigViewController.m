//
//  ConfigViewController.m
//  SimpleConfig
//
//  Created by Realsil on 14/11/11.
//  Copyright (c) 2014年 Realtek. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ConfigViewController.h"
#import <SystemConfiguration/CaptiveNetwork.h>

@implementation ConfigViewController
@synthesize m_input_ssid, m_input_password, m_input_pin, m_config_button;
@synthesize m_qrscan_line;
@synthesize simpleConfig;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [m_input_ssid setText:[self fetchCurrSSID]];
    [m_input_ssid addTarget:self action:@selector(textFieldDoneEditing:) forControlEvents:UIControlEventEditingDidEndOnExit];
    [m_input_password addTarget:self action:@selector(textFieldDoneEditing:) forControlEvents:UIControlEventEditingDidEndOnExit];
    [m_input_pin addTarget:self action:@selector(textFieldDoneEditing:) forControlEvents:UIControlEventEditingDidEndOnExit];
    
    m_context.m_timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(timerHandler:) userInfo:nil repeats:YES];
    m_context.m_mode = MODE_INIT;
    simpleConfig = [[SimpleConfig alloc] init];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc {
    [m_input_ssid release];
    [m_input_password release];
    [m_input_pin release];
    [m_config_button release];
    [super dealloc];
}

/* Hide the keyboard when pushing "enter" */
- (BOOL)textFieldDoneEditing:(UITextField *)sender
{
    NSLog(@"textFieldDoneEditing, Sender is %@", sender);
    UITextField *target = sender;
    return [target resignFirstResponder];
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    if([text isEqualToString:@"\n"])
    {
        [textView resignFirstResponder];
        return NO;
    }
    return YES;
}

/* action responder */
- (IBAction)rtk_start_listener:(id)sender
{
    if (m_context.m_mode == MODE_INIT) {
        // build profile and send
        m_context.m_mode = MODE_CONFIG;
        [m_config_button setTitle:SC_UI_STOP_BUTTON forState:UIControlStateNormal];
        [simpleConfig rtk_sc_config_start:m_input_ssid.text psw:m_input_password.text pin:m_input_pin.text];
    }else if(m_context.m_mode == MODE_CONFIG){
        // stop sending profile
        m_context.m_mode = MODE_INIT;
        [m_config_button setTitle:SC_UI_START_BUTTON forState:UIControlStateNormal];
        [simpleConfig rtk_sc_config_stop];
    }
}

- (IBAction)rtk_scan_listener:(id)sender
{
    if (m_context.m_mode == MODE_INIT) {
        // do action
        [self showQRScanner];
    }else{
        // don't listen
    }
}

/******* private functions *******/
- (NSString *)fetchCurrSSID
{
    NSArray *ifs = (id)CNCopySupportedInterfaces();
    NSDictionary *info = nil;
    for (NSString *ifnam in ifs) {
        info = (id)CNCopyCurrentNetworkInfo((CFStringRef)ifnam);
        if (info && [info count]) {
            break;
        }
        [info release];
    }
    [ifs release];
    
    NSString *auto_ssid = [info objectForKey:@"SSID"];
    NSLog(@"Current SSID: %@", auto_ssid);
    return auto_ssid;
}

-(void)timerHandler: (NSTimer *)sender
{
    unsigned int sc_mode = [simpleConfig rtk_sc_get_mode];
    switch (sc_mode) {
        case MODE_INIT:
            break;
        
        case MODE_CONFIG:
            break;
            
        case MODE_WAIT_FOR_IP:
            [m_config_button setTitle:SC_UI_START_BUTTON forState:UIControlStateNormal];
            if (m_context.m_mode==MODE_CONFIG)
                m_context.m_mode = MODE_ALERT;
            [self showConfigList];
            break;
            
        default:
            break;
    }
}

-(void)showConfigList
{
    if (m_context.m_mode!=MODE_ALERT)
        return;

    struct dev_info dev;
    NSValue *dev_val;
    NSMutableArray *list = simpleConfig.config_list;
    NSString *msg;
#if 1
    for (int i=0; i<[list count]; i++) {
        dev_val = [list objectAtIndex:i];
        [dev_val getValue:&dev];
        
        NSLog(@"======Dump dev_info %d======",i);
        NSLog(@"MAC: %02x:%02x:%02x:%02x:%02x:%02x", dev.mac[0], dev.mac[1],dev.mac[2],dev.mac[3],dev.mac[4],dev.mac[5]);
        NSLog(@"Status: %d", dev.status);
        NSLog(@"Device type: %d", dev.dev_type);
        NSLog(@"IP:%x", dev.ip);
        NSLog(@"Name:%@", [NSString stringWithUTF8String:(const char *)(dev.extra_info)]);
    }
#endif
    
    dev_val = [list objectAtIndex:0];
    [dev_val getValue:&dev];
    
    msg = [NSString stringWithFormat:@"Device info:\nMAC: %02x:%02x:%02x:%02x:%02x:%02x\nDevice type: %d\nName:%@", dev.mac[0], dev.mac[1],dev.mac[2],dev.mac[3],dev.mac[4],dev.mac[5], dev.dev_type, [NSString stringWithUTF8String:(const char *)(dev.extra_info)]];
    UIAlertView *alert = [[UIAlertView alloc]initWithTitle:SC_UI_ALERT_CONFIGURE_DONE message:msg delegate:self cancelButtonTitle:SC_UI_ALERT_OK otherButtonTitles:nil, nil];
    [alert show];
    
    m_context.m_mode = MODE_INIT;
}

/* ------QRCode Related------*/
-(void)showQRScanner
{
    /* full screen scan QR Code */
    m_num = 0;
    m_upOrdown = NO;
    //初始话ZBar
    ZBarReaderViewController * reader = [ZBarReaderViewController new];
    //设置代理
    reader.readerDelegate = self;
    //支持界面旋转
    reader.supportedOrientationsMask = ZBarOrientationMaskAll;
    reader.showsHelpOnFail = NO;
    //reader.scanCrop = CGRectMake(0.15, 0, 0.6, 1.5);//扫描的感应框
    ZBarImageScanner * scanner = reader.scanner;
    [scanner setSymbology:ZBAR_I25
                   config:ZBAR_CFG_ENABLE
                       to:0];
    UIView * view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 420)];
    view.backgroundColor = [UIColor clearColor];
    reader.cameraOverlayView = view;
    
    UILabel * label = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, 280, 40)];
    label.text = @"请将扫描的二维码至于下面的框内\n谢谢！";
    label.textColor = [UIColor whiteColor];
    label.textAlignment = 1;
    label.lineBreakMode = 0;
    label.numberOfLines = 2;
    label.backgroundColor = [UIColor clearColor];
    [view addSubview:label];
    
    UIImageView * image = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"pick_bg.png"]];
    image.frame = CGRectMake(20, 80, 280, 280);
    [view addSubview:image];
    
    
    m_qrscan_line = [[UIImageView alloc] initWithFrame:CGRectMake(30, 10, 220, 2)];
    m_qrscan_line.image = [UIImage imageNamed:@"line.png"];
    [image addSubview:m_qrscan_line];
    //定时器，设定时间过1.5秒，
    m_qrcode_timer = [NSTimer scheduledTimerWithTimeInterval:.02 target:self selector:@selector(qrcode_animation) userInfo:nil repeats:YES];
    
    [self presentViewController:reader animated:YES completion:^{
    }];
}

-(void)qrcode_animation
{
    if (m_upOrdown == NO) {
        m_num ++;
        m_qrscan_line.frame = CGRectMake(40, 20+2*m_num, 220, 2);
        if (2*m_num == 280) {
            m_upOrdown = YES;
        }
    }
    else {
        m_num --;
        m_qrscan_line.frame = CGRectMake(40, 20+2*m_num, 220, 2);
        if (m_num == 0) {
            m_upOrdown = NO;
        }
    }
    
}

/* Parse QRCode */
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    id<NSFastEnumeration> results = [info objectForKey:ZBarReaderControllerResults];
    ZBarSymbol *symbol = nil;
    for(symbol in results)
        break;
    
    NSLog(@"Got QRCode: %@", symbol.data);
    [m_input_pin setText:symbol.data];
    //self.imageView.image = [info objectForKey:UIImagePickerControllerOriginalImage];
    [picker dismissViewControllerAnimated:YES completion:nil];
}

@end