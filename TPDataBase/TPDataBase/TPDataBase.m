//
//  TPDataBase.m
//  TPDataBase
//
//  Created by MrPlusZhao on 2021/5/24.
//

#import "TPDataBase.h"

#import <objc/runtime.h>

#pragma mark - TPDataBase 工具类区域
@implementation TPDataBase

@synthesize dbQueue = _dbQueue;

static TPDataBase *_database = nil;
+ (instancetype)shared{
    static dispatch_once_t onceToken ;
    dispatch_once(&onceToken, ^{
        _database = [[self alloc] init] ;
    }) ;
    return _database;
}
- (id)copyWithZone:(struct _NSZone *)zone{
    return [TPDataBase shared];
}
+ (NSString *)dbPath{
    NSString *docsdir = [NSSearchPathForDirectoriesInDomains( NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSFileManager *filemanage = [NSFileManager defaultManager];
    docsdir = [docsdir stringByAppendingPathComponent:@"TPDB"];
    BOOL isDir;
    BOOL exit =[filemanage fileExistsAtPath:docsdir isDirectory:&isDir];
    if (!exit || !isDir) {
        [filemanage createDirectoryAtPath:docsdir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString *dbpath = [docsdir stringByAppendingPathComponent:@"tpdb.sqlite"];
    NSLog(@"%@",dbpath);
    return dbpath;
}
//创建多线程安全的数据库
- (FMDatabaseQueue *)dbQueue{
    if (_dbQueue == nil) {
        _dbQueue = [[FMDatabaseQueue alloc] initWithPath:[[self class] dbPath]];
    }
    return _dbQueue;
}

#pragma mark - 存数据
+ (BOOL)saveModel:(NSObject*)model{
    [TPDataBase createTable:model Update:NO];
    return [TPDataBase save:model];
}
+ (BOOL)saveModel:(NSObject*)model UpdateTable:(BOOL)update{
    [TPDataBase createTable:model Update:update];
    return [TPDataBase save:model];
}

#pragma mark - 查数据
///** 查询全部数据 */
////@"SELECT * FROM %@",tableName      有个表名就完事了
////查询结果先赋值给模型，再用一个数组装起来
+ (NSArray *)FindModelClass:(Class)ModelClass{
    TPDataBase *TPDB = [TPDataBase shared];
    NSMutableArray *users = [NSMutableArray array];
    [TPDB.dbQueue inDatabase:^(FMDatabase *db) {
        NSString *sql = [NSString stringWithFormat:@"SELECT * FROM %@",NSStringFromClass(ModelClass)];
        FMResultSet *resultSet = [db executeQuery:sql];
        while ([resultSet next]) {
            NSObject *model = [TPDataBase setModelValue:ModelClass Result:resultSet];
            [users addObject:model];
            FMDBRelease(model);
        }
    }];
    
    return users;
}
/** 通过条件查找数据 */
+ (NSArray *)FindModelClass:(Class)ModelClass Key:(NSString*)key Value:(NSString*)value{
    TPDataBase *jkDB = [TPDataBase shared];
    NSMutableArray *users = [NSMutableArray array];
    [jkDB.dbQueue inDatabase:^(FMDatabase *db) {
        //拿到表名,查询条件就是参数criteria
        NSString *tableName = NSStringFromClass(ModelClass.class);
        NSString *sql = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ = %@",tableName,key,value];
        FMResultSet *resultSet = [db executeQuery:sql];
        //从数据库中查询出来的数据有2种：字符串，整形，我必须对这2种数据区分处理
        while ([resultSet next]) {
            NSObject *model = [TPDataBase setModelValue:ModelClass Result:resultSet];
            [users addObject:model];
            FMDBRelease(model);
        }
    }];
    return users;
}
/**
 * 创建表
 * 如果已经创建，返回YES
 */
+ (BOOL)createTable:(NSObject*)model Update:(BOOL)update{
    //拿到数据库路径，创建数据库
    FMDatabase *db = [FMDatabase databaseWithPath:[TPDataBase dbPath]];
    //开启数据库
    if (![db open]) {
        NSLog(@"数据库打开失败!");
        return NO;
    }
    NSString *tableName = NSStringFromClass(model.class);
    //拿到存有所有属性（包括自己添加的主键字段）的字典
    NSDictionary *propertyDict = [TPDataBase getPropertys:model];
    NSDictionary *allPropertyDict = [TPDataBase addPrimaryId:propertyDict];
    NSString *columeAndType = [TPDataBase getColumeAndTypeString:model Properties:allPropertyDict];;
    //创建字段，columeAndType中保存的是模型中所有的属性名与属性类型
    NSString *sql = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@(%@);",tableName,columeAndType];
    if (![db executeUpdate:sql]) {
        return NO;
    }
    if (!update) { // 如果不查找 更新表中字段, 那么直接返回 YES
        [db close];
        return YES;
    }
    // 接下来查找并且更新字段,如果有新增字段的话
    NSMutableArray *columns = [NSMutableArray array];
    FMResultSet *resultSet = [db getTableSchema:tableName];
    while ([resultSet next]) {
        //取出结果集中name对应的值，即字段的名称（取出所有的字段名）
        NSString *column = [resultSet stringForColumn:@"name"];
        [columns addObject:column];
    }
    
    //拿到所有属性名
    NSArray *properties = [allPropertyDict objectForKey:@"name"];
    //这个过滤数组的作用：检查模型中所有的属性在数据库中是否都有对应的字段，如果没有，立即新增一个字段
    NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"NOT (SELF IN %@)",columns];
    //过滤数组
    NSArray *resultArray = [properties filteredArrayUsingPredicate:filterPredicate];

    for (NSString *column in resultArray) {
        NSUInteger index = [properties indexOfObject:column];
        NSString *proType = [[allPropertyDict objectForKey:@"type"] objectAtIndex:index];
        NSString *fieldSql = [NSString stringWithFormat:@"%@ %@",column,proType];
        //在表中添加新的字段（或者说新的列）
        NSString *sql = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ ",NSStringFromClass(model.class),fieldSql];
        if (![db executeUpdate:sql]) {
            return NO;
        }
    }
    [db close];
    return YES;
}
+ (BOOL)save:(NSObject*)model{
    NSString *tableName          = NSStringFromClass(model.class);
    NSMutableString *keyString   = [NSMutableString string];
    NSMutableString *valueString = [NSMutableString string];
    NSMutableArray *insertValues = [NSMutableArray  array];
    
    NSDictionary *dict = [TPDataBase getAllProperties:model];
    NSMutableArray *proNames = [dict objectForKey:@"name"];
    NSMutableArray *proTypes = [dict objectForKey:@"type"];
    
    for (int i = 0; i < proNames.count; i++) {
        NSString *proname = [proNames objectAtIndex:i];
        [keyString appendFormat:@"%@,", proname];
        [valueString appendString:@"?,"];
        //【KVC】通过KVC将属性值取出来(运行时配合KVC还真方便)
        id value = nil;
        if ([proTypes[i] isEqualToString:SQLARRAY]) {//数组存储前先反序列化为二进制数据
            NSArray *array = [model valueForKey:proname];
            NSError *error;
            if (@available(iOS 11.0, *)) {
                value = [NSKeyedArchiver archivedDataWithRootObject:array requiringSecureCoding:YES error:&error];
            }
            else{
                value = [NSKeyedArchiver archivedDataWithRootObject:array];
            }
        }
        else if([proTypes[i] isEqualToString:SQLMAP]){//字典存储前先反序列化为二进制数据
            NSDictionary *dictionary = [model valueForKey:proname];
            NSString *dicJson = [TPDataBase jsonStringWithDict:dictionary];
            value = dicJson;
        }
        else if([proTypes[i] isEqualToString:SQLMODEL]){//模型存储前先反序列化为二进制数据
            id tempModel = [model valueForKey:proname];
            NSError *error;
            if (@available(iOS 11.0, *)) {
                value = [NSKeyedArchiver archivedDataWithRootObject:tempModel requiringSecureCoding:YES error:&error];
            }
            else{
                value = [NSKeyedArchiver archivedDataWithRootObject:tempModel];
            }
        }else {
            value = [model valueForKey:proname];
        }
        //属性值可能为空
        if (!value) {
            value = @"";
        }
        [insertValues addObject:value];
    }
    //删除最后的那个","
    [keyString deleteCharactersInRange:NSMakeRange(keyString.length - 1, 1)];
    [valueString deleteCharactersInRange:NSMakeRange(valueString.length - 1, 1)];
    
    TPDataBase *DB = [TPDataBase shared];
    __block BOOL res = NO;
    [DB.dbQueue inDatabase:^(FMDatabase *db) {
        NSString *sql = [NSString stringWithFormat:@"INSERT INTO %@(%@) VALUES (%@);", tableName, keyString, valueString];
        //这个方法会自动到一个数组中去取值
        res = [db executeUpdate:sql withArgumentsInArray:insertValues];
        NSLog(res?@"插入成功":@"插入失败");
    }];
    return res;
}
/** 获取模型中的所有属性，并且添加一个主键字段pk。这些数据都存入一个字典中 */
+ (NSDictionary *)getAllProperties:(id)model{
    return [TPDataBase getPropertys:model];
}
+ (NSDictionary*)addPrimaryId:(NSDictionary*)dict{
    NSMutableArray *proNames = [NSMutableArray array];
    NSMutableArray *proTypes = [NSMutableArray array];
    [proNames addObject:primaryId];
    [proTypes addObject:[NSString stringWithFormat:@"%@ %@",SQLINTEGER,PrimaryKey]];
    [proNames addObjectsFromArray:[dict objectForKey:@"name"]];
    [proTypes addObjectsFromArray:[dict objectForKey:@"type"]];
    return [NSDictionary dictionaryWithObjectsAndKeys:proNames,@"name",proTypes,@"type",nil];
}
//将属性名与属性类型拼接成sqlite语句：integer a,real b,...
+ (NSString *)getColumeAndTypeString:(id)model Properties:(NSDictionary*)propertyDict{
    NSMutableString* pars    = [NSMutableString string];
    NSMutableArray *proNames = [propertyDict objectForKey:@"name"];
    NSMutableArray *proTypes = [propertyDict objectForKey:@"type"];
    for (int i=0; i< proNames.count; i++) {
        [pars appendFormat:@"%@ %@",[proNames objectAtIndex:i],[proTypes objectAtIndex:i]];
        if(i+1 != proNames.count){
            [pars appendString:@","];
        }
    }
    return pars;
}
/**
 *  获取该类的所有属性以及属性对应的类型,并且存入字典中
 */
+ (NSDictionary *)getPropertys:(NSObject*)model{
    //存放模型中所有的属性名
    NSMutableArray *proNames = [NSMutableArray array];
    //存放模型中所有属性对应的类型(sqlite数据类型)
    NSMutableArray *proTypes = [NSMutableArray array];
    unsigned int outCount, i;
    objc_property_t *properties = class_copyPropertyList([model class], &outCount);
    for (i = 0; i < outCount; i++) {
        objc_property_t property = properties[i];
        //获取属性名
        NSString *propertyName = [NSString stringWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
        [proNames addObject:propertyName];
        //获取属性类型等参数
        NSString *propertyType = [NSString stringWithCString: property_getAttributes(property) encoding:NSUTF8StringEncoding];
         // SQLite 默认支持五种数据类型TEXT、INTEGER、REAL、BLOB、NULL
        if ([propertyType hasPrefix:@"T@\"NSArray\""]) {//属性类型是数组
            [proTypes addObject:SQLARRAY];
        }else if ([propertyType hasPrefix:@"T@\"NSDictionary\""]){//字典类型
            [proTypes addObject:SQLMAP];
        }else if ([propertyType hasPrefix:@"T@\"NSString\""]){//@:字符串
            [proTypes addObject:SQLTEXT];
        }else if ([propertyType hasPrefix:@"T@"]){//以T@开头的类型，只剩下模型类型了
            [proTypes addObject:SQLMODEL];
        }else if ([propertyType hasPrefix:@"Ti"]||[propertyType hasPrefix:@"TI"]||[propertyType hasPrefix:@"Ts"]||[propertyType hasPrefix:@"TS"]||[propertyType hasPrefix:@"TB"]) {//i,I(integer):整形； s(short):短整形； B(BOOL):布尔；
            [proTypes addObject:SQLINTEGER];
        } else {
            [proTypes addObject:SQLREAL];
        }
        
    }
    free(properties);
    
    return [NSDictionary dictionaryWithObjectsAndKeys:proNames,@"name",proTypes,@"type",nil];
}
+ (NSObject*)setModelValue:(Class)ModelClass Result:(FMResultSet*)resultSet{
    NSString *name = NSStringFromClass(ModelClass);
    Class cls = NSClassFromString(name);
    NSObject *model = [[cls alloc] init];
    NSDictionary *propertyDict = [TPDataBase getPropertys:model];
    NSMutableArray *proNames = [propertyDict objectForKey:@"name"];
    NSMutableArray *proTypes = [propertyDict objectForKey:@"type"];
    for (int i=0; i< proNames.count; i++) {
        NSString *columeName = [proNames objectAtIndex:i];
        NSString *columeType = [proTypes objectAtIndex:i];
        if ([columeType isEqualToString:SQLARRAY]) {
            NSData *data = [resultSet dataForColumn:columeName];
            NSArray *array;
            NSError *error;
            if (@available(iOS 11.0, *)) {
                array = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSArray class] fromData:data error:&error];
            }
            else{
                array = [NSKeyedUnarchiver unarchiveObjectWithData:data];
            }
            [model setValue:array forKey:columeName];
        }
        else if ([columeType isEqualToString:SQLMAP]){
            NSString *jsonDict = [resultSet stringForColumn:columeName];
            NSDictionary *dictionary = [TPDataBase dictionaryWithJsonString:jsonDict];
            [model setValue:dictionary forKey:columeName];
        }
        else if ([columeType isEqualToString:SQLMODEL]){
            NSData *data = [resultSet dataForColumn:columeName];
            id mo;
            NSError *error;
            if (@available(iOS 11.0, *)) {
                mo = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSObject class] fromData:data error:&error];
            }
            else{
                mo = [NSKeyedUnarchiver unarchiveObjectWithData:data];
            }
            [model setValue:mo forKey:columeName];
        }else if ([columeType isEqualToString:SQLTEXT]) {
            [model setValue:[resultSet stringForColumn:columeName] forKey:columeName];
        } else {
            [model setValue:[NSNumber numberWithLongLong:[resultSet longLongIntForColumn:columeName]] forKey:columeName];
        }
    }
    return model;
}
+ (NSString *)jsonStringWithDict:(NSDictionary *)dict {
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
    NSString *jsonString;
    if (!jsonData) {
        NSLog(@"%@",error);
    }else{
        jsonString = [[NSString alloc]initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    return jsonString;
}
+ (NSDictionary *)dictionaryWithJsonString:(NSString *)jsonString{
    if (jsonString == nil) {
        return nil;
    }
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *err;
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:jsonData
                                                        options:NSJSONReadingMutableContainers
                                                          error:&err];
    if(err){
        NSLog(@"json解析失败：%@",err);
        return nil;
    }
    return dic;
}

@end
