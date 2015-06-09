//
//  Cus360Base.h
//  WebRTC-demo
//
//  Created by customer360 on 27/05/15.
//  Copyright (c) 2015 customer360. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "RTCPeerConnection.h"
#import "RTCPeerConnectionFactory.h"
#import "RTCVideoTrack.h"


@class XMPPStream;
@class Cus360Base;
typedef NS_ENUM(NSInteger, Cus360ClientState) {
    // Disconnected from servers.
    kARDAppClientStateDisconnected,
    // Connecting to servers.
    kARDAppClientStateConnecting,
    // Connected to servers.
    kARDAppClientStateConnected,
};

@protocol Cus360ClientDelegate <NSObject>

- (void)appClient:(Cus360Base *)client didChangeState:(Cus360ClientState)state;

- (void)appClient:(Cus360Base *)client didChangeConnectionState:(RTCICEConnectionState)state;

- (void)appClient:(Cus360Base *)client didReceiveLocalVideoTrack:(RTCVideoTrack *)localVideoTrack;

- (void)appClient:(Cus360Base *)client didReceiveRemoteVideoTrack:(RTCVideoTrack *)remoteVideoTrack;

- (void)appClient:(Cus360Base *)client didError:(NSError *)error;

@end

@interface Cus360Base : NSObject

@property (nonatomic, strong) XMPPStream *_xmppStream;
@property (nonatomic, strong)  UIViewController *_cusBaseView;
@property(nonatomic, strong) RTCPeerConnection *_peerConnection;
@property(nonatomic, strong) RTCPeerConnectionFactory *_factory;
@property(nonatomic, strong) NSMutableArray *_iceServers;
@property(nonatomic, weak) id<Cus360ClientDelegate> _delegate;

#pragma mark - methods
+(Cus360Base*)shareInstance; // singleton method...

-(void) initWebRTCWithView:(UIViewController*) _baseView;
-(void) setDelegate: (id<Cus360ClientDelegate>)delegate;
-(void) disconnect;

@end
