//
//  ViewController.m
//  ServerApp
//
//  Created by Cosmin Elvis Anita
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.

    NSURL *url = [[NSBundle mainBundle] URLForResource:@"websockethomepage" withExtension:@"html"];
    [webViewContent loadRequest:[NSURLRequest requestWithURL:url]];

}

- (IBAction)startServer:(id)sender {
    
    if (!server && ![server isExecuting]){
        server =[[ServerThread alloc] init];
        [server initialize];
        [server start];
    }
}

- (IBAction)stopServer:(id)sender {
    if (server && [server isExecuting]){
        [server stopServer];
        server = nil;
    }
}

- (IBAction)sendMsg:(id)sender {
    if (server && [server isExecuting]){
        [server sendMessage: msgToSend.text];
    }
}

- (IBAction)getMsg:(id)sender {
    if (server && [server isExecuting]){
        NSString* data = [server fetchMessage];
        msgReceived.text = data;
    }
}

@end
