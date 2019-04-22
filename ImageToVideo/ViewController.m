//
//  ViewController.m
//  ImageToVideo
//
//  Created by 徐城 on 2019/4/9.
//  Copyright © 2019年 Cheng. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];


    UIImage *image = [UIImage imageNamed:@"222.jpg"];
    
    NSDate *date = [NSDate new];
    NSString *string = [NSString stringWithFormat:@"%ld.mp4",(unsigned long)(date.timeIntervalSince1970 * 1000)];
    NSString *cachePath = [NSTemporaryDirectory() stringByAppendingPathComponent:string];
    if ([[NSFileManager defaultManager] fileExistsAtPath:cachePath]){
        [[NSFileManager defaultManager] removeItemAtPath:cachePath error:nil];
    }
    
    NSURL *exportUrl = [NSURL fileURLWithPath:cachePath];
    
    NSLog(@"s----%@",[exportUrl path]);
    CGSize size = CGSizeMake(720, 1280);
    
    AVAssetWriter *videoWriter = [[AVAssetWriter alloc] initWithURL:exportUrl fileType:AVFileTypeQuickTimeMovie error:nil];
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:AVVideoCodecH264, AVVideoCodecKey,[NSNumber numberWithInt:size.width], AVVideoWidthKey,[NSNumber numberWithInt:size.height], AVVideoHeightKey, nil];
    
    AVAssetWriterInput *writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    
    NSDictionary *sourcePixelBufferAttributesDictionary = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:kCVPixelFormatType_32ARGB], kCVPixelBufferPixelFormatTypeKey, nil];
    
    AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:writerInput sourcePixelBufferAttributes:sourcePixelBufferAttributesDictionary];
    NSParameterAssert(writerInput);
    NSParameterAssert([videoWriter canAddInput:writerInput]);
    
    if ([videoWriter canAddInput:writerInput])
        NSLog(@"");
    else
        NSLog(@"");
    
    [videoWriter addInput:writerInput];
    
    [videoWriter startWriting];
    [videoWriter startSessionAtSourceTime:kCMTimeZero];

    
    //合成多张图片为一个视频文件
    dispatch_queue_t dispatchQueue = dispatch_queue_create("mediaInputQueue", NULL);
    int __block frame = 0;
    
    [writerInput requestMediaDataWhenReadyOnQueue:dispatchQueue usingBlock:^{
        while ([writerInput isReadyForMoreMediaData])
        {
            if(++frame > 30)
            {
                [writerInput markAsFinished];
                //[videoWriter_ finishWriting];
                if(videoWriter.status == AVAssetWriterStatusWriting){
                    NSCondition *cond = [[NSCondition alloc] init];
                    [cond lock];
                    [videoWriter finishWritingWithCompletionHandler:^{
                        [cond lock];
                        [cond signal];
                        [cond unlock];
                    }];
                    [cond wait];
                    [cond unlock];
                }
                break;
            }
            CVPixelBufferRef buffer = (CVPixelBufferRef)[self pixelBufferFromCGImage:[image CGImage] size:size];
            
            if (buffer){
                if(![adaptor appendPixelBuffer:buffer withPresentationTime:CMTimeMake(frame, 90)])
                {
                    NSLog(@"fail");
                }else
                {
                    NSLog(@"success:%ld",frame);
                }
                CFRelease(buffer);
            }
        }
    }];

    
    
}


- (CVPixelBufferRef )pixelBufferFromCGImage:(CGImageRef)image size:(CGSize)size{
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey, nil];
    CVPixelBufferRef pxbuffer = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, size.width, size.height, kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef) options, &pxbuffer);
    
    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);
    
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    NSParameterAssert(pxdata != NULL);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata, size.width, size.height, 8, 4*size.width, rgbColorSpace, kCGImageAlphaPremultipliedFirst);
    NSParameterAssert(context);
    //CGSize drawSize = CGSizeMake(CGImageGetWidth(image), CGImageGetHeight(image));
    //BOOL baseW = drawSize.width < drawSize.height;
    
    
    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image), CGImageGetHeight(image)), image);
    
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    
    return pxbuffer;
}



@end
