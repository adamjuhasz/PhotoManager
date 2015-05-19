//
//  PhotoManagerIOS8.h
//  Pods
//
//  Created by Adam Juhasz on 4/16/15.
//
//

#import "PhotoManager.h"
#import <Photos/Photos.h>

@interface PhotoManagerIOS8 : PhotoManager <PHPhotoLibraryChangeObserver>

@end
