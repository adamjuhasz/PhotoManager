//
//  PhotoAlbumManager.m
//  moments
//
//  Created by Adam Juhasz on 11/25/14.
//  Copyright (c) 2014 Adam Juhasz. All rights reserved.
//

#import "PhotoManager.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "PhotoManagerIOS8.h"

#define InitialPhotosToLoad 20
#define PhotosToLoad 100

@interface PhotoManager ()
{
    NSArray *_albums;
    ALAssetsLibrary *library;
    Boolean loadingAssets;
}

@end

@implementation PhotoManager

+ (id)sharedManager
{
    static PhotoManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if(NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_7_1) {
            NSLog(@"ios8");
            shared = [[PhotoManagerIOS8 alloc] init];
        } else {
            shared = [[self alloc] init];
        }
        if (shared && shared.authorized == YES) {
            [shared getAlbumNamesWhenDone:^{
                //NSLog(@"%@", shared.albumNames);
                //NSLog(@"Camera Roll: %@", shared.cameraRollAlbumName);
                NSRange cacheRange = {0, InitialPhotosToLoad};
                [shared cacheThumbnailsForAlbum:shared.cameraRollAlbumName
                                       withRange:cacheRange
                                 completionBlock:^(NSDictionary *photos) {
                                     //NSLog(@"%@", photos);
                                     dispatch_async(dispatch_get_main_queue(), ^{
                                         [[NSNotificationCenter defaultCenter] postNotificationName:@"PhotoManagerLoaded" object:shared];
                                     });
                                 }];
                }];
        }
    });
    
    return shared;
}

- (id)init
{
    self = [super init];
    if (self) {
        loadingAssets = NO;
        [self checkAuthorization];
    }
    return self;
}

- (void)libraryChanged
{
    [self checkAuthorization];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"PhotoManagerLoaded" object:self];
    });
}

- (Boolean)checkAuthorization
{
    ALAuthorizationStatus currentStatus = [ALAssetsLibrary authorizationStatus];
    if (currentStatus == ALAuthorizationStatusAuthorized) {
        self.authorized = YES;
    } else {
        self.authorized = NO;
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(libraryChanged) name:
     ALAssetsLibraryChangedNotification object:nil];
    library = [[ALAssetsLibrary alloc] init];
    
    return self.authorized;
}

- (void)getAlbumNamesWhenDone:(void (^)(void))completionBlock
{
    self.albumNames = nil;
    NSMutableArray *_tempAlbumNames = [NSMutableArray array];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSUInteger groupTypes = ALAssetsGroupAll;
        
        [library enumerateGroupsWithTypes:groupTypes
                               usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
                                   if(group != nil) {
                                       //grab album information
                                       NSString *albumName = [group valueForProperty:ALAssetsGroupPropertyName];
                                       NSNumber *albumCount = [NSNumber numberWithInteger:[group numberOfAssets]];
                                       UIImage *albumImage = [UIImage imageWithCGImage:group.posterImage];
                                       NSMutableDictionary *albumThumbnails = [NSMutableDictionary dictionary];
                                       NSMutableDictionary *albumPhotos = [NSMutableDictionary dictionary];
                                       NSNumber *type = [group valueForProperty:ALAssetsGroupPropertyType];
                                       NSNumber *lastIndexLoaded = [NSNumber numberWithInteger:0];
                                       //NSLog(@"<PhotoAlbumManager> Name: %@; Count: %@", albumName, albumCount);
                                       if ([albumCount integerValue] <= 0) {
                                           return;
                                       }
                                       if ([type integerValue] == ALAssetsGroupSavedPhotos) {
                                           self.cameraRollAlbumName = albumName;
                                       }
                                       
                                       NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                                             albumName, @"name",
                                                             albumCount, @"count",
                                                             albumImage, @"image",
                                                             albumThumbnails, @"thumbnails",
                                                             albumPhotos, @"photos",
                                                             lastIndexLoaded, @"lastIndexLoaded",
                                                             nil];
                                       //plave into album list array using count as the sorting control
                                       for (int i=0; i<_tempAlbumNames.count; i++) {
                                           NSDictionary *existing = [_tempAlbumNames objectAtIndex:i];
                                           if ([[existing objectForKey:@"count"] integerValue]  < [[dict objectForKey:@"count"] integerValue]) {
                                               [_tempAlbumNames insertObject:dict atIndex:i];
                                               return;
                                           }
                                       }
                                       
                                       //if first object or last object, insert at end of attay
                                       [_tempAlbumNames addObject:dict];
                                   }
                                   
                                   if (group == nil) {
                                       //done enumaerating
                                       _albums = _tempAlbumNames;
                                       NSMutableArray *names = [NSMutableArray array];
                                       for (NSDictionary *albumInfo in _tempAlbumNames) {
                                           [names addObject:[albumInfo objectForKey:@"name"]];
                                       }
                                       self.albumNames = names;
                                       if (completionBlock) {
                                           completionBlock();
                                       }
                                   }
                               }
                             failureBlock:nil];
    });
    
}

- (void)albumWithName:(NSString*)wantedAlbumName runBlock:(void (^)(ALAssetsGroup*))block
{
    if (block == nil || wantedAlbumName == nil) {
        return;
    }
    
    NSUInteger groupTypes = ALAssetsGroupAll;
    [library enumerateGroupsWithTypes:groupTypes
                           usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
                               if(group != nil) {
                                   NSString *albumName = [group valueForProperty:ALAssetsGroupPropertyName];
                                   if ([albumName isEqualToString:wantedAlbumName]) {
                                       block(group);
                                   }
                               }
                               
                           }
                         failureBlock:^(NSError *error) {
                             
                         }];
}

- (void)cacheThumbnailsForAlbum:(NSString*)wantedAlbumName withRange:(NSRange)requestedRange completionBlock:(void (^)(NSDictionary* photos))completionBlock
{
    NSMutableDictionary *albumInfo = nil;
    for (NSMutableDictionary *album in _albums) {
        NSString *albumName = [album objectForKey:@"name"];
        if ([albumName isEqualToString:wantedAlbumName]) {
            albumInfo = album;
            break;
        }
    }
    NSMutableDictionary *groupThumbnails = [albumInfo objectForKey:@"thumbnails"];
    NSMutableDictionary *images = [NSMutableDictionary dictionary];
    
    loadingAssets = YES;
    [self albumWithName:wantedAlbumName runBlock:^(ALAssetsGroup *group) {
        NSRange adjustedRange = requestedRange;
        if ([group numberOfAssets] < requestedRange.location + requestedRange.length) {
            //can we fix this?
            if (requestedRange.location >= [group numberOfAssets]) {
                //nope
                NSLog(@"Error asking too far");
                return;
            }
            NSLog(@"Warning, asking too much of the album");
            adjustedRange.length = [group numberOfAssets] - requestedRange.location;
        }
        
        BOOL reverseAlbum = YES;
        NSRange range = adjustedRange;
        NSNumber *type = [group valueForProperty:ALAssetsGroupPropertyType];
        if ([type integerValue] == ALAssetsGroupSavedPhotos) {
            //camera roll is in reverse always
            reverseAlbum = YES;
            //NSLog(@"<PhotoAlbumManager> '%@' is the 'camera roll'", wantedAlbumName);
        }
        if (reverseAlbum) {
            range.location = [group numberOfAssets] - (adjustedRange.location + adjustedRange.length);
        }
        NSIndexSet *set;
        //NSInteger startIndex = range.location;
        NSInteger lastIndex = range.location + (range.length-1);
        
        if (lastIndex < [group numberOfAssets]) {
            set = [[NSIndexSet alloc] initWithIndexesInRange:range];
        } else {
            NSInteger length = [group numberOfAssets] - range.location;
            if (length <= 0) {
                return;
            }
            
            NSRange goodRange = {range.location, length};
            lastIndex = goodRange.location + goodRange.length - 1;
            set = [[NSIndexSet alloc] initWithIndexesInRange:goodRange];
        }
        
        //NSLog(@"<PhotoAlbumManager> '%@' has %ld photos and getting photos %@", wantedAlbumName, (long)[group numberOfAssets], set);
        
        [group enumerateAssetsAtIndexes:set
                                options:NSEnumerationReverse
                             usingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
                                 NSUInteger realIndex = index;
                                 if (reverseAlbum) {
                                     realIndex = [group numberOfAssets] - index - 1;
                                 }
                                 
                                 if (result != nil) {
                                     CGImageRef thumbnail = [result thumbnail];
                                     UIImage *image = [UIImage imageWithCGImage:thumbnail];
                                     NSString *key = [NSString stringWithFormat:@"%lu", (unsigned long)realIndex];
                                     
                                     [groupThumbnails setObject:image forKey:key];
                                     [images setObject:image forKey:key];
                                 }
                                 
                                 if (result == nil) {
                                     [albumInfo setObject:[NSNumber numberWithLong:(adjustedRange.location + adjustedRange.length - 1)] forKey:@"lastIndexLoaded"];
                                     loadingAssets = NO;
                                     if (range.location == 0) {
                                         [self libraryChanged];
                                     }
                                     if (completionBlock) {
                                         completionBlock(images);
                                     }
                                 }
                             }];
    }];
}

- (UIImage*)grabFullPhotoFromAsset:(ALAsset*)asset
{
    BOOL orionatationNeeded = NO;
    ALAssetRepresentation *assetRepresentation = [asset defaultRepresentation];
    if (assetRepresentation == nil) {
        return nil;
    }
    CGImageRef fullResImage = [assetRepresentation fullResolutionImage];
    orionatationNeeded = YES; //YES for fullResolutionImage, NO for fullscreen
    
    NSDictionary *metadata = [assetRepresentation metadata];
    NSString *adjustment = [metadata objectForKey:@"AdjustmentXMP"];
    if (adjustment) {
        NSData *xmpData = [adjustment dataUsingEncoding:NSUTF8StringEncoding];
        CIImage *image = [CIImage imageWithCGImage:fullResImage];
        
        NSError *error = nil;
        NSArray *filterArray = [CIFilter filterArrayFromSerializedXMP:xmpData
                                                     inputImageExtent:image.extent
                                                                error:&error];
        if (error) {
            return nil;
        }
        
        CIContext *context = [CIContext contextWithOptions:nil];
        if (filterArray && !error) {
            for (CIFilter *filter in filterArray) {
                [filter setValue:image forKey:kCIInputImageKey];
                image = [filter outputImage];
            }
            fullResImage = [context createCGImage:image fromRect:[image extent]];
        }
        
        
    }
    
    UIImage *result = [UIImage imageWithCGImage:fullResImage
                                          scale:[assetRepresentation scale]
                                    orientation:orionatationNeeded ? (UIImageOrientation)[assetRepresentation orientation] : UIImageOrientationUp];
    return result;
    
}

- (void)fullsizeImageIn:(NSString*)wantedAlbumName atIndex:(NSInteger)wantedindex completionBlock:(void (^)(UIImage* image, CLLocation *location))completionBlock
{
    NSDictionary *albumInfo = nil;
    for (NSDictionary *album in _albums) {
        NSString *albumName = [album objectForKey:@"name"];
        if ([albumName isEqualToString:wantedAlbumName]) {
            albumInfo = album;
            break;
        }
    }
    if (albumInfo == nil) {
        return;
    }
    
    NSMutableDictionary *groupPhotos = [albumInfo objectForKey:@"photos"];
    
    [self albumWithName:wantedAlbumName runBlock:^(ALAssetsGroup *albumGroup) {
        if (wantedindex >= [albumGroup numberOfAssets]) {
            return;
        }
        
        NSUInteger virtualIndex = [albumGroup numberOfAssets] - wantedindex - 1;
        NSIndexSet *set = [[NSIndexSet alloc] initWithIndex:virtualIndex];
        NSLog(@"asking full photo in %@(%ld) at %@", wantedAlbumName, (long)[albumGroup numberOfAssets], set);
        [albumGroup enumerateAssetsAtIndexes:set
                                     options:NSEnumerationReverse
                                  usingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
                                      if (result != nil) {
                                          UIImage *fullImage = [self grabFullPhotoFromAsset:result];
                                          if (fullImage == nil) {
                                              return;
                                          }
                                          ALAssetRepresentation *representation = [result defaultRepresentation];
                                          NSDictionary *imageMetadata = [representation metadata];
                                          
                                          NSString *key = [NSString stringWithFormat:@"%lu", (unsigned long)wantedindex];
                                          [groupPhotos setObject:fullImage forKey:key];
                                          
                                          CLLocation *location = nil;
                                          if (completionBlock) {
                                              completionBlock(fullImage, location);
                                          }
                                      }
                                  }];
        
    }];
}

- (void)getThumbnailFor:(NSString *)albumName atIndex:(NSInteger)index completionBlock:(void (^)(UIImage *))completionBlock
{
    NSMutableDictionary *selectedAlbum = nil;
    for (NSMutableDictionary *album in _albums) {
        if ([[album objectForKey:@"name"] isEqualToString:albumName]) {
            selectedAlbum = album;
        }
    }
    
    if (selectedAlbum == nil) {
        if (completionBlock)
            completionBlock(nil);
        return;
    }
    
    NSNumber *lastIndexLoadedNumber = [selectedAlbum objectForKey:@"lastIndexLoaded"];
    if (lastIndexLoadedNumber != nil) {
        NSInteger lastLoadedIndex = [lastIndexLoadedNumber integerValue];
        if ((lastLoadedIndex - index) < PhotosToLoad*(0.75) && loadingAssets == NO) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSRange newRange = {lastLoadedIndex+1, PhotosToLoad};
                [self cacheThumbnailsForAlbum:albumName withRange:newRange completionBlock:nil];
            });
        }
    } else {
        NSLog(@"Error, no lastIndexLoaded");
    }
    
    NSString *key = [NSString stringWithFormat:@"%lu", (unsigned long)index];
    NSDictionary *photos = [selectedAlbum objectForKey:@"photos"];
    UIImage *photo = [photos objectForKey:key];
    if (photo) {
        if (completionBlock)
            completionBlock(photo);
        return;
        
    }
    
    NSDictionary *thumbnails = [selectedAlbum objectForKey:@"thumbnails"];
    UIImage *thumbnail = [thumbnails objectForKey:key];
    if (thumbnail) {
        if (completionBlock)
            completionBlock(thumbnail);
        return;
    }
    
    if (completionBlock)
        completionBlock(nil);
    return;
}

- (UIImage*)imageForAlbum:(NSString*)albumName
{
    NSDictionary *selectedAlbum = nil;
    for (NSDictionary *album in _albums) {
        if ([[album objectForKey:@"name"] isEqualToString:albumName]) {
            selectedAlbum = album;
        }
    }
    
    if (selectedAlbum == nil) {
        return nil;
    }
    
    return [selectedAlbum objectForKey:@"image"];
}

- (void)get:(NSInteger)numberOfImages MostRecentThumbnailsFrom:(NSString*)albumName
{
    
}

- (NSInteger)countForAlbum:(NSString*)albumName
{
    NSDictionary *selectedAlbum = nil;
    for (NSDictionary *album in _albums) {
        if ([[album objectForKey:@"name"] isEqualToString:albumName]) {
            selectedAlbum = album;
        }
    }
    
    if (selectedAlbum == nil) {
        return -1;
    }
    
    
    NSInteger count = [[selectedAlbum objectForKey:@"count"] integerValue];
    return count;
}

@end
