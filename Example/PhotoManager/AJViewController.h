//
//  AJViewController.h
//  PhotoManager
//
//  Created by Adam Juhasz on 04/09/2015.
//  Copyright (c) 2014 Adam Juhasz. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AJViewController : UIViewController <UICollectionViewDataSource>

@property IBOutlet UICollectionView *collectionView;
@property IBOutlet UIView *layoutButton;
@property IBOutlet UIActivityIndicatorView *activityIndicator;

@end
