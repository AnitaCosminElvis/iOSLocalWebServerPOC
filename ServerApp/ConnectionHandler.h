//
//  ConnectionHandler.h
//  ServerApp
//
//  Created by Cosmin Elvis Anita
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ConnectionHandler : NSThread{
    @public
    CFReadStreamRef             streamReader;
    CFWriteStreamRef            streamWriter;
    
    //TO DO add a synchronized queue class to replace these arrays
    NSMutableArray* sendMsgQueue;
    NSMutableArray* receivedMsgQueue;
    __strong NSOutputStream*    out;
    @private
    __strong NSInputStream*     in;
    
    CFHTTPMessageRef htmlMessage;
    
    BOOL isWaitingForFirstMessage;
    
}

-(void) main;

-(void) readFromStream: (NSInputStream*) rStream;
-(void) writeToStream: (NSOutputStream*) wStream;
-(NSData*) decodeFrame:(NSData*) data;
-(NSData*) encodeFrame:(NSData*) data;
-(BOOL) isValidHttpToWebSocketUpgrade: (NSData*) data;
- (BOOL)isValidWebSocketData:(UInt8)dataHead;
-(BOOL) isFrameMasked: (NSData*) data;
-(void) sendHandshakeResponse: (NSData*) data;
- (NSString *) generateAcceptedKey: (NSString*) key;
-(void) stopConnection;
-(BOOL) isHandshakeOver;

@end

NS_ASSUME_NONNULL_END
