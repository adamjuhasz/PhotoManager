//
//  PhotoAlbumManager.h
//  moments
//
//  Created by Adam Juhasz on 11/25/14.
//  Copyright (c) 2014 Adam Juhasz. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@interface PhotoManager : NSObject

@property NSMutableArray *albumNames;
@property NSString *cameraRollAlbumName;
@property Boolean authorized;

+ (id)sharedManager;

- (UIImage*)imageForAlbum:(NSString*)album;
- (void)getThumbnailFor:(NSString*)albumName atIndex:(NSInteger)index completionBlock:(void (^)(UIImage* image))completionBlock;
- (NSInteger)countForAlbum:(NSString*)album;

- (void)getAlbumNamesWhenDone:(void (^)(void))completionBlock;
- (void)cacheThumbnailsForAlbum:(NSString*)wantedAlbumName withRange:(NSRange)requestedRange completionBlock:(void (^)(NSDictionary* photos))completionBlock;
- (void)fullsizeImageIn:(NSString*)wantedAlbumName atIndex:(NSInteger)wantedindex completionBlock:(void (^)(UIImage* image, CLLocation *location))completionBlock;
@end
