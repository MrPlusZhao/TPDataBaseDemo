//
//  TPDataBase.h
//  TPDataBase
//
//  Created by MrPlusZhao on 2021/5/24.
//

#import <Foundation/Foundation.h>
#import "FMDB.h"
/** SQLite五种数据类型 */
#define SQLTEXT     @"TEXT" //字符串
#define SQLINTEGER  @"INTEGER" //数字
#define SQLREAL     @"REAL" //bool
#define SQLBLOB     @"BLOB" //二进制
#define SQLNULL     @"NULL" //空

/// 自定义类型
#define SQLMODEL    @"MODEL"   //model数据类型
#define SQLMAP      @"MAP"     //NSDictionary数据类型
#define SQLARRAY    @"ARRAY"   //NSArray数据类型

#define PrimaryKey  @"primary key"
#define primaryId   @"pk"


NS_ASSUME_NONNULL_BEGIN

@interface TPDataBase : NSObject

@property(nonatomic,strong,readonly) FMDatabaseQueue *dbQueue;

+ (instancetype)shared;

//创建文件夹，拼接数据库路径
+ (NSString *)dbPath;

// 直接存model
+ (BOOL)saveModel:(NSObject*)model;
// 直接存model 有表字段更新得时候 需要 update
+ (BOOL)saveModel:(NSObject*)model UpdateTable:(BOOL)update;

/** 通过表名查找数据 */
+ (NSArray *)FindModelClass:(Class)ModelClass;
/** 通过条件查找数据 */
+ (NSArray *)FindModelClass:(Class)ModelClass Key:(NSString*)key Value:(NSString*)value;

@end

NS_ASSUME_NONNULL_END
