//
//  PhotoManagerViewController.h
//  Pods
//
//  Created by Adam Juhasz on 5/26/15.
//
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

@protocol PhotoManagerCollectionDelegate <NSObject>
@required
- (void)userDidChooseThumbnail:(UIImage*)thumbnail;
- (void)userDidChooseFullImage:(UIImage*)image atLocation:(CLLocation*)location;

@end

@interface PhotoManagerViewController : UIViewController

@property NSValue *previewFrame;
@property id <PhotoManagerCollectionDelegate> delegate;

@end
