//
//  PhotoManagerViewController.m
//  Pods
//
//  Created by Adam Juhasz on 5/26/15.
//
//

#import "PhotoManagerViewController.h"
#import "PhotoManager.h"
#import "PhotoLibraryCell.h"

@interface PhotoManagerViewController () <UICollectionViewDataSource, UICollectionViewDelegate>

@property UICollectionView *photoLibraryCollection;
@property UIImageView *demoImageView;
@end

@implementation PhotoManagerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.minimumInteritemSpacing = 1;
    layout.minimumLineSpacing = 1;
    layout.scrollDirection = UICollectionViewScrollDirectionVertical;
    CGFloat columns = 4;
    layout.itemSize = CGSizeMake((self.view.bounds.size.width - (columns-1)*layout.minimumInteritemSpacing - 1 )/columns, (self.view.bounds.size.width - (columns-1)*layout.minimumInteritemSpacing)/columns);
    
    self.photoLibraryCollection = [[UICollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:layout];
    self.photoLibraryCollection.dataSource = self;
    self.photoLibraryCollection.delegate = self;
    [self.photoLibraryCollection registerClass:[PhotoLibraryCell class] forCellWithReuseIdentifier:@"PhotoCell"];
    [self.view addSubview:self.photoLibraryCollection];
 
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressOnPhotoLibrary:)];
    longPress.allowableMovement = 4000;
    [self.photoLibraryCollection addGestureRecognizer:longPress];
}

- (void)viewWillLayoutSubviews
{
    self.photoLibraryCollection.frame = self.view.bounds;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    PhotoManager *shared = [PhotoManager sharedManager];
    NSInteger count = [shared countForAlbum:shared.cameraRollAlbumName];
    if (count <= 0) {
        [shared getAlbumNamesWhenDone:^{
            [_photoLibraryCollection reloadData];
        }];
        return 30;
        
    }
    return count;
}

-(UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    PhotoLibraryCell *myCell = [collectionView
                                  dequeueReusableCellWithReuseIdentifier:@"PhotoCell"
                                  forIndexPath:indexPath];
    
    long row = [indexPath row];
    
    PhotoManager *shared =  [PhotoManager sharedManager];
    if (shared.authorized) {
        [shared getThumbnailFor:shared.cameraRollAlbumName atIndex:row completionBlock:^(UIImage *image) {
            [myCell setImage:image];
        }];
    }
    
    return myCell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger index = [indexPath indexAtPosition:1];
    [[PhotoManager sharedManager] getThumbnailFor:[[PhotoManager sharedManager] cameraRollAlbumName]
                                          atIndex:index
                                  completionBlock:^(UIImage *image) {
                                      [self.delegate userDidChooseThumbnail:image];
    }];
    
    [[PhotoManager sharedManager] fullsizeImageIn:[[PhotoManager sharedManager] cameraRollAlbumName]
                                          atIndex:index
                                  completionBlock:^(UIImage *image, CLLocation *location) {
                                      [self.delegate userDidChooseFullImage:image atLocation:location];
                                  }];

}

- (void)longPressOnPhotoLibrary:(UILongPressGestureRecognizer*)recognizer
{
    static CGRect frameInMasterView;
    static NSTimer *fullResolutionTimer;
    UICollectionView *collectionView = (UICollectionView*)recognizer.view;
    CGPoint pointOfFinger = [recognizer locationInView:recognizer.view];
    NSIndexPath *indexPath = [collectionView indexPathForItemAtPoint:pointOfFinger];
    if (indexPath != nil) {
        UIView *cell = [collectionView cellForItemAtIndexPath:indexPath];
        frameInMasterView = [self.view convertRect:cell.frame fromView:collectionView];
        NSInteger index = [indexPath indexAtPosition:1];
        NSLog(@"thumbnail to show: %ld", (long) index);
        [[PhotoManager sharedManager] getThumbnailFor:[[PhotoManager sharedManager] cameraRollAlbumName] atIndex:index completionBlock:^(UIImage *image) {
            if (self.demoImageView == nil) {
                CGRect frame = self.view.superview.frame;
                frame.size = CGSizeMake( frame.size.width, frame.size.width );
                frame.origin = CGPointMake(0, 0);
                if (self.previewFrame) {
                    frame = [self.previewFrame CGRectValue];
                }
                self.demoImageView = [[UIImageView alloc] initWithFrame:frame];
                self.demoImageView.clipsToBounds = YES;
                self.demoImageView.contentMode = UIViewContentModeScaleAspectFill;
                [self.view.superview addSubview:self.demoImageView];
            }
            self.demoImageView.image = image;
            /*
            if (self.collectionViewEnlargedImage.hidden == YES) {
                POPSpringAnimation *frameAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPViewFrame];
                frameAnimation.fromValue = [NSValue valueWithCGRect:frameInMasterView];
                CGRect centeredFrame;
                centeredFrame.size = CGSizeMake(CGRectGetWidth(self.view.frame), CGRectGetWidth(self.view.frame));
                centeredFrame.origin = CGPointMake(0, CGRectGetMidY(self.view.frame)-centeredFrame.size.height/2.0);
                frameAnimation.toValue = [NSValue valueWithCGRect:centeredFrame];

                CGPoint cellTrueOrigin = CGPointMake(cell.frame.origin.x, cell.frame.origin.y - collectionView.contentOffset.y);
                if (cellTrueOrigin.y < collectionView.contentInset.top) {
                    CGFloat diff = collectionView.contentInset.top - cellTrueOrigin.y;
                    POPBasicAnimation *moveDownAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPScrollViewContentOffset];
                    moveDownAnimation.toValue = [NSValue valueWithCGPoint:CGPointMake(collectionView.contentOffset.x, collectionView.contentOffset.y - diff)];
                    moveDownAnimation.duration = 0.1;
                    moveDownAnimation.completionBlock = ^(POPAnimation *anim, BOOL finished) {
                        frameInMasterView = [self.view convertRect:cell.frame fromView:collectionView];
                        frameAnimation.fromValue = [NSValue valueWithCGRect:frameInMasterView];
                        [self.collectionViewEnlargedImage pop_addAnimation:frameAnimation forKey:@"frame"];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            //do this on next frame so animations can prep the scaling and centering (there is no pop)
                            self.collectionViewEnlargedImage.hidden = NO;
                        });
                    };
                    [collectionView pop_addAnimation:moveDownAnimation forKey:@"contentOffset"];
                } else {
                    [self.collectionViewEnlargedImage pop_addAnimation:frameAnimation forKey:@"frame"];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        //do this on next frame so animations can prep the scaling and centering (there is no pop)
                        self.collectionViewEnlargedImage.hidden = NO;
                    });
                }
            }
            self.collectionViewEnlargedImage.image = image;
            [fullResolutionTimer invalidate];
            fullResolutionTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 block:^{
                [[PhotoManager sharedManager] fullsizeImageIn:[[PhotoManager sharedManager] cameraRollAlbumName]
                                                      atIndex:index
                                              completionBlock:^(UIImage *image, CLLocation *location) {
                                                  self.collectionViewEnlargedImage.image = image;
                                              }];
            } repeats:NO];*/
        }];
    }
    
    
    //POPSpringAnimation *frameAnimation = [self.collectionViewEnlargedImage pop_animationForKey:@"frame"];
    
    switch (recognizer.state) {
        case UIGestureRecognizerStateEnded:
        {
            [self.demoImageView removeFromSuperview];
            self.demoImageView = nil;
            /*
            if (frameAnimation == nil) {
                frameAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPViewFrame];
                [self.collectionViewEnlargedImage pop_addAnimation:frameAnimation forKey:@"frame"];
            }
            frameAnimation.toValue = [NSValue valueWithCGRect:frameInMasterView];
            frameAnimation.completionBlock = ^(POPAnimation *anim, BOOL finished) {
                self.collectionViewEnlargedImage.hidden = YES;
            };
            [fullResolutionTimer invalidate];
            fullResolutionTimer = nil;
            break;
             */
        }
            
        {
        default:
            break;
        }
            
    }
    
}


@end
