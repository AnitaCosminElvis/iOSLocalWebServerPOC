//
//  ServerThread.m
//  Server
//
//  Created by Cosmin Elvis Anita
//

#import "ServerThread.h"

ConnectionHandler* lastConn;


@implementation ServerThread

-(void)initialize{
    CFSocketContext ctx = {0,(__bridge void*)(self),NULL,NULL,NULL};
    
    serverSocket = CFSocketCreate(kCFAllocatorDefault, AF_INET, SOCK_STREAM, IPPROTO_TCP, kCFSocketAcceptCallBack, callbackHandler, &ctx);
    
    struct sockaddr_in sock_addr;
    memset(&sock_addr, 0, sizeof(sock_addr));
    sock_addr.sin_len = sizeof(sock_addr);
    sock_addr.sin_family = AF_INET;
    sock_addr.sin_port = htons(80);
    sock_addr.sin_addr.s_addr = INADDR_ANY;//INADDR_LOOPBACK INADDR_ANY
    
    CFDataRef dataRef = CFDataCreate(kCFAllocatorDefault, (UInt8*)&sock_addr,sizeof(sock_addr));
    CFSocketSetAddress(serverSocket, dataRef);
    CFRelease(dataRef);
    
}

- (void)main{
    CFRunLoopSourceRef loopRef = CFSocketCreateRunLoopSource(kCFAllocatorDefault, serverSocket, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), loopRef, kCFRunLoopCommonModes);
    CFRelease(loopRef);
    NSLog(@"Start Server!");
    CFRunLoopRun();
}

-(void)stopServer{
    CFSocketInvalidate(serverSocket);
    CFRelease(serverSocket);
    NSLog(@"Stop Server!");
    CFRunLoopStop(CFRunLoopGetCurrent());
}

void callbackHandler(CFSocketRef s,
                              CFSocketCallBackType type,
                              CFDataRef address,
                              const void* data,
                              void* info)
{
    switch (type) {
        case kCFSocketAcceptCallBack:{
            lastConn = [[ConnectionHandler alloc]init];
            
            CFStreamCreatePairWithSocket(kCFAllocatorDefault,
                                         *(CFSocketNativeHandle*)data,
                                         &(lastConn->streamReader),
                                         &(lastConn->streamWriter));
            CFReadStreamSetProperty(lastConn->streamReader,
                                    kCFStreamPropertyShouldCloseNativeSocket,
                                    kCFBooleanTrue);
            CFWriteStreamSetProperty(lastConn->streamWriter,
                                    kCFStreamPropertyShouldCloseNativeSocket,
                                    kCFBooleanTrue);
            }
            
            [lastConn start];

            break;
            
        default:
            break;
    }
}

- (NSString*) fetchMessage{
    NSString* msg = nil;
    
    if (lastConn && [lastConn isExecuting] && [lastConn isHandshakeOver]){
        NSData* data =  [lastConn->receivedMsgQueue lastObject];
        msg = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        [lastConn->receivedMsgQueue removeLastObject];
    }else{
        NSLog(@"No mesage available/received!");
    }
    
    return msg;
}

- (void) sendMessage:(NSString*) msg{
    if (lastConn && [lastConn isExecuting] && [lastConn isHandshakeOver]){
        [lastConn->sendMsgQueue insertObject:[msg dataUsingEncoding:NSUTF8StringEncoding] atIndex:0];
        
        [lastConn writeToStream:( NSOutputStream *) lastConn->out ];
    }else{
        NSLog(@"No connection available!");
    }
}

@end


