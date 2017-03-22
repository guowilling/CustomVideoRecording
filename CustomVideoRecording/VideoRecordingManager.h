//
//  VideoRecordingManager.h
//  CustomVideoRecording
//
//  Created by 郭伟林 on 17/1/18.
//  Copyright © 2017年 SR. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@protocol VideoRecordingManagerDelegate <NSObject>

- (void)updateRecordingProgress:(CGFloat)progress;

@end

@interface VideoRecordingManager : NSObject

@property (nonatomic, weak) id<VideoRecordingManagerDelegate> delegate;

@property (nonatomic, assign, readonly) BOOL isRecording;

@property (nonatomic, assign) CGFloat maxRecordingTime;
@property (nonatomic, assign, readonly) CGFloat currentRecordingTime;

@property (nonatomic, strong) NSString *videoPath;

@property (nonatomic, assign) BOOL autoSaveVideo;

@property (strong, nonatomic) AVCaptureVideoPreviewLayer *previewLayer;

- (void)startCapture;
- (void)stopCapture;

- (void)startRecoring;
- (void)stopRecoring;
- (void)stopRecordingHandler:(void (^)(UIImage *movieImage))handler;

- (void)openFlashLight;
- (void)closeFlashLight;

- (void)switchCameraInputDeviceToFront;
- (void)swithCameraInputDeviceToBack;

- (void)saveCurrentRecordingVideo;

@end
