//
//  VideoRecordingWriter.h
//  CustomVideoRecording
//
//  Created by 郭伟林 on 17/1/18.
//  Copyright © 2017年 SR. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface VideoRecordingWriter : NSObject

@property (nonatomic, copy, readonly) NSString *videoPath;

+ (instancetype)recordingWriterWithVideoPath:(NSString*)videoPath
                             resolutionWidth:(NSInteger)width
                            resolutionHeight:(NSInteger)height
                                audioChannel:(int)channel
                                  sampleRate:(Float64)rate;

- (BOOL)writeWithSampleBuffer:(CMSampleBufferRef)sampleBuffer isVideo:(BOOL)isVideo;

- (void)finishWritingWithCompletionHandler:(void (^)(void))completion;

@end
