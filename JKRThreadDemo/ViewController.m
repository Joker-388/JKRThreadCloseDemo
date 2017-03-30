//
//  ViewController.m
//  JKRThreadDemo
//
//  Created by tronsis_ios on 17/3/30.
//  Copyright © 2017年 tronsis_ios. All rights reserved.
//

#import "ViewController.h"
#import "NSObject+JKR_RunTime.h"
#import <pthread.h>
#import "JKRPort.h"

#ifndef weakify
#if DEBUG
#if __has_feature(objc_arc)
#define weakify(object) autoreleasepool{} __weak __typeof__(object) weak##_##object = object;
#else
#define weakify(object) autoreleasepool{} __block __typeof__(object) block##_##object = object;
#endif
#else
#if __has_feature(objc_arc)
#define weakify(object) try{} @finally{} {} __weak __typeof__(object) weak##_##object = object;
#else
#define weakify(object) try{} @finally{} {} __block __typeof__(object) block##_##object = object;
#endif
#endif
#endif

#ifndef strongify
#if DEBUG
#if __has_feature(objc_arc)
#define strongify(object) autoreleasepool{} __typeof__(object) object = weak##_##object;
#else
#define strongify(object) autoreleasepool{} __typeof__(object) object = block##_##object;
#endif
#else
#if __has_feature(objc_arc)
#define strongify(object) try{} @finally{} __typeof__(object) object = weak##_##object;
#else
#define strongify(object) try{} @finally{} __typeof__(object) object = block##_##object;
#endif
#endif
#endif

@interface ViewController ()

@property (nonatomic, strong) NSThread *thread;
 
@end

@implementation ViewController

/**
static BOOL stop;
static BOOL doMethod;
 
- (void)viewDidLoad {
    [super viewDidLoad];
    stop = NO;
    self.thread = [[NSThread alloc] initWithBlock:^{
        @autoreleasepool {
            NSLog(@"开启了一个子线程：%@", [NSThread currentThread]);
            [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer * _Nonnull timer) {
                NSLog(@"Time action : %@", [NSThread currentThread]);
                // 如果开关关闭就停止runloop
                if (stop) {
                    NSLog(@"移除runloop的source");
                    [timer invalidate];
                } else if (doMethod) {
                    [self testMethod];
                }
            }];
            [[NSRunLoop currentRunLoop] run];
            NSLog(@"Runloop finish");
        }
    }];
    [self.thread start];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    // 在自定义的常住线程中处理一个操作
    doMethod = YES;
}

- (void)testMethod {
    NSLog(@"在自定义的子线程中异步处理了一个耗时操作 : %@", [NSThread currentThread]);
    sleep(3.0);
    // 处理完操作后关闭常住线程
    NSLog(@"处理完耗时操作后关闭常住线程");
    stop = YES;
}

- (void)dealloc {
    NSLog(@"Thread isExecuting: %zd", [self.thread isExecuting]);
    NSLog(@"Thread isFinished: %zd", [self.thread isFinished]);
    NSLog(@"Thread isCancelled: %zd", [self.thread isCancelled]);
    NSLog(@"dealloc");
}
*/


static BOOL stop;
static BOOL doingMethod;

- (void)viewDidLoad {
    [super viewDidLoad];
    stop = NO;
    doingMethod = NO;
    // 创建一个常驻线程
    self.thread = [[NSThread alloc] initWithBlock:^{
        CFRunLoopSourceContext context = {0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL};
        CFRunLoopSourceRef source = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &context);
        // 给runloop添加一个自定义source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);
        // 给runloop添加一个状态监听者
        CFRunLoopObserverRef observer = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, kCFRunLoopAllActivities, YES, 0, ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
            switch (activity) {
                case kCFRunLoopBeforeWaiting:
                    NSLog(@"即将进入睡眠");
                    // 当runloop进入空闲时，即方法执行完毕后，判断runloop的开关，如果关闭就执行关闭操作
                {
                    if (stop) {
                        NSLog(@"关闭runloop");
                        // 移除runloop的source
                        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);
                        CFRelease(source);
                        // 没有source的runloop是可以通过stop方法关闭的
                        CFRunLoopStop(CFRunLoopGetCurrent());
                    }
                }
                    break;
                case kCFRunLoopExit:
                    NSLog(@"退出");
                    break;
                default:
                    break;
            }
        });
        CFRunLoopAddObserver(CFRunLoopGetCurrent(), observer, kCFRunLoopCommonModes);
        CFRunLoopRun();
        CFRelease(observer);
        NSLog(@"Runloop finish");
    }];
    [self.thread start];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!doingMethod) {
        doingMethod = YES;
        // 在该线程中异步执行一个方法
        [self performSelector:@selector(testMethod) onThread:self.thread withObject:nil waitUntilDone:YES];
    }
}

- (void)testMethod {
    NSLog(@"在自定义的子线程中异步处理了一个耗时操作 : %@", [NSThread currentThread]);
    sleep(3.0);
    // 处理完操作后关闭常住线程
    NSLog(@"处理完耗时操作后关闭常住线程");
    stop = YES;
}

- (void)dealloc {
    NSLog(@"Thread isExecuting: %zd", [self.thread isExecuting]);
    NSLog(@"Thread isFinished: %zd", [self.thread isFinished]);
    NSLog(@"Thread isCancelled: %zd", [self.thread isCancelled]);
    NSLog(@"dealloc");
}


/**
- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.port = [NSPort port];
    self.thread = [[NSThread alloc] initWithBlock:^{
        [[NSRunLoop currentRunLoop] addPort:self.port forMode:NSDefaultRunLoopMode];
        [[NSRunLoop currentRunLoop] run];
        NSLog(@"Runloop finish");
    }];
    [self.thread start];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self performSelector:@selector(testMethod) onThread:self.thread withObject:nil waitUntilDone:YES];
}

- (void)testMethod {
    NSLog(@"线程内执行方法: %@", [NSThread currentThread]);
    [[NSRunLoop currentRunLoop] removePort:self.port forMode:NSDefaultRunLoopMode];
}

- (void)dealloc {
    NSLog(@"Thread isExecuting: %zd", [self.thread isExecuting]);
    NSLog(@"Thread isFinished: %zd", [self.thread isFinished]);
    NSLog(@"Thread isCancelled: %zd", [self.thread isCancelled]);
    NSLog(@"dealloc");
}
 */


@end
