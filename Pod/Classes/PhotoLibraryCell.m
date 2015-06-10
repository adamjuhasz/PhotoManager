//
//  PhotoLibraryCell.m
//  Pods
//
//  Created by Adam Juhasz on 5/26/15.
//
//

#import "PhotoLibraryCell.h"

@interface PhotoLibraryCell ()
{
    UIImageView *imageView;
}
@end

@implementation PhotoLibraryCell

- (void)commonInit
{
    self.backgroundColor = [UIColor darkGrayColor];
    
    imageView = [[UIImageView alloc] init];
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    [self addSubview:imageView];
    
    self.clipsToBounds = YES;
}

- (id)init
{
    self = [super init];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    imageView.frame = self.bounds;
}

- (void)setImage:(UIImage *)image
{
    imageView.image = image;
}

@end
