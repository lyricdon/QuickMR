//
//  VersionDataModel.h
//  QuickMR
//
//  Created by PC on 2020/12/16.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface VersionDataModel : NSObject <NSCoding, NSSecureCoding>

@property (copy, nonatomic) NSString *repo;
@property (copy, nonatomic) NSString *folderPath;
@property (copy, nonatomic) NSArray *branches;

- (NSData *)archiveData;

+ (VersionDataModel *)modelWithData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
