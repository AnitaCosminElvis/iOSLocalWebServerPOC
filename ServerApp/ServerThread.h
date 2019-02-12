//
//  ServerThread.h
//  Server
//
//  Created by Cosmin Elvis Anita
//

#import <Foundation/Foundation.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include "ConnectionHandler.h"
NS_ASSUME_NONNULL_BEGIN

@interface ServerThread : NSThread
{
    CFSocketRef serverSocket;
}

-(void)initialize;

-(void) main;

- (void)stopServer;
- (NSString*) fetchMessage;
- (void) sendMessage:(NSString*) msg;
@end

NS_ASSUME_NONNULL_END
