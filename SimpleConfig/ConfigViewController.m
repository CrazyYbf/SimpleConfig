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

/* Hide the keyboard */
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

@end