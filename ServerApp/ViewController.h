//
//  ViewController.h
//  ServerApp
//
//  Created by Cosmin Elvis Anita
//

#import <UIKit/UIKit.h>
#import "ServerThread.h"
#import  <WebKit/WebKit.h>

@interface ViewController : UIViewController {
    ServerThread *server;
    __weak IBOutlet UITextField *msgToSend;
    __weak IBOutlet UILabel *msgReceived;
    __weak IBOutlet WKWebView *webViewContent;
}


@end

