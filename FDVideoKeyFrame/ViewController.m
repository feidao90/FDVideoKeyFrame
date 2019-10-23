//
//  ViewController.m
//  FDVideoKeyFrame
//
//  Created by 非道 on 2019/10/23.
//  Copyright © 2019 feidao. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface ViewController ()
{
    NSInteger _maxKeyFrameCount;
}

@property (nonatomic, strong) UIImageView *keyFrameImageView;
@property (nonatomic, strong) AVPlayer *player;
@end

@implementation ViewController

#pragma mark - _initSubViews
- (void)_initSubViews
{
    [self keyFrameImageView];
}

#pragma mark - getter method
-(UIImageView *)keyFrameImageView
{
    if (!_keyFrameImageView) {
        _keyFrameImageView = [[UIImageView alloc] init];
        _keyFrameImageView.backgroundColor = [UIColor redColor];
        [self.view addSubview:_keyFrameImageView];
    }
    return _keyFrameImageView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self _initSubViews];
    
    //获取首帧
    [self getFirstVideoKeyFrame];
    //所有帧
    [self getALLVideoKeyFrame];
}

#pragma mark - 视频处理
//获取视频首帧
- (void)getFirstVideoKeyFrame{
    AVURLAsset *asset = [self getVideoAsset];
    AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    generator.appliesPreferredTrackTransform=TRUE;
    CMTime thumbTime = CMTimeMakeWithSeconds(0,10);
    generator.maximumSize = self.view.frame.size;
    
    AVAssetImageGeneratorCompletionHandler handler =
    ^(CMTime requestedTime, CGImageRef im, CMTime actualTime, AVAssetImageGeneratorResult result, NSError *error){
            if (result != AVAssetImageGeneratorSucceeded) {}//没成功
            UIImage *thumbImg = [UIImage imageWithCGImage:im];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self dealWithImage:thumbImg];
            });
        };
    [generator generateCGImagesAsynchronouslyForTimes:[NSArray arrayWithObject:[NSValue valueWithCMTime:thumbTime]] completionHandler:handler];
}

//获取视频所有帧图像
- (void)getALLVideoKeyFrame{
    AVURLAsset *asset = [self getVideoAsset];
    AVAssetTrack *videoAssetTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    CGFloat duration = CMTimeGetSeconds(videoAssetTrack.timeRange.duration);
    AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    generator.maximumSize = self.view.frame.size;
    generator.appliesPreferredTrackTransform=TRUE;
    NSMutableArray *thumbTimes = [NSMutableArray array];
    
    _maxKeyFrameCount = (NSInteger)duration;
    for (int i = 0; i <= _maxKeyFrameCount; i ++) {
        [thumbTimes addObject:[NSValue valueWithCMTime:CMTimeMakeWithSeconds(i,duration)]];
    }
    
//    dispatch_semaphore_t actualSemaphore;
    NSMutableArray *resultImage = [NSMutableArray array];
    [generator generateCGImagesAsynchronouslyForTimes:thumbTimes completionHandler:^(CMTime requestedTime, CGImageRef  _Nullable image, CMTime actualTime, AVAssetImageGeneratorResult result, NSError * _Nullable error) {
        if (result != AVAssetImageGeneratorSucceeded) {
            NSLog(@"fail");
        }//没成功
        UIImage *thumbImg = [UIImage imageWithCGImage:image];
        CGFloat startTime = CMTimeGetSeconds(requestedTime);
        [resultImage addObject:thumbImg];
        if (self->_maxKeyFrameCount == (NSInteger)startTime) {
            __typeof(self) weakSelf = self;
            [self dealWithALLkeyFrameImages:[resultImage copy] withComplete:^(NSString *path) {
                __typeof(weakSelf) strongSelf = weakSelf;
                
                AVPlayerItem*videoItem = [[AVPlayerItem alloc] initWithURL:[NSURL fileURLWithPath:path]];
                strongSelf.player = [AVPlayer playerWithPlayerItem:videoItem];
                strongSelf.player.volume =0;
                AVPlayerLayer*playerLayer = [AVPlayerLayer playerLayerWithPlayer:strongSelf.player];
                playerLayer.backgroundColor = [UIColor whiteColor].CGColor;
                playerLayer.videoGravity =AVLayerVideoGravityResizeAspectFill;
                playerLayer.frame = CGRectMake(0, strongSelf.keyFrameImageView.frame.origin.y + strongSelf.keyFrameImageView.frame.size.height, strongSelf.keyFrameImageView.frame.size.width, strongSelf.keyFrameImageView.frame.size.height);
                [self.view.layer addSublayer:playerLayer];
                [strongSelf.player play];
                
                //监听视频播放
                [[NSNotificationCenter defaultCenter] addObserver:strongSelf selector:@selector(moviePlayDidEnd:)  name:AVPlayerItemDidPlayToEndTimeNotification object:strongSelf.player.currentItem];
            }];
        }
//        dispatch_semaphore_signal(actualSemaphore);
    }];
//    dispatch_semaphore_wait(actualSemaphore,DISPATCH_TIME_FOREVER);
    
}
#pragma mark - private method
//获取视频资源
- (AVURLAsset *)getVideoAsset{
    NSString *path = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"mp4"];
    NSURL *url = [NSURL fileURLWithPath:path];
    AVURLAsset *asset=[[AVURLAsset alloc] initWithURL:url options:nil];
    NSParameterAssert(asset);
    return asset;
}

- (void)dealWithImage:(UIImage *)keyFrameImage{
    CGFloat maxWidth = self.view.frame.size.width;
    CGFloat maxHeight = self.view.frame.size.height;
    
    self.keyFrameImageView.frame = CGRectMake(maxWidth/2 - keyFrameImage.size.width/2, maxHeight/2 - keyFrameImage.size.height/2, keyFrameImage.size.width, keyFrameImage.size.height);
    self.keyFrameImageView.image = keyFrameImage;
}

//处理关键帧，合成视频
- (void)dealWithALLkeyFrameImages:(NSArray <UIImage *> *)imageArray withComplete:(void(^)(NSString *path))completeBlock{
    //设置mov路径
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
    
    NSString *moviePath = [[paths objectAtIndex:0]stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.mov",@"test"]];
        
    //定义视频的大小320 480 倍数
    CGSize size = CGSizeMake(320,234);
    NSError *error = nil;
    //    转成UTF-8编码
    unlink([moviePath UTF8String]);
    NSLog(@"path->%@",moviePath);
    //     iphone提供了AVFoundation库来方便的操作多媒体设备，AVAssetWriter这个类可以方便的将图像和音频写成一个完整的视频文件
    AVAssetWriter *videoWriter = [[AVAssetWriter alloc]initWithURL:[NSURL fileURLWithPath:moviePath]fileType:AVFileTypeQuickTimeMovie error:&error];
    NSParameterAssert(videoWriter);
    if(error) {
        NSLog(@"error =%@",[error localizedDescription]);
        return;
    }
    //mov的格式设置 编码格式 宽度 高度
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:AVVideoCodecTypeH264,AVVideoCodecKey,
                                     [NSNumber numberWithInt:size.width],AVVideoWidthKey,
                                     [NSNumber numberWithInt:size.height],AVVideoHeightKey,nil];
    AVAssetWriterInput *writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    
    NSDictionary *sourcePixelBufferAttributesDictionary = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:kCVPixelFormatType_32ARGB],kCVPixelBufferPixelFormatTypeKey,nil];
    
    //    AVAssetWriterInputPixelBufferAdaptor提供CVPixelBufferPool实例,
    //    可以使用分配像素缓冲区写入输出文件。使用提供的像素为缓冲池分配通常
    //    是更有效的比添加像素缓冲区分配使用一个单独的池
    AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:writerInput sourcePixelBufferAttributes:sourcePixelBufferAttributesDictionary];
    NSParameterAssert(writerInput);
    NSParameterAssert([videoWriter canAddInput:writerInput]);
    if([videoWriter canAddInput:writerInput]){
        NSLog(@"添加图像帧成功");
    }else{
        NSLog(@"添加图像帧失败");
    }
    
    [videoWriter addInput:writerInput];
    [videoWriter startWriting];
    [videoWriter startSessionAtSourceTime:kCMTimeZero];
    
    //合成多张图片为一个视频文件
    dispatch_queue_t dispatchQueue = dispatch_queue_create("mediaInputQueue",NULL);
    int __block frame = 0;
    [writerInput requestMediaDataWhenReadyOnQueue:dispatchQueue usingBlock:^{
        while([writerInput isReadyForMoreMediaData]) {
            if(++frame >= [imageArray count] * 10) {
                [writerInput markAsFinished];
                [videoWriter finishWritingWithCompletionHandler:^{
                    NSLog(@"视频写入完成");
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                        NSLog(@"视频合成完毕");
                        completeBlock(moviePath);
                    }];
                }];
                break;
            }
            
            CVPixelBufferRef buffer = NULL;
            int idx = frame / 10;
            NSLog(@"idx==%d",idx);
            NSString *progress = [NSString stringWithFormat:@"%0.2lu",idx / [imageArray count]];
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                NSLog(@"合成进度:%@",progress);
            }];
            
            buffer = (CVPixelBufferRef)[self pixelBufferFromCGImage:[[imageArray objectAtIndex:idx]CGImage]size:size];
            if(buffer){
                //设置每秒钟播放图片的个数
                if(![adaptor appendPixelBuffer:buffer withPresentationTime:CMTimeMake(frame,10)]) {
                    NSLog(@"FAIL");
                } else {
                    NSLog(@"OK");
                }
                CFRelease(buffer);
            }
        }
    }];
}

- (CVPixelBufferRef)pixelBufferFromCGImage:(CGImageRef)image size:(CGSize)size {
    
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                           [NSNumber numberWithBool:YES],kCVPixelBufferCGImageCompatibilityKey,
                           [NSNumber numberWithBool:YES],kCVPixelBufferCGBitmapContextCompatibilityKey,nil];
    
    CVPixelBufferRef pxbuffer = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,size.width,size.height,kCVPixelFormatType_32ARGB,(__bridge CFDictionaryRef) options,&pxbuffer);
    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);
    CVPixelBufferLockBaseAddress(pxbuffer,0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    NSParameterAssert(pxdata !=NULL);
    CGColorSpaceRef rgbColorSpace=CGColorSpaceCreateDeviceRGB();
    
    CGContextRef context = CGBitmapContextCreate(pxdata,size.width,size.height,8,4*size.width,rgbColorSpace,kCGImageAlphaPremultipliedFirst);
    
    NSParameterAssert(context);
    CGContextDrawImage(context,CGRectMake(0,0,CGImageGetWidth(image),CGImageGetHeight(image)), image);
    // 释放色彩空间
    CGColorSpaceRelease(rgbColorSpace);
    // 释放context
    CGContextRelease(context);
    // 解锁pixel buffer
    CVPixelBufferUnlockBaseAddress(pxbuffer,0);
    
    return pxbuffer;
}

#pragma mark - notification actions
- (void)moviePlayDidEnd:(NSNotification*)notification{
    AVPlayerItem*item = [notification object];
    [item seekToTime:kCMTimeZero completionHandler:^(BOOL finished) {
        [self.player play];
    }];
}
@end
