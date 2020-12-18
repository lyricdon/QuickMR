//
//  PreferViewController.m
//  QuickMR
//
//  Created by PC on 2020/12/15.
//

#import "PreferViewController.h"
#import "keyDefine.h"

@interface PreferViewController ()

@end

@implementation PreferViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
}

- (IBAction)confirm:(id)sender {
    if (!self.tokenField.stringValue.length) {
        return;
    }
    
    [[NSUserDefaults standardUserDefaults] setValue:self.tokenField.stringValue forKey:kTokenKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    
}

@end
