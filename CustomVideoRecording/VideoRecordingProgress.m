//
//  VideoRecordingProgress.m
//  CustomVideoRecording
//
//  Created by 郭伟林 on 17/1/18.
//  Copyright © 2017年 SR. All rights reserved.
//

#import "VideoRecordingProgress.h"

#pragma mark - RecordingProgressViewBackgroundLayer

@interface RecordingProgressViewBackgroundLayer : CALayer

@property (nonatomic, strong) UIColor *tintColor;

@end

@implementation RecordingProgressViewBackgroundLayer

- (id)init {
    
    if (self = [super init]) {
        self.contentsScale = [UIScreen mainScreen].scale;
    }
    return self;
}

- (void)setTintColor:(UIColor *)tintColor {
    
    _tintColor = tintColor;
    
    [self setNeedsDisplay];
}

- (void)drawInContext:(CGContextRef)ctx {
    
    CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
    CGFloat WH = self.bounds.size.width * 0.3;
    CGContextFillRect(ctx, CGRectMake(CGRectGetMidX(self.bounds) - WH * 0.5, CGRectGetMidY(self.bounds) - WH * 0.5, WH, WH));
    CGContextSetStrokeColorWithColor(ctx, _tintColor.CGColor);
    CGContextStrokeEllipseInRect(ctx, CGRectInset(self.bounds, 1, 1));
}

@end

#pragma mark - VideoRecordingProgress

@interface VideoRecordingProgress ()

@property (nonatomic, strong) RecordingProgressViewBackgroundLayer *backgroundLayer;
@property (nonatomic, strong) CAShapeLayer *shapeLayer;

@end

@implementation VideoRecordingProgress

- (instancetype)initWithFrame:(CGRect)frame {
    
    if (self = [super initWithFrame:frame]) {
        _progressTintColor = [UIColor blackColor];
        
        _backgroundLayer           = [[RecordingProgressViewBackgroundLayer alloc] init];
        _backgroundLayer.frame     = self.bounds;
        _backgroundLayer.tintColor = self.progressTintColor;
        [self.layer addSublayer:_backgroundLayer];
        
        _shapeLayer             = [[CAShapeLayer alloc] init];
        _shapeLayer.frame       = self.bounds;
        _shapeLayer.fillColor   = nil;
        _shapeLayer.strokeColor = _progressTintColor.CGColor;
        [self.layer addSublayer:_shapeLayer];
    }
    return self;
}

- (void)setProgress:(float)progress animated:(BOOL)animated {
    
    _progress = progress;
    
    if (progress <= 0) {
        [self.shapeLayer removeAnimationForKey:@"strokeEndAnimation"];
        return;
    }
    self.shapeLayer.lineWidth = 3;
    self.shapeLayer.path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds))
                                                          radius:self.bounds.size.width / 2 - 2
                                                      startAngle:3 * M_PI_2
                                                        endAngle:3 * M_PI_2 + 2 * M_PI
                                                       clockwise:YES].CGPath;
    if (animated) {
        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
        animation.fromValue = [self.shapeLayer animationForKey:@"indeterminateAnimation"] ? @0 : nil;
        animation.toValue = [NSNumber numberWithFloat:progress];
        animation.duration = 1;
        self.shapeLayer.strokeEnd = progress;
        [self.shapeLayer addAnimation:animation forKey:@"strokeEndAnimation"];
    } else {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        self.shapeLayer.strokeEnd = progress;
        [CATransaction commit];
    }
}

- (void)setProgress:(float)progress {
    
    [self setProgress:progress animated:NO];
}

- (void)setProgressTintColor:(UIColor *)progressTintColor {
    
    _progressTintColor = progressTintColor;
    
    _backgroundLayer.tintColor = progressTintColor;
    _shapeLayer.strokeColor = progressTintColor.CGColor;
}

@end
