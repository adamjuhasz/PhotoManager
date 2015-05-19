//
//  AJViewController.m
//  PhotoManager
//
//  Created by Adam Juhasz on 04/09/2015.
//  Copyright (c) 2014 Adam Juhasz. All rights reserved.
//

#import "AJViewController.h"
#import <PhotoManager/PhotoManager.h>
#import "AJPhotoCell.h"

@interface AJViewController ()

@end

@implementation AJViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    [PhotoManager sharedManager];
    //[self.collectionView registerClass:[AJPhotoCell class] forCellWithReuseIdentifier:@"PhotoCell"];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(photosUpdated) name:@"PhotoManagerLoaded" object:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section
{
    PhotoManager *shared = [PhotoManager sharedManager];
    NSInteger count = [shared countForAlbum:shared.cameraRollAlbumName];
    if (count > 0) {
        self.layoutButton.hidden = NO;
        [self.activityIndicator stopAnimating];
    }
    return MAX(0,count);
}

-(UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                 cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    AJPhotoCell *myCell = [collectionView
                                    dequeueReusableCellWithReuseIdentifier:@"PhotoCell"
                                    forIndexPath:indexPath];
    
    UIImage *image;
    long row = [indexPath row];
    
    PhotoManager *shared =  [PhotoManager sharedManager];
    image =  [shared imageIn:shared.cameraRollAlbumName atIndex:row];
    
    myCell.photoView.image = image;
    
    return myCell;
}

- (void)photosUpdated
{
    [self.collectionView reloadData];
}

- (IBAction)changeLayout:(id)sender
{
    UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout*)self.collectionView.collectionViewLayout;
    CGSize currentSize = layout.itemSize;
    int ratio = round(self.view.frame.size.width / currentSize.width);
    CGSize newSize;
    switch (ratio) {
        case 1:
            ratio = 2;
            newSize.width = 159;
            break;
            
        case 2:
            ratio = 3;
            newSize.width = 106;
            break;
            
        case 3:
        default:
            ratio = 1;
            newSize.width = 320;
            break;
    }
    newSize.height = newSize.width;
    layout.itemSize = newSize;
}

@end
