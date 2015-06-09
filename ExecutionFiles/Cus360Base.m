//
//  Cus360Base.m
//  WebRTC-demo
//
//  Created by customer360 on 27/05/15.
//  Copyright (c) 2015 customer360. All rights reserved.
//

#import "Cus360Base.h"
#import "XMPP.h"
#import "XMPPPing.h"
#import "XMPPFramework.h"
#import "Cus360VideoController.h"
#import "RTCSessionDescription.h"
#import "RTCPeerConnectionDelegate.h"
#import "RTCSessionDescriptionDelegate.h"
#import "RTCMediaStream.h"
#import "RTCMediaConstraints.h"
#import "RTCAVFoundationVideoSource.h"
#import "RTCPair.h"
#import "RTCICEServer.h"
#import "RTCICECandidate.h"


static NSString * const kARDAppClientErrorDomain = @"ARDAppClient";
static NSInteger const kARDAppClientErrorUnknown = -1;
static NSInteger const kARDAppClientErrorRoomFull = -2;
static NSInteger const kARDAppClientErrorCreateSDP = -3;
static NSInteger const kARDAppClientErrorSetSDP = -4;
static NSInteger const kARDAppClientErrorInvalidClient = -5;
static NSInteger const kARDAppClientErrorInvalidRoom = -6;


static NSString* const _hostName = @"webrtc.customer360.co";
static int const _port = 5222;
static NSString* const _jid = @"rohit@c360dev.in";
static NSString* const _iceUrl = @"turn:global.turn.twilio.com:3478?transport=udp";
static NSString* const _iceUsername = @"4b4daf3720f9d46ed8227fcc28c5ff3edd44f3a973f946e12afbb1a3b14da511";
static NSString* const _icePassword = @"oVTNWKYbazMpAD3GP5P+bka7ocGbh6JMBGyDl5jGMTA=";


//-------------------------------------------------------------------------------------
#pragma mark - ### Interface ###
@interface Cus360Base()<XMPPStreamDelegate,XMPPRosterDelegate,RTCPeerConnectionDelegate,RTCSessionDescriptionDelegate>
{
    UITextField *_mainText;
    RTCMediaStream *localStream_Global;
}

@property (nonatomic, strong) XMPPRosterCoreDataStorage *_xmppRosterStorage;
@property (nonatomic, strong) XMPPRoster *_xmppRoster;
@property (nonatomic, strong) XMPPReconnect *_xmppReconnect;

-(void) setupXMPP;
-(void) connectXMPP;
-(void) goOnline;
-(void) goOffline;
-(void) sendPing;
@end


//-------------------------------------------------------------------------------------
#pragma mark - ### Implementation ###
@implementation Cus360Base

@synthesize _xmppStream;
@synthesize _xmppRosterStorage;
@synthesize _xmppRoster;
@synthesize _xmppReconnect;
@synthesize _cusBaseView;
@synthesize _peerConnection;
@synthesize _factory;
@synthesize _iceServers;
@synthesize _delegate;

static Cus360Base *_sharedInstance = nil;

+(Cus360Base*)shareInstance
{
    if(_sharedInstance == nil)
        _sharedInstance = [[Cus360Base alloc] init];
    return _sharedInstance;
}

-(void) setDelegate: (id<Cus360ClientDelegate>)delegate
{
    _delegate = delegate;
}

-(void) initWebRTCWithView:(UIViewController*) _baseView
{
    NSLog(@"-> Cus360Base::launchWebRTC");
    
    _cusBaseView = _baseView;
    
    [self setupXMPP];
    [self configureWebRTC];
    [self connectXMPP];
}

-(void) disconnect
{
    if(!_peerConnection)
    {
        NSLog(@"_peerConnection == NULL");
        return;
    }
    if(!localStream_Global)
    {
        NSLog(@"localStream_Global == NULL");
        return;
    }
    
    NSLog(@"Stream count = %d",[[_peerConnection localStreams] count]);
    for(RTCMediaStream *stream in [_peerConnection localStreams])
    {
        [_peerConnection removeStream:stream];
    }
    //[_peerConnection localStreams];
    //[_peerConnection removeStream:localStream_Global];
    [_peerConnection close];
    
    
    //if(_peerConnection)
    {
       // [_peerConnection close];
      //  _peerConnection = nil;
    }
    
    /*if(_factory)
    {
        _factory = nil;
    }*/
}


//-------------------------------------------------------------------------------------
#pragma mark - XMPP Setup

-(void) setupXMPP
{
    _xmppStream = [[XMPPStream alloc] init];
    [_xmppStream addDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    _xmppRosterStorage = [[XMPPRosterCoreDataStorage alloc] initWithInMemoryStore];
    
    _xmppRoster = [[XMPPRoster alloc] initWithRosterStorage:_xmppRosterStorage];
    [_xmppRoster addDelegate:self delegateQueue:dispatch_get_main_queue()];
    _xmppRoster.autoFetchRoster =YES;
    _xmppRoster.autoAcceptKnownPresenceSubscriptionRequests = YES;
    
    [_xmppRoster activate:_xmppStream];
    
    _xmppReconnect = [[XMPPReconnect alloc] init];
    [_xmppReconnect activate:_xmppStream];
    
    [_xmppStream oldSchoolSecureConnectWithTimeout:10 error:nil];
}

-(void) connectXMPP
{
    if([_xmppStream isConnected])
    {
        NSLog(@"-> XMPPStream isConnected");
        return;
    }
    [_xmppStream setHostName:_hostName];
    [_xmppStream setHostPort:_port];
    [_xmppStream setMyJID:[XMPPJID jidWithString:_jid]];
    
    if(![_xmppStream connectWithTimeout:XMPPStreamTimeoutNone error:nil])
    {
        UIAlertView *_alert = [[UIAlertView alloc] initWithTitle:@"Error Connecting" message:@"See console for more details" delegate:nil cancelButtonTitle:@"ok" otherButtonTitles:nil, nil];
        
        [_alert show];
    }
}

-(void) goOnline
{
    XMPPPresence *_presence = [XMPPPresence presenceWithType:@"available"];
    [_xmppStream sendElement:_presence];
}

-(void) goOffline
{
    XMPPPresence *_presence = [XMPPPresence presenceWithType:@"unavailable"];
    [_xmppStream sendElement:_presence];
}

-(void) sendPing
{
    XMPPPing *_ping = [[XMPPPing alloc] init];
    [_ping activate:_xmppStream];
    [_ping sendPingToServer];
    [_ping sendPingToJID:[XMPPJID jidWithString:@"rohit@c360dev.in"]];
}


//-------------------------------------------------------------------------------------
#pragma mark - Configure WebRTC
-(void) configureWebRTC
{
    _factory = [[RTCPeerConnectionFactory alloc] init];
    _iceServers = [NSMutableArray arrayWithObject:[self defaultServer]];
}




//-------------------------------------------------------------------------------------
#pragma mark - XMPPStream Delegates

- (void)xmppStream:(XMPPStream *)sender socketDidConnect:(GCDAsyncSocket *)socket
{
    NSLog(@"xmppDelegate -> socketDidConnect");
}

-(void)xmppStreamDidConnect:(XMPPStream *)sender
{
    NSLog(@"xmppDelegate -> xmppStreamDidConnect");
    //[(MyViewController*)_cusBaseView updateString:@"Connected to XMPP server."];
    [_xmppStream authenticateWithPassword:@"password" error:nil];
}

-(void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
{
    NSLog(@"xmppDelegate -> xmppStreamDidDisconnect: %@",error);
    //[(MyViewController*)_cusBaseView updateString:@"Disconnected to XMPP server."];
}

-(void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
    NSLog(@"xmppDelegate -> xmppStreamDidAuthenticate");
    //[(MyViewController*)_cusBaseView updateString:@"Ready to receive a call."];
    [self goOnline];
}

-(void)xmppStream:(XMPPStream *)sender didNotAuthenticate:(DDXMLElement *)error
{
    NSLog(@"xmppDelegate -> didNotAuthenticate: %@",error);
}

-(void)xmppStream:(XMPPStream *)sender didSendPresence:(XMPPPresence *)presence
{
    NSLog(@"xmppDelegate -> didSendPresence");
}

-(void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence
{
    NSLog(@"xmppDelegate -> didReceivePresence");
}

-(void)xmppStream:(XMPPStream *)sender didSendMessage:(XMPPMessage *)message
{
    NSLog(@"xmppDelegate -> didSendMessage");
}

-(void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
    NSLog(@"xmppDelegate -> didReceiveMessage");
    NSLog(@"message : %@",message.prettyXMLString);
    
    NSString *msgtype = [[message attributeForName:@"msgtype"]stringValue];
    
    if([msgtype isEqualToString:@"endcall"])
    {
        NSLog(@"disconnect xmppDelegate -> didReceiveMessage :: msgtype == endcall");
        [self disconnect];
        return;
    }
    NSString *_body = [[message elementForName:@"body"] stringValue];
    NSDictionary *_bodyDictionary = [[NSDictionary alloc]init];
    _bodyDictionary = [self dictionaryWithJSONString:_body];

    if ([msgtype isEqualToString:@"offer"]) {
        NSLog(@"->offer received");
        Cus360VideoController *_videoView = [[Cus360VideoController alloc] init];
        [_cusBaseView presentViewController:_videoView animated:YES completion:nil];
        
        [self processOfferWithMessage:_bodyDictionary];
    }else if([msgtype isEqualToString:@"candidate"])
    {
        NSLog(@"->candidate received");
        [self processCandidateWithMessage:_bodyDictionary];
    }
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
    NSLog(@"xmppDelegate -> didReceiveIQ");
    return NO;
}
/*
 set remote description
 create answer
 set local description
 on create success pe;
 */


//-------------------------------------------------------------------------------------
#pragma mark - XMPPRoster Delegates

-(void) xmppRoster:(XMPPRoster *)sender didReceiveRosterItem:(DDXMLElement *)item
{
    NSLog(@"xmppRosterDelegate -> didReceiveRosterItem");
}

-(void) xmppRoster:(XMPPRoster *)sender didReceiveRosterPush:(XMPPIQ *)iq
{
    NSLog(@"xmppRosterDelegate -> didReceiveRosterPush");
}

-(void) xmppRoster:(XMPPRoster *)sender didReceivePresenceSubscriptionRequest:(XMPPPresence *)presence
{
    NSLog(@"xmppRosterDelegate -> didReceivePresenceSubscriptionRequest");
}

- (void)xmppRoster:(XMPPRoster *)sender didReceiveBuddyRequest:(XMPPPresence *)presence
{
    NSLog(@"xmppRosterDelegate -> didReceiveBuddyRequest");
}


//-------------------------------------------------------------------------------------
#pragma mark - RTCPeerConnectionDelegate
- (void)peerConnection:(RTCPeerConnection *)peerConnection
 signalingStateChanged:(RTCSignalingState)stateChanged {
    NSLog(@"Signaling state changed: %d", stateChanged);
    NSLog(@"peerConnection -> signalingStateChanged");
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
           addedStream:(RTCMediaStream *)stream {
    NSLog(@"peerConnection -> addedStream");
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"Received %lu video tracks and %lu audio tracks",
              (unsigned long)stream.videoTracks.count,
              (unsigned long)stream.audioTracks.count);
        if (stream.videoTracks.count) {
            RTCVideoTrack *videoTrack = stream.videoTracks[0];
            [_delegate appClient:self didReceiveRemoteVideoTrack:videoTrack];
        }
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
         removedStream:(RTCMediaStream *)stream {
    NSLog(@"Stream was removed.");
    NSLog(@"peerConnection -> removedStream");
}

- (void)peerConnectionOnRenegotiationNeeded:
(RTCPeerConnection *)peerConnection {
    NSLog(@"WARNING: Renegotiation needed but unimplemented.");
    NSLog(@"peerConnection -> peerConnectionOnRenegotiationNeeded");
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
  iceConnectionChanged:(RTCICEConnectionState)newState {
    NSLog(@"peerConnection -> iceConnectionChanged");
    dispatch_async(dispatch_get_main_queue(), ^{
        [_delegate appClient:self didChangeConnectionState:newState];
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
   iceGatheringChanged:(RTCICEGatheringState)newState {
    NSLog(@"peerConnection -> iceGatheringChanged");
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
       gotICECandidate:(RTCICECandidate *)candidate {
    NSLog(@"peerConnection -> gotICECandidate");
    dispatch_async(dispatch_get_main_queue(), ^{
        [self sendCandidateWithMessage:candidate];
    });
}

- (void)peerConnection:(RTCPeerConnection*)peerConnection
    didOpenDataChannel:(RTCDataChannel*)dataChannel {
    NSLog(@"peerConnection -> didOpenDataChannel");
}



//-------------------------------------------------------------------------------------
#pragma mark - RTCSessionDescriptionDelegate
- (void)peerConnection:(RTCPeerConnection *)peerConnection didCreateSessionDescription:(RTCSessionDescription *)sdp
    error:(NSError *)error
{
    NSLog(@"peerConnection -> didCreateSessionDescription");
    dispatch_async(dispatch_get_main_queue(), ^{
       if(error)
       {
           NSLog(@"Failed to create session description. Error: %@", error);
           //[self disconnect];
           NSDictionary *userInfo = @{
                                      NSLocalizedDescriptionKey: @"Failed to create session description.",
                                      };
           NSError *sdpError =
           [[NSError alloc] initWithDomain:kARDAppClientErrorDomain
                                      code:kARDAppClientErrorCreateSDP
                                  userInfo:userInfo];
           [_delegate appClient:self didError:sdpError];
           return;
       }
        
        [_peerConnection setLocalDescriptionWithDelegate:self sessionDescription:sdp];
        
        NSString *desc = sdp.description;
        [self sendAnswerMessage:desc];
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didSetSessionDescriptionWithError:(NSError *)error
{
    NSLog(@"peerConnection -> didSetSessionDescriptionWithError");
    dispatch_async(dispatch_get_main_queue(), ^{
        if(error)
        {
            NSLog(@"Failed to set session description. Error: %@", error);
            //[self disconnect];
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: @"Failed to set session description.",
                                       };
            NSError *sdpError =
            [[NSError alloc] initWithDomain:kARDAppClientErrorDomain
                                       code:kARDAppClientErrorSetSDP
                                   userInfo:userInfo];
            [_delegate appClient:self didError:sdpError];
            return;
        }
        
        if(!_peerConnection.localDescription)
        {
            RTCMediaConstraints *constraints = [self defaultAnswerConstraints];
            [_peerConnection createAnswerWithDelegate:self constraints:constraints];
        }
    });
}





//-------------------------------------------------------------------------------------
#pragma mark - Messaging
- (void)sendAnswerMessage:(NSString *)sdpStr
{
    NSLog(@"sdp: %@", sdpStr);/*
                               NSDictionary *message = @{@"type": @"ANSWER",
                               @"src": _id,//id,
                               @"dst": _dstId,
                               @"payload":
                               @{@"browser": @"Chrome",
                               @"serialization": @"binary",
                               @"type": @"media",
                               @"connectionId": _connectionId,
                               //                                @"sdp": @{@"sdp": sdpStr, @"type": @"answer"} }
                               };*/
    NSDictionary * message =  @{@"sdp": sdpStr, @"type": @"answer"};
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:message options:0 error:nil];
    //[_messageQueue addObject:data];
    NSMutableString *msg = [[NSMutableString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    [msg replaceOccurrencesOfString:@"\r\n" withString:@"\n" options:NSLiteralSearch range:NSMakeRange(0, msg.length)];
    [self sendMessage:msg msgType:[message objectForKey:@"type"]];
}

- (void)sendCandidateWithMessage:(RTCICECandidate *)candidate
{
    NSDictionary *candidateObj = @{@"sdpMLineIndex": @(candidate.sdpMLineIndex),
                                   @"sdpMid": candidate.sdpMid,
                                   @"candidate": candidate.sdp.description};
    /*
     NSDictionary *message = @{@"type": @"CANDIDATE",
     @"src": _id,
     @"dst": _dstId,
     @"payload": @{
     @"type": @"media",
     @"connectionId": _connectionId,
     @"candidate": candidateObj}
     };*/
    
    NSDictionary *message = @{@"type": @"candidate",@"candidate": candidateObj};
    NSData* CandidateData =[NSJSONSerialization dataWithJSONObject:[message objectForKey:@"candidate"] options:0 error:nil];
    NSString *candidatemsg = [[NSString alloc]initWithData:CandidateData encoding:NSUTF8StringEncoding];
    [self sendMessage:candidatemsg msgType:[message objectForKey:@"type"]];
}

-(void)sendMessage:(NSString*)WebRTCmessage msgType:(NSString*) msgType
{
    NSLog(@"xmppStream -> WebRTCmessage");
    NSLog(@"WebRTCmessage = %@",WebRTCmessage);
    NSLog(@"msgType = %@",msgType);
    
    XMPPMessage * message = [XMPPMessage messageWithType:@"chat" to:[XMPPJID jidWithString:@"admin@c360dev.in"]];
    [message addAttributeWithName:@"msgtype" stringValue:msgType];
    [message addBody:WebRTCmessage];
    
    //    [message addThread:[[NSUserDefaults standardUserDefaults] objectForKey:@"msgThread"]];
    
    [_xmppStream sendElement:message];
    NSLog(@"%@",message);
}


//-------------------------------------------------------------------------------------
#pragma mark - Private methods
- (NSDictionary *)dictionaryWithJSONString:(NSString *)jsonString {
    NSParameterAssert(jsonString.length > 0);
    NSData *data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    NSDictionary *dict =
    [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error) {
        NSLog(@"Error parsing JSON: %@", error.localizedDescription);
    }
    return dict;
}

- (void)processOfferWithMessage:(NSDictionary *)message
{
    NSString *sdpMessage = [message objectForKey:@"sdp"];
    NSLog(@"remote sdp: %@", sdpMessage);
    
    // Create peer connection.
    RTCMediaConstraints *constraints = [self defaultPeerConnectionConstraints];
    _peerConnection = [_factory peerConnectionWithICEServers:_iceServers
                                                 constraints:constraints
                                                    delegate:self];
    
    // Create AV media stream and add it to the peer connection.
    //RTCMediaStream *localStream = [self createLocalMediaStream];
    localStream_Global = [self createLocalMediaStream];
    [_peerConnection addStream:localStream_Global];
    
    RTCSessionDescription *sdp = [[RTCSessionDescription alloc] initWithType:@"offer" sdp:sdpMessage];
    [_peerConnection setRemoteDescriptionWithDelegate:self sessionDescription:sdp];
}

- (void)processCandidateWithMessage:(NSDictionary *)message
{
    //  NSDictionary *payload = [message objectForKey:@"payload"];
    //NSDictionary *candidateObj = [message objectForKey:@"candidate"];
    NSString *candidateMessage = [message objectForKey:@"candidate"];
    NSInteger sdpMLineIndex = [[message objectForKey:@"sdpMLineIndex"] integerValue];
    NSString *sdpMid = [message objectForKey:@"sdpMid"]; NSLog(@"remote candidate: %@", message);
    RTCICECandidate *candidate = [[RTCICECandidate alloc] initWithMid:sdpMid index:sdpMLineIndex sdp:candidateMessage];
    [_peerConnection addICECandidate:candidate];
}


- (RTCMediaStream *)createLocalMediaStream {
    RTCMediaStream* localStream = [_factory mediaStreamWithLabel:@"ARDAMS"];
    RTCVideoTrack* localVideoTrack = [self createLocalVideoTrack];
    if (localVideoTrack) {
        [localStream addVideoTrack:localVideoTrack];
        [_delegate appClient:self didReceiveLocalVideoTrack:localVideoTrack];
    }
    [localStream addAudioTrack:[_factory audioTrackWithID:@"ARDAMSa0"]];
    return localStream;
}

- (RTCVideoTrack *)createLocalVideoTrack {
    RTCVideoTrack* localVideoTrack = nil;
    // The iOS simulator doesn't provide any sort of camera capture
    // support or emulation (http://goo.gl/rHAnC1) so don't bother
    // trying to open a local stream.
    // TODO(tkchin): local video capture for OSX. See
    // https://code.google.com/p/webrtc/issues/detail?id=3417.
#if !TARGET_IPHONE_SIMULATOR && TARGET_OS_IPHONE
    RTCMediaConstraints *mediaConstraints = [self defaultMediaStreamConstraints];
    RTCAVFoundationVideoSource *source = [[RTCAVFoundationVideoSource alloc] initWithFactory:_factory
                                            constraints:mediaConstraints];
    localVideoTrack =
    [[RTCVideoTrack alloc] initWithFactory:_factory
                                    source:source
                                   trackId:@"ARDAMSv0"];
#endif
    return localVideoTrack;
}



//-------------------------------------------------------------------------------------
#pragma mark - Defaults
- (RTCMediaConstraints *)defaultMediaStreamConstraints {
    RTCMediaConstraints* constraints =
    [[RTCMediaConstraints alloc]
     initWithMandatoryConstraints:nil
     optionalConstraints:nil];
    return constraints;
}

- (RTCMediaConstraints *)defaultAnswerConstraints {
    return [self defaultOfferConstraints];
}

- (RTCMediaConstraints *)defaultOfferConstraints {
    NSArray *mandatoryConstraints = @[
                                      [[RTCPair alloc] initWithKey:@"OfferToReceiveAudio" value:@"true"],
                                      [[RTCPair alloc] initWithKey:@"OfferToReceiveVideo" value:@"true"]
                                      ];
    RTCMediaConstraints* constraints =
    [[RTCMediaConstraints alloc]
     initWithMandatoryConstraints:mandatoryConstraints
     optionalConstraints:nil];
    return constraints;
}

- (RTCMediaConstraints *)defaultPeerConnectionConstraints {
    NSArray *optionalConstraints = @[
                                     [[RTCPair alloc] initWithKey:@"DtlsSrtpKeyAgreement" value:@"true"]
                                     ];
    RTCMediaConstraints* constraints =
    [[RTCMediaConstraints alloc]
     initWithMandatoryConstraints:nil
     optionalConstraints:optionalConstraints];
    return constraints;
}

- (RTCICEServer *)defaultServer {
    NSURL *defaultServerURL = [NSURL URLWithString:_iceUrl];
    return [[RTCICEServer alloc] initWithURI:defaultServerURL
                                    username:_iceUsername
                                    password:_icePassword];
}

@end
