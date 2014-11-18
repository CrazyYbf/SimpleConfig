//
//  ClientViewController.m
//  SimpleConfig
//
//  Created by Realsil on 14/11/13.
//  Copyright (c) 2014年 Realtek. All rights reserved.
//

#import "ClientViewController.h"

@interface ClientViewController ()

@end

@implementation ClientViewController
@synthesize sharedData;
@synthesize pin_label, m_qrscan_line;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    m_controller = [[Controller alloc] init];
    
    if (sharedData!=nil) {
        struct dev_info dev;
        [sharedData getValue:&dev];
        
        if(0x0a==dev.extra_info[0])
            [_name_label setText:@"Untitled"];
        else
            [_name_label setText:[NSString stringWithUTF8String:(const char *)dev.extra_info]];
        _ip_label.text = [NSString stringWithFormat:@"%02d.%02d.%02d.%02d", 0xFF&(dev.ip>>24), 0xFF&(dev.ip>>16), 0xFF&(dev.ip>>8), 0xFF&dev.ip];
        _mac_label.text = [NSString stringWithFormat:@"%02x:%02x:%02x:%02x:%02x:%02x", dev.mac[0], dev.mac[1], dev.mac[2], dev.mac[3], dev.mac[4], dev.mac[5]];
    }
    
    pin_label.text = @"";
    [pin_label addTarget:self action:@selector(textFieldDoneEditing:) forControlEvents:UIControlEventEditingDidEndOnExit];
    [_name_label addTarget:self action:@selector(textFieldDoneEditing:) forControlEvents:UIControlEventEditingDidEndOnExit];
    m_timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(timerHandler:) userInfo:nil repeats:YES];
    m_mode = MODE_INIT;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (void)dealloc {
    [_name_label release];
    [_ip_label release];
    [_mac_label release];
    [_delete_btn release];
    [_rename_btn release];
    [pin_label release];
    [_name_label release];
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

- (void)viewDidDisappear:(BOOL)animated
{
    // Must release simpleConfig, so that its asyncUDPSocket delegate won't receive data
    NSLog(@"close control socket");
    [m_controller rtk_sc_close_sock];
    [super viewDidDisappear:animated];
}

- (void)viewWillAppear:(BOOL)animated
{
    NSLog(@"reopen control socket");
    [m_controller rtk_sc_reopen_sock];
}

/* Button Delegate */
-(IBAction)delete_profile:(id)sender
{
    // generate data
    NSString *pin = pin_label.text;
    unsigned int ip = [m_controller rtk_sc_convert_host_to_ip:_ip_label.text];
    NSLog(@"pin=%@, ip=%x", pin, ip);
    
    if ([pin isEqualToString:@""]) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:SC_UI_ALERT_TITLE_ERROR message:SC_UI_ALERT_INPUT_PIN delegate:self cancelButtonTitle:SC_UI_ALERT_OK otherButtonTitles:nil, nil];
        [alert show];
        return;
    }
    [m_controller rtk_sc_gen_control_data:RTK_SC_CONTROL_DELETE pin:pin name:nil];
    m_mode = MODE_CONTROL;
    
    // send data
    for (int i=0; i<RTK_SC_CONTROL_PKT_ROUND; i++) {
        NSLog(@"send delete profile data %d", i);
        [m_controller rtk_sc_send_control_data:ip];
    }
}

-(IBAction)rename_device:(id)sender
{
    // generate data
    NSString *pin = pin_label.text;
    NSString *name = _name_label.text;
    unsigned int ip = [m_controller rtk_sc_convert_host_to_ip:_ip_label.text];
    NSLog(@"pin=%@, ip=%x", pin, ip);
    
    if ([pin isEqualToString:@""]) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:SC_UI_ALERT_TITLE_ERROR message:SC_UI_ALERT_INPUT_PIN delegate:self cancelButtonTitle:SC_UI_ALERT_OK otherButtonTitles:nil, nil];
        [alert show];
        return;
    }else if([name isEqualToString:@""]){
        name = @"Untitled";
    }
    [m_controller rtk_sc_gen_control_data:RTK_SC_CONTROL_RENAME pin:pin name:name];
    m_mode = MODE_CONTROL;
    
    // send data
    for (int i=0; i<RTK_SC_CONTROL_PKT_ROUND; i++) {
        NSLog(@"send delete profile data %d", i);
        [m_controller rtk_sc_send_control_data:ip];
    }
}

-(IBAction)scan_QRCode:(id)sender
{
    [self showQRScanner];
}

/* Timer Delegate */
-(void)timerHandler: (NSTimer *)sender
{
    unsigned int controller_mode = [m_controller rtk_sc_get_mode];
    switch (controller_mode) {
        case MODE_INIT:
            if (m_mode == MODE_CONTROL) {
                int result = [m_controller rtk_sc_get_control_result];
                if (result==RTK_SUCCEED) {
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:SC_UI_ALERT_TITLE_INFO message:SC_UI_ALERT_CONTROL_DONE delegate:self cancelButtonTitle:SC_UI_ALERT_OK otherButtonTitles:nil, nil];
                    [alert show];
                }else{
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:SC_UI_ALERT_TITLE_ERROR message:SC_UI_ALERT_CONTROL_FAILED delegate:self cancelButtonTitle:SC_UI_ALERT_OK otherButtonTitles:nil, nil];
                    [alert show];
                }
                m_mode = MODE_INIT;
            }
            break;
           
        default:
            break;
    }
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
    [pin_label setText:symbol.data];
    //self.imageView.image = [info objectForKey:UIImagePickerControllerOriginalImage];
    [picker dismissViewControllerAnimated:YES completion:nil];
}
@end
