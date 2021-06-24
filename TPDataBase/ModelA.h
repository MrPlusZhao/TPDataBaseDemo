//
//  ModelA.h
//  TPDataBase
//
//  Created by MrPlusZhao on 2021/5/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ModelA : NSObject

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *name2;
@property (nonatomic, strong) NSArray *cardsArr;
@property (nonatomic, strong) NSDictionary *xxDict;
@property (nonatomic, strong) NSNumber *num;
@property (nonatomic, assign) int age;
@property (nonatomic, assign) NSInteger ageNum;

@end

NS_ASSUME_NONNULL_END
