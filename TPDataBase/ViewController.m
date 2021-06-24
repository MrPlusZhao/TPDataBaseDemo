//
//  ViewController.m
//  TPDataBase
//
//  Created by ztp on 2021/6/23.
//

#import "ViewController.h"
#import "TPDataBase.h"
#import "ModelA.h"
#import "ModelB.h"
@interface ViewController ()

@end

@implementation ViewController

//1: 存储某个model,在表中,可以根据字段更新表, ----  ok
//2: 查询该表内的所有数据 ----   ok
//3: 根据某个字段查询数据
//4: 更新某个表中, 某一条数据的 某一个字段
//5: 根据接口返回数据做表格存储

- (void)viewDidLoad {
    [super viewDidLoad];

    
    ModelA *aa = [[ModelA alloc] init];
    aa.name = @"6";
    aa.name2 = @"66";
    aa.cardsArr = @[@"123",@"456"];
    aa.xxDict = @{@"qqq":@"666"};
    aa.num = [NSNumber numberWithInt:6];
    aa.age = 18;
    aa.ageNum = 19;
    [TPDataBase saveModel:aa UpdateTable:YES];
 
    NSArray *ArrNew = [TPDataBase FindModelClass:[ModelA class]];
    NSLog(@"%@",ArrNew);
    if (ArrNew.count > 0) {
        for (ModelA *model in ArrNew) {
            NSLog(@"%@",model.name);
        }
    }
}


@end

