//
//  VideoRecordingProgress.h
//  CustomVideoRecording
//
//  Created by 郭伟林 on 17/1/18.
//  Copyright © 2017年 SR. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface VideoRecordingProgress : UIView

@property (nonatomic, assign) float progress;

@property (nonatomic, strong) UIColor *progressTintColor;

- (void)setProgress:(float)progress animated:(BOOL)animated;

@end
