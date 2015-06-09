//
//  Cus360VideoController.m
//  WebRTC-demo
//
//  Created by customer360 on 29/05/15.
//  Copyright (c) 2015 customer360. All rights reserved.
//

#import "Cus360VideoController.h"
#import "ARDVideoCallView.h"
#import "RTCAVFoundationVideoSource.h"
#import "Cus360Base.h"

@interface Cus360VideoController ()<Cus360ClientDelegate, ARDVideoCallViewDelegate>
@property(nonatomic, readonly) ARDVideoCallView *_videoCallView;
@property(nonatomic, strong) RTCVideoTrack *localVideoTrack;
@property(nonatomic, strong) RTCVideoTrack *remoteVideoTrack;
@end

@implementation Cus360VideoController

@synthesize _videoCallView;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self initView];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void) initView
{
    [[Cus360Base shareInstance] setDelegate:self];
    _videoCallView = [[ARDVideoCallView alloc] initWithFrame:CGRectZero];
    _videoCallView.delegate = self;
    self.view = _videoCallView;
}


//-------------------------------------------------------------------------------------
#pragma mark - Cus360ClientDelegate

- (void)appClient:(Cus360Base *)client didChangeState:(Cus360ClientState)state
{
    NSLog(@"appClient -> didChangeState");
    switch (state) {
        case kARDAppClientStateConnected:
            NSLog(@"Client connected.");
            break;
        case kARDAppClientStateConnecting:
            NSLog(@"Client connecting.");
            break;
        case kARDAppClientStateDisconnected:
            NSLog(@"appClient disconnected -> hangup");
            [self hangup];
            break;
    }
}

- (void)appClient:(Cus360Base *)client didChangeConnectionState:(RTCICEConnectionState)state
{
    NSLog(@"appClient -> didChangeConnectionState");
    NSLog(@"ICE state changed: %d", state);
    __weak Cus360VideoController *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        //Cus360VideoController *strongSelf = weakSelf;
        //strongSelf._videoCallView.statusLabel.text = [strongSelf statusTextForState:state];
        switch (state) {
            case RTCICEConnectionDisconnected:
                NSLog(@"appClient RTCICEConnectionDisconnected -> hangup");
                [self hangup];
                break;
            
            case RTCICEConnectionClosed:
                NSLog(@"appClient RTCICEConnectionClosed -> hangup");
                [self hangup];
                break;
                
            default:
                break;
        }
    });
}

- (void)appClient:(Cus360Base *)client didReceiveLocalVideoTrack:(RTCVideoTrack *)localVideoTrack
{
    NSLog(@"appClient -> didReceiveLocalVideoTrack");
    self.localVideoTrack = localVideoTrack;
}

- (void)appClient:(Cus360Base *)client didReceiveRemoteVideoTrack:(RTCVideoTrack *)remoteVideoTrack
{
    NSLog(@"appClient -> didReceiveRemoteVideoTrack");
    self.remoteVideoTrack = remoteVideoTrack;
    _videoCallView.statusLabel.hidden = YES;
}

- (void)appClient:(Cus360Base *)client didError:(NSError *)error
{
    NSLog(@"appClient -> didError -> hangup");
    NSString *message =
    [NSString stringWithFormat:@"%@", error.localizedDescription];
    [self showAlertWithMessage:message];
    [self hangup];
}



//-------------------------------------------------------------------------------------
#pragma mark - Cus360ClientDelegate

- (void)videoCallViewDidHangup:(ARDVideoCallView *)view
{
    NSLog(@"Cus360ClientDelegate videoCallViewDidHangup -> hangup");
    [self hangup];
}

- (void)videoCallViewDidSwitchCamera:(ARDVideoCallView *)view
{
    // TODO(tkchin): Rate limit this so you can't tap continously on it.
    // Probably through an animation.
    [self switchCamera];
}



//-------------------------------------------------------------------------------------
#pragma mark - Private

- (void)setLocalVideoTrack:(RTCVideoTrack *)localVideoTrack {
    if (_localVideoTrack == localVideoTrack) {
        return;
    }
    [_localVideoTrack removeRenderer:_videoCallView.localVideoView];
    _localVideoTrack = nil;
    [_videoCallView.localVideoView renderFrame:nil];
    _localVideoTrack = localVideoTrack;
    [_localVideoTrack addRenderer:_videoCallView.localVideoView];
}

- (void)setRemoteVideoTrack:(RTCVideoTrack *)remoteVideoTrack {
    if (_remoteVideoTrack == remoteVideoTrack) {
        return;
    }
    [_remoteVideoTrack removeRenderer:_videoCallView.localVideoView];
    _remoteVideoTrack = nil;
    [_videoCallView.remoteVideoView renderFrame:nil];
    _remoteVideoTrack = remoteVideoTrack;
    [_remoteVideoTrack addRenderer:_videoCallView.remoteVideoView];
}

-(void) hangup
{
    NSLog(@"Cus360VideoController -> hangup");
    [[Cus360Base shareInstance] disconnect];
    
    if(_localVideoTrack)
    {
        [_localVideoTrack removeRenderer:_videoCallView.localVideoView];
        self.localVideoTrack = nil;
        [_videoCallView.localVideoView renderFrame:nil];
    }
    
    if(_remoteVideoTrack)
    {
        [_remoteVideoTrack removeRenderer:_videoCallView.remoteVideoView];
        self.remoteVideoTrack = nil;
        [_videoCallView.localVideoView renderFrame:nil];
    }
    
    //[_videoCallView removeFromSuperview];
    //[self removeFromParentViewController];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)switchCamera {
    RTCVideoSource* source = self.localVideoTrack.source;
    if ([source isKindOfClass:[RTCAVFoundationVideoSource class]]) {
        RTCAVFoundationVideoSource* avSource = (RTCAVFoundationVideoSource*)source;
        avSource.useBackCamera = !avSource.useBackCamera;
        _videoCallView.localVideoView.transform = avSource.useBackCamera ?
        CGAffineTransformIdentity : CGAffineTransformMakeScale(-1, 1);
    }
}

- (void)showAlertWithMessage:(NSString*)message {
    UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:nil
                                                        message:message
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
    [alertView show];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
