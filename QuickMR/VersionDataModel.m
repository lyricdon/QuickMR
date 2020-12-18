//
//  VersionDataModel.m
//  QuickMR
//
//  Created by PC on 2020/12/16.
//

#import "VersionDataModel.h"

@implementation VersionDataModel

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super init]) {
        self.branches = [coder decodeObjectOfClass:NSArray.class forKey:@"branches"];
        self.repo = [coder decodeObjectForKey:@"repo"];
        self.folderPath = [coder decodeObjectForKey:@"folderPath"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.branches forKey:@"branches"];
    [coder encodeObject:self.repo forKey:@"repo"];
    [coder encodeObject:self.folderPath forKey:@"folderPath"];
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (NSData *)archiveData {
    NSError *err = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self requiringSecureCoding:YES error:&err];
    if (err) {
        NSLog(@"%@",err);
    }
    return data;
}

+ (VersionDataModel *)modelWithData:(NSData *)data {
    NSError *err = nil;
    VersionDataModel *model = [NSKeyedUnarchiver unarchivedObjectOfClass:self fromData:data error:&err];
    if (err) {
        NSLog(@"%@",err);
    }
    return model;
}

@end
