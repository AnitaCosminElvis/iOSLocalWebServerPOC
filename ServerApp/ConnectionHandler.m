//
//  ConnectionHandler.m
//  ServerApp
//
//  Created by Cosmin Elvis Anita
//

#import "ConnectionHandler.h"
#import <CommonCrypto/CommonDigest.h>

@implementation ConnectionHandler

-(void) main{
    isWaitingForFirstMessage = true;
    
    sendMsgQueue = [[NSMutableArray alloc] init];
    receivedMsgQueue = [[NSMutableArray alloc] init];
    
    in = (__bridge NSInputStream *)(streamReader);
    out = (__bridge NSOutputStream *)(streamWriter);
    
    [in setDelegate:self];
    [out setDelegate:self];
    
    [in scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [out scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    [in open];
    [out open];
    
    CFRunLoopRun();
}

-(void) stream:(NSStream*) stream handleEvent:(NSStreamEvent) evCode{
    switch (evCode) {
        case NSStreamEventHasSpaceAvailable:{
            [self writeToStream:(NSOutputStream*) stream];
            NSLog(@"Trying to write!");
        }
            break;
        case NSStreamEventHasBytesAvailable:{
            [self readFromStream:(NSInputStream*) stream];
            NSLog(@"Trying to read!");
        }
            break;
        case NSStreamEventEndEncountered:{
            NSLog(@"%i: %s", -1, "Info - Stream ended!");
            [self stopConnection];
        }
            break;
        case NSStreamEventErrorOccurred:{
            NSError *error = [stream streamError];
            NSLog(@"%li: %@", [error code], [error localizedDescription]);
            [self stopConnection];
        }
            break;
        default:
            [self writeToStream:(NSOutputStream*) stream];
            NSLog(@"Trying to write!");
            NSLog(@"%lu: %s", (unsigned long)evCode, "Error - Invalid event!");
            break;
    }
}

-(void) readFromStream: (NSInputStream*) rStream{
    uint8_t buffer[LINE_MAX];
    long size = [rStream read:buffer maxLength:LINE_MAX];
    
    if (0 < size){
        NSData *data = [NSData dataWithBytes:buffer length:size];

        if (isWaitingForFirstMessage){
            htmlMessage = CFHTTPMessageCreateEmpty(NULL, YES);
            if ([self isValidHttpToWebSocketUpgrade:(NSData*) data]){
                [self sendHandshakeResponse:(NSData*) data];
            }else{
                NSLog(@"%i: %s", -1, "Error - Invalid handshake!");
                [self stopConnection];
            }
        }else{
            if (false == [self isValidWebSocketData: (UInt8)(*(UInt8*)[data bytes])]){
                NSLog(@"%i: %s", -1, "Error - Invalid data!");
                [self stopConnection];
            }else{
                [receivedMsgQueue insertObject:[self decodeFrame:(NSData *) data] atIndex:0];
            }
        }
    }else{
        NSLog(@"%i: %s", -1, "Error - Invalid message size received!");
        //TO DO case for message greater then 2048
    }
}

-(void) writeToStream: (NSOutputStream*) wStream{
    
    if (0 < [sendMsgQueue count]){
        NSData* data = [sendMsgQueue lastObject];
        //TO DO manage special case when message is bigger then 2mb
        if (LINE_MAX > data.length){
            if (isWaitingForFirstMessage){
                isWaitingForFirstMessage = false;
            }else{
                data = [self encodeFrame:(NSData *) data];
            }
            
            uint8_t* dataBytes = (uint8_t*)[data bytes];
            
            if (0 < [wStream write:dataBytes maxLength:data.length]){
                [sendMsgQueue removeLastObject];
            }else{
                NSLog(@"%i: %s", -1, "Error - Unable to send message!");
            }

        }else{
            NSLog(@"%i: %s", -1, "Error - Message too large!");
        }
    }
}

-(NSData*) decodeFrame:(NSData*) data{
    UInt8* dataBytes = (UInt8*)[data bytes];
    UInt8  startLenPos = 0x1;
    UInt8  maskPos = 0x0;
    UInt8  dataPos = 0x0;
    UInt64 msgLen = 0x0;
    UInt8 sizeIndicator = (dataBytes[1] & ((UInt8) 0x7F));
    
    switch(sizeIndicator){
        case 0x7D:
            msgLen = (UInt16)dataBytes[startLenPos];
            msgLen <<= 1;
            maskPos = 0x9;
            dataPos = 0xD;
            break;
        case 0x7E:
            msgLen = (UInt64)dataBytes[startLenPos];
            msgLen <<= 1;
            maskPos = 0x4;
            dataPos = 0x8;
            break;
        default:
            msgLen = sizeIndicator;
            maskPos = 0x2;
            dataPos = 0x6;
            break;
    }
    
    UInt8 msg[msgLen];
    
    for (UInt8 i = 0; i < msgLen; ++i){
        msg[i] = (UInt8) (dataBytes[i + dataPos] ^ dataBytes[(i % 4 ) + maskPos]);
    }
   
    return [NSData dataWithBytes:&msg length:(msgLen)];
   //TO DO - check opcode
   //TO DO - invalidate other non frames messages
}

-(NSData*) encodeFrame:(NSData*) data{
    UInt8  dataPos = 0x0;
    UInt8* dataBytes = (UInt8*)[data bytes];
    UInt8 msg[0xD + data.length];
    
    memset(&msg, '\0', sizeof(msg));
    
    msg[0] = 0x81;
    
    if (0x7E > data.length){
            msg[1] = (UInt8) data.length;
            dataPos = 0x2;
    }else if (0x7E <= data.length && data.length >= UINT_MAX){
            msg[1] = (UInt16) data.length;
            dataPos = 0x4;
    }else{
        msg[1] = (UInt64) data.length;
        dataPos = 0xA;
    }
    
    for (UInt8 i = 0; i < data.length; ++i){
        msg[i + dataPos] = (UInt8) (dataBytes[i]);
    }
    
    return [NSData dataWithBytes:&msg length:(data.length + dataPos)];
}

-(BOOL) isValidHttpToWebSocketUpgrade: (NSData*) data{
    //TO DO - implement validation of upgrading from http/https to ws/wss
    return true;
}

- (BOOL)isValidWebSocketData:(UInt8)dataHead
{
    NSUInteger reservs =  dataHead & 0x70;
    NSUInteger opcode = dataHead & 0x0F;
    
    if ((0x0 != reservs) ||
        ((0x3 <= opcode) && (opcode <= 0x7)) ||
        ((0xB <= opcode) && (opcode <= 0xF)))
    {
        return false;
    }
    
    return true;
}

-(BOOL) isFrameMasked: (NSData*) data{
    return ((*((UInt8*)[data bytes])) & 0x80) ? YES : NO;
}

-(void) sendHandshakeResponse: (NSData*) data{
    if (CFHTTPMessageAppendBytes(htmlMessage, [data bytes], [data length])){
        NSString* key = (__bridge_transfer NSString *)CFHTTPMessageCopyHeaderFieldValue(htmlMessage, (__bridge CFStringRef)@"Sec-WebSocket-Key");
        key = [self generateAcceptedKey:(NSString*) key];
        
        CFHTTPMessageRef responseMsg = CFHTTPMessageCreateResponse(NULL,
                                                                  (CFIndex)101,
                                                                  (__bridge CFStringRef)@"Switching Protocols",
                                                                  (__bridge CFStringRef)@"HTTP/1.1");
        CFHTTPMessageSetHeaderFieldValue(responseMsg,
                                         (__bridge CFStringRef)@"Upgrade",
                                         (__bridge CFStringRef)@"webSocket");
        CFHTTPMessageSetHeaderFieldValue(responseMsg,
                                         (__bridge CFStringRef)@"Connection",
                                         (__bridge CFStringRef)@"Upgrade");
        CFHTTPMessageSetHeaderFieldValue(responseMsg,
                                         (__bridge CFStringRef)@"Sec-WebSocket-Accept",
                                         (__bridge CFStringRef)key);
        [sendMsgQueue insertObject: (__bridge NSData*)CFHTTPMessageCopySerializedMessage(responseMsg) atIndex:0];
    }
}

- (NSString *) generateAcceptedKey: (NSString*) key{
    unsigned char result[CC_SHA1_DIGEST_LENGTH];

    NSData* bufferKey = [[key stringByAppendingString: @"258EAFA5-E914-47DA-95CA-C5AB0DC85B11"] dataUsingEncoding: NSUTF8StringEncoding];
    
    CC_SHA1([bufferKey bytes], (CC_LONG)[bufferKey length], result);
    NSData* sha1Key = [NSData dataWithBytes:result length:CC_SHA1_DIGEST_LENGTH];
    
    return [sha1Key base64EncodedStringWithOptions:0];
}

-(void) stopConnection{
    [in close];
    [out close];
    
    CFRunLoopStop(CFRunLoopGetCurrent());
    NSLog(@"Stoping Connection!");
}

-(BOOL) isHandshakeOver{
    return !isWaitingForFirstMessage;
}

@end
