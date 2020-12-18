//
//  ViewController.m
//  QuickMR
//
//  Created by PC on 2020/12/11.
//

#import "ViewController.h"
#import "keyDefine.h"
#import "VersionDataModel.h"

@interface ViewController () <NSTextFieldDelegate,NSControlTextEditingDelegate, NSComboBoxDelegate, NSComboBoxDataSource>

@property (unsafe_unretained) IBOutlet NSTextView *resultTextV;
@property (weak) IBOutlet NSTextField *repoId;
@property (weak) IBOutlet NSBox *relV;

@property (strong, nonatomic) NSMutableDictionary *projectIdDict;
@property (strong, nonatomic) NSString *mergeIID;
@property (strong, nonatomic) NSString *mergeUrl;
@property (strong, nonatomic) NSString *privateToken;

@property (weak) IBOutlet NSBox *tokenBox;
@property (weak) IBOutlet NSTextField *tokenField;

@property (weak) IBOutlet NSButton *descBtn;
@property (weak) IBOutlet NSTextField *descField;
@property (weak) IBOutlet NSButton *titleBtn;
@property (weak) IBOutlet NSTextField *titleField;
@property (weak) IBOutlet NSButton *delBtn;
@property (weak) IBOutlet NSButton *aprrovalBtn;
@property (weak) IBOutlet NSTextField *approvalField;

@property (weak) IBOutlet NSComboBox *curFolderComboBox;
@property (weak) IBOutlet NSComboBox *sourceComboBox;
@property (weak) IBOutlet NSComboBox *targetComboBox;
@property (weak) IBOutlet NSComboBox *projectComboBox;

@property (strong, nonatomic) NSMutableDictionary<NSString *, VersionDataModel *> *branchDict;

@end

@implementation ViewController

#pragma mark - chooseFile
- (IBAction)chooseFile:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setAllowsMultipleSelection:NO];
    [panel setCanChooseDirectories:YES];
    [panel setCanChooseFiles:NO];
    [panel setAllowsOtherFileTypes:YES];

    [panel beginWithCompletionHandler:^(NSInteger result) {
        if (result == NSModalResponseOK) {
            NSString *path = [panel.URLs.firstObject path];
            self.resultTextV.string = [NSString stringWithFormat:@"Choose Directory:%@", path];
            self.curFolderComboBox.stringValue = path;
            [self.curFolderComboBox addItemWithObjectValue:path];
            [self dealFolderWithPath:path];
        }
    }];
}

- (void)getRemoteUrl:(NSString *)path {
    VersionDataModel *model = nil;
    for (VersionDataModel *tmp in self.branchDict.allValues) {
        if ([tmp.folderPath isEqualToString:path]) {
            model = tmp;
            break;
        }
    }
    
    if (model.repo.length) {
        self.projectComboBox.stringValue = model.repo;
        [self getRepoId:model.repo];
        [self getBranches:path url:model.repo];
        return;
    }
    
    self.resultTextV.string = [NSString stringWithFormat:@"Start get project repo, PATH: %@",path];
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/git"];
    NSPipe *outPipe = [NSPipe pipe];
    task.standardOutput = outPipe;
    NSError *err = nil;
    task.currentDirectoryURL = [NSURL fileURLWithPath:path];
    task.arguments = @[@"ls-remote",@"--get-url", @"origin"];
    [task launchAndReturnError:&err];
    [task setTerminationHandler:^(NSTask *tmp){
        dispatch_async(dispatch_get_main_queue(), ^{
            NSData *data = [outPipe.fileHandleForReading readDataToEndOfFile];
            NSString *url = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            self.resultTextV.string = [NSString stringWithFormat:@"%@\nGet succecc: %@", self.resultTextV.string, url];
            
            url = [self replaceSpace:url];
            if ([url containsString:@"git@"]) {
                
                url = [url stringByReplacingOccurrencesOfString:@":" withString:@"/"];
                
                url = [url stringByReplacingOccurrencesOfString:@"git@" withString:@"https://"];
            }

            if ([url hasSuffix:@".git"]) {
                url = [url stringByReplacingOccurrencesOfString:@".git" withString:@""];
            }
            self.resultTextV.string = [NSString stringWithFormat:@"%@\nReplace git:%@", self.resultTextV.string, url];
            self.projectComboBox.stringValue = url;
            [self getRepoId:url];
            [self getBranches:path url:url];
        });
    }];
}

- (void)getBranches:(NSString *)path url:(NSString *)url {
    BOOL exist = [[NSFileManager defaultManager] fileExistsAtPath:path];
    if (!exist) {
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSTask *task = [[NSTask alloc] init];
        task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/git"];
        NSPipe *outPipe = [NSPipe pipe];
        task.standardOutput = outPipe;
        NSError *err = nil;
        task.currentDirectoryURL = [NSURL fileURLWithPath:path];
        task.arguments = @[@"branch",@"-r"];
        [task launchAndReturnError:&err];
        [task setTerminationHandler:^(NSTask *tmp){
            dispatch_async(dispatch_get_main_queue(), ^{
                NSData *data = [outPipe.fileHandleForReading readDataToEndOfFile];
                NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                str = [str stringByReplacingOccurrencesOfString:@"origin/" withString:@""];
                str = [str stringByReplacingOccurrencesOfString:@" " withString:@""];
                NSArray *arr = [str componentsSeparatedByString:@"\n"];
                NSMutableArray *tmp = [NSMutableArray arrayWithObject:@"master"];
                for (int i = 0; i < arr.count - 1; i++) {
                    NSString *obj = arr[i];
                    if ([obj containsString:@"HEAD"] || [obj isEqualToString:@"master"]) {
                        continue;
                    }
                    [tmp addObject:obj];
                }
                VersionDataModel *model = [VersionDataModel new];
                model.branches = tmp.copy;
                model.folderPath = path;
                model.repo = url;
                [self.branchDict setValue:model forKey:url];
            });
        }];
    });
}

- (void)getCurrentBranch:(NSString *)path {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSTask *task = [[NSTask alloc] init];
        task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/git"];
        NSPipe *outPipe = [NSPipe pipe];
        task.standardOutput = outPipe;
        NSError *err = nil;
        task.currentDirectoryURL = [NSURL fileURLWithPath:path];
        task.arguments = @[@"symbolic-ref", @"--short", @"HEAD"];
        [task launchAndReturnError:&err];
        [task setTerminationHandler:^(NSTask *tmp){
            dispatch_async(dispatch_get_main_queue(), ^{
                NSData *data = [outPipe.fileHandleForReading readDataToEndOfFile];
                NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                str = [self replaceSpace:str];
                self.sourceComboBox.stringValue = str;
            });
        }];
    });
}

- (void)getRepoId:(NSString *)remote {
    NSString *projectId = [self.projectIdDict objectForKey:remote];
    if (projectId.length) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.repoId.stringValue = projectId;
        });
        return;
    }
    
    self.repoId.stringValue = @"";
    
    NSURL *url = [NSURL URLWithString:remote];
    NSString *name = url.lastPathComponent;
    NSString *token = [[NSUserDefaults standardUserDefaults] objectForKey:kTokenKey];
    NSString *api = [NSString stringWithFormat:@"https://%@/api/v4/projects?private_token=%@&search=%@",url.host,token, name];
    NSURLSession *sesstion = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    NSURLSessionDataTask *task = [sesstion dataTaskWithURL:[NSURL URLWithString:api] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSString *projectId = nil;
        if (data) {
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([json isKindOfClass:NSArray.class]) {
                NSArray *arr = (NSArray *)json;
                for (NSDictionary *dict in arr) {
                    if ([dict isKindOfClass:NSDictionary.class]) {
                        if ([[dict objectForKey:@"web_url"] isEqualToString:remote]) {
                            NSNumber *projId = [dict objectForKey:@"id"];
                            projectId = projId.stringValue;
                        }
                    }
                }
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (projectId.length) {
                    self.repoId.stringValue = projectId;
            } else {
                self.resultTextV.string = [NSString stringWithFormat:@"%@\nGet Project ID Failured, please enter manual(check project homepage):%@", self.resultTextV.string, response.URL];
            }
        });
    }];
    [task resume];
}

- (void)dealFolderWithPath:(NSString *)path {
    [self checkFolder];
    [self getRemoteUrl:path];
    [self getCurrentBranch:path];
}

#pragma mark - NSComboBoxDelegate
- (void)comboBoxSelectionDidChange:(NSNotification *)notification {
    NSComboBox *box = notification.object;
    NSString *str = [box.dataSource comboBox:box objectValueForItemAtIndex:box.indexOfSelectedItem];
    if (box == self.curFolderComboBox) {
        [self dealFolderWithPath:str];
    }
    else if (box == self.projectComboBox) {
        [self chooseProject:str];
    }
}


- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)comboBox {
    if (comboBox == self.curFolderComboBox) {
        return self.branchDict.allKeys.count;
    } else if (comboBox == self.sourceComboBox || comboBox == self.targetComboBox) {
        VersionDataModel *model = [self.branchDict objectForKey:self.projectComboBox.stringValue];
        return model.branches.count;
    } else if (comboBox == self.projectComboBox) {
        return self.projectIdDict.allKeys.count;
    }
    return 0;
}

- (nullable id)comboBox:(NSComboBox *)comboBox objectValueForItemAtIndex:(NSInteger)index {
    NSString *str = @"";
    if (comboBox == self.curFolderComboBox) {
        if (self.branchDict.allValues.count > index) {
            VersionDataModel *model = self.branchDict.allValues[index];
            str = model.folderPath;
        }
    } else if (comboBox == self.sourceComboBox || comboBox == self.targetComboBox) {
        VersionDataModel *model = [self.branchDict objectForKey:self.projectComboBox.stringValue];
        if (model.branches.count > index) {
            str = [model.branches objectAtIndex:index];
        }
    } else if (comboBox == self.projectComboBox) {
        str = [self.projectIdDict.allKeys objectAtIndex:index];
    }
    
    return str;
}

- (void)chooseProject:(NSString *)key {
    VersionDataModel *model = [self.branchDict objectForKey:key];
    if (model) {
        self.curFolderComboBox.stringValue = model.folderPath;
        BOOL exist = [self checkFolder];
        if (exist) {
            [self getCurrentBranch:model.folderPath];
        }
    }
    
    NSString *projectId = [self.projectIdDict objectForKey:key];
    self.repoId.stringValue = projectId;
}

- (BOOL)checkFolder {
    BOOL exist = [[NSFileManager defaultManager] fileExistsAtPath:self.curFolderComboBox.stringValue];
    if (!exist) {
        NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:@"(NotExist)" attributes:@{NSForegroundColorAttributeName:[NSColor systemRedColor], NSFontAttributeName:[NSFont boldSystemFontOfSize:14]}];
        [attr appendAttributedString:[[NSAttributedString alloc] initWithString:self.curFolderComboBox.stringValue attributes:@{NSForegroundColorAttributeName:[NSColor systemGrayColor], NSFontAttributeName:[NSFont systemFontOfSize:13]}]];
        self.curFolderComboBox.attributedStringValue = attr;
    }
    return exist;
}

#pragma mark - NSControlTextEditingDelegate
- (void)controlTextDidChange:(NSNotification *)obj {
    NSTextField *field = obj.object;
    NSControlStateValue state = field.stringValue.length == 0 ? NSControlStateValueOff : NSControlStateValueOn;
    if (field == self.descField) {
        [self.descBtn setState:state];
    } else if (field == self.titleField) {
        [self.titleBtn setState:state];
    } else if (field == self.approvalField) {
        [self.aprrovalBtn setState:state];
    }
}

#pragma mark -
- (void)viewDidLoad {
    [super viewDidLoad];
    
//    NSString *appDomain = [[NSBundle mainBundle] bundleIdentifier];
//    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:appDomain];

    NSString *tokenStr = [[NSUserDefaults standardUserDefaults] stringForKey:kTokenKey];
    self.privateToken = tokenStr;
    if (!tokenStr.length) {
        [self.tokenField becomeFirstResponder];
        self.tokenBox.hidden = NO;
    } else {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateAfterActive) name:NSApplicationDidBecomeActiveNotification object:nil];
        [self setupUI];
    }
}

- (void)updateAfterActive {
    if (self.privateToken.length && self.projectComboBox.stringValue) {
        VersionDataModel *model = [self.branchDict objectForKey:self.projectComboBox.stringValue];
        if (model) {
            [self dealFolderWithPath:model.folderPath];
        }
    }
}

- (void)setupUI {
    self.approvalField.delegate = self;
    self.titleField.delegate = self;
    self.descField.delegate = self;
    
    self.curFolderComboBox.usesDataSource = YES;
    self.curFolderComboBox.delegate = self;
    self.curFolderComboBox.dataSource = self;
    self.sourceComboBox.usesDataSource = YES;
    self.sourceComboBox.delegate = self;
    self.sourceComboBox.dataSource = self;
    self.targetComboBox.usesDataSource = YES;
    self.targetComboBox.delegate = self;
    self.targetComboBox.dataSource = self;
    self.projectComboBox.usesDataSource = YES;
    self.projectComboBox.delegate = self;
    self.projectComboBox.dataSource = self;
    
    NSDictionary *modelDict = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kFolderItemsKey];
    [modelDict enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, NSData *data, BOOL * _Nonnull stop) {
        VersionDataModel *model = [VersionDataModel modelWithData:data];
        [self.branchDict setValue:model forKey:key];
    }];
    
    NSString *repoStr = [[NSUserDefaults standardUserDefaults] stringForKey:kRepoKey];
    NSString *folderStr = [self.branchDict objectForKey:repoStr].folderPath;
    NSString *repoIdStr = [[NSUserDefaults standardUserDefaults] stringForKey:kRepoIDKey];
    NSString *sourceStr = [[NSUserDefaults standardUserDefaults] stringForKey:kSourceKey];
    NSString *targetStr = [[NSUserDefaults standardUserDefaults] stringForKey:kTargetKey];
    NSDictionary *repoItemsDict = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kRepoItemsKey];
    if (repoItemsDict.allKeys.count) {
        [self.projectIdDict setValuesForKeysWithDictionary:repoItemsDict];
    }
    self.targetComboBox.stringValue = targetStr?:@"";
    self.sourceComboBox.stringValue = sourceStr?:@"";
    self.projectComboBox.stringValue = repoStr?:@"";
    self.repoId.stringValue = repoIdStr?:@"";
    self.curFolderComboBox.stringValue = folderStr?:@"";
}

- (void)recordItems {
    [[NSUserDefaults standardUserDefaults] setObject:self.projectComboBox.stringValue forKey:kRepoKey];
    [[NSUserDefaults standardUserDefaults] setObject:self.repoId.stringValue forKey:kRepoIDKey];
    [[NSUserDefaults standardUserDefaults] setObject:self.sourceComboBox.stringValue forKey:kSourceKey];
    [[NSUserDefaults standardUserDefaults] setObject:self.targetComboBox.stringValue forKey:kTargetKey];
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [self.branchDict enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, VersionDataModel * _Nonnull obj, BOOL * _Nonnull stop) {
        [dict setValue:obj.archiveData forKey:key];
    }];
    [[NSUserDefaults standardUserDefaults] setObject:dict.copy forKey:kFolderItemsKey];
    
    [self.projectIdDict setValue:self.repoId.stringValue forKey:self.projectComboBox.stringValue];
    [[NSUserDefaults standardUserDefaults] setObject:self.projectIdDict forKey:kRepoItemsKey];
    
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (IBAction)clickCreateMR:(id)sender {
    
    if (!self.projectComboBox.stringValue.length) {
        self.resultTextV.string = @"Project Empty";
        return;
    }
    
    if (!self.repoId.stringValue.length) {
        self.resultTextV.string = @"Project ID Empty";
        return;
    }
    
    if (!self.sourceComboBox.stringValue.length) {
        self.resultTextV.string = @"Source Branch Empty";
        return;
    }
    if (!self.targetComboBox.stringValue.length) {
        self.resultTextV.string = @"Target Branch Empty";
        return;
    }
    
    NSString *title = self.titleBtn.state == NSControlStateValueOn && self.titleField.stringValue.length ? self.titleField.stringValue : @"";
    NSString *desc = self.descBtn.state == NSControlStateValueOn && self.descField.stringValue.length ? self.descField.stringValue : @"";
    NSString *approval = self.aprrovalBtn.state == NSControlStateValueOn && self.approvalField.stringValue.length ? self.approvalField.stringValue : @"";
    NSString *del = @(self.delBtn.state == NSControlStateValueOn).stringValue;
    NSArray *params = @[@"./versionPub-Merge", self.projectComboBox.stringValue, self.sourceComboBox.stringValue, self.targetComboBox.stringValue, self.repoId.stringValue, self.privateToken, title, desc, approval, del];
    
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:@"/bin/bash"];
    task.currentDirectoryURL = [NSURL fileURLWithPath:[NSBundle mainBundle].resourcePath];
    task.arguments = params;
    NSPipe *outPipe = [NSPipe pipe];
    task.standardOutput = outPipe;
    NSError *err = nil;
    [task launchAndReturnError:&err];
    [task setTerminationHandler:^(NSTask *tmp){
        dispatch_async(dispatch_get_main_queue(), ^{
            [self dealWithCreateMerge];
        });
    }];
    
    NSData *data = [outPipe.fileHandleForReading readDataToEndOfFile];
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    self.resultTextV.string = str;
}

- (void)dealWithCreateMerge {
    NSString *tag = @"Merge Request URL: ";
    NSRange range = [self.resultTextV.string rangeOfString:tag];
    if (range.length) {
        
        [self recordItems];
        
        self.mergeUrl = [self.resultTextV.string substringFromIndex:range.location+range.length];
        self.mergeUrl = [self replaceSpace:self.mergeUrl];
        range = [self.mergeUrl rangeOfString:@"merge_requests/"];
        self.mergeIID = [self.mergeUrl substringFromIndex:range.location+range.length];
    }
    self.relV.hidden = !range.length;
}

- (IBAction)doMerge:(id)sender {
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:@"/bin/bash"];
    task.currentDirectoryURL = [NSURL fileURLWithPath:[NSBundle mainBundle].resourcePath];
    task.arguments = @[@"./versionPub-State", self.projectComboBox.stringValue, self.mergeIID, self.repoId.stringValue, self.privateToken];
    NSPipe *outPipe = [NSPipe pipe];
    task.standardOutput = outPipe;
    NSError *err = nil;
    [task launchAndReturnError:&err];
    [task setTerminationHandler:^(NSTask *tmp){
        dispatch_async(dispatch_get_main_queue(), ^{
            [self dealWithUpdateMerge];
        });
    }];
    
    NSData *data = [outPipe.fileHandleForReading readDataToEndOfFile];
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    self.resultTextV.string = str;
}

- (IBAction)checkMerge:(id)sender {
    NSURL *url = [NSURL URLWithString:self.mergeUrl];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

- (void)dealWithUpdateMerge {
    NSLog(@"%@", self.resultTextV.string);
    
}

#pragma mark - token
- (IBAction)saveToken:(id)sender {
    if (!self.tokenField.stringValue.length) {
        return;
    }
    self.privateToken = self.tokenField.stringValue;
    [[NSUserDefaults standardUserDefaults] setObject:self.privateToken forKey:kTokenKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    self.tokenBox.hidden = YES;
    [self setupUI];
}

- (IBAction)clickTokenTip:(id)sender {
    NSURL *url = [NSURL URLWithString:@"https://git.example.cn/profile/personal_access_tokens"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

#pragma mark - private

- (NSString *)replaceSpace:(NSString *)string {
    return [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSMutableDictionary *)projectIdDict {
    if (_projectIdDict == nil) {
        _projectIdDict = [NSMutableDictionary dictionary];
    }
    return _projectIdDict;
}

- (NSMutableDictionary<NSString *,VersionDataModel *> *)branchDict {
    if (_branchDict == nil) {
        _branchDict = [NSMutableDictionary dictionary];
    }
    return _branchDict;
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
    
}

@end
