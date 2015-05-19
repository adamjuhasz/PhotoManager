//
//  PhotoManagerIOS8.m
//  Pods
//
//  Created by Adam Juhasz on 4/16/15.
//
//

#import "PhotoManagerIOS8.h"
#import <Photos/Photos.h>

#define PhotosToLoad 50

@interface PhotoManagerIOS8 ()
{
    NSMutableDictionary *albums;
    PHCachingImageManager *cacher;
    CGSize thumbnailSize;
    NSMutableDictionary *cachedLocations;
}
@end

@implementation PhotoManagerIOS8

- (id)init
{
    self = [super init];
    if (self) {
        albums = [NSMutableDictionary dictionary];
        thumbnailSize = CGSizeMake(157, 157);
        cachedLocations = [NSMutableDictionary dictionary];
    }
    return self;
}

- (NSMutableArray*)albumNames
{
    return [[albums allKeys] mutableCopy];
}

- (void)photoLibraryDidChange:(PHChange *)changeInstance
{
    [self checkAuthorization];
    [self getAlbumNamesWhenDone:^{
        dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"PhotoManagerLoaded" object:nil];
        });
    }];
}

- (void)setAlbumNames:(NSMutableArray *)albumNames
{
    
}

- (Boolean)checkAuthorization
{
    PHAuthorizationStatus state = [PHPhotoLibrary authorizationStatus];
    if (state == PHAuthorizationStatusAuthorized) {
        self.authorized = YES;
    }
    else
        self.authorized = NO;
    
    return self.authorized;
}

- (void)getAlbumNamesWhenDone:(void (^)(void))completionBlock
{
    [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:self];
    
    [albums removeAllObjects];
    
    PHFetchOptions *userAlbumsOptions = [PHFetchOptions new];
    userAlbumsOptions.predicate = [NSPredicate predicateWithFormat:@"estimatedAssetCount > 0"];
    
    PHFetchOptions *allPhotosOptions = [PHFetchOptions new];
    allPhotosOptions.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
    
    PHFetchResult *userAlbums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum
                                                                         subtype:PHAssetCollectionSubtypeAny
                                                                         options:userAlbumsOptions];
    if (userAlbums.count == 0) {
        //are we authorized for the photo library?
        [self checkAuthorization];
        //do not call compeltion block
        return;
    }
    [userAlbums enumerateObjectsUsingBlock:^(PHAssetCollection *collection, NSUInteger idx, BOOL *stop) {
        PHFetchResult *fetchResult = [PHAsset fetchAssetsInAssetCollection:collection options:allPhotosOptions];
        [albums setObject:fetchResult forKey:collection.localizedTitle];
    }];
    
    PHFetchResult *smartAlbums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum
                                                                          subtype:PHAssetCollectionSubtypeAlbumRegular
                                                                          options:userAlbumsOptions];
    [smartAlbums enumerateObjectsUsingBlock:^(PHAssetCollection *collection, NSUInteger idx, BOOL *stop) {
        PHFetchResult *fetchResult = [PHAsset fetchAssetsInAssetCollection:collection options:allPhotosOptions];
        [albums setObject:fetchResult forKey:collection.localizedTitle];
    }];
    
    PHFetchResult *allPhotosResult = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage
                                                               options:allPhotosOptions];
    [albums setObject:allPhotosResult forKey:@"All Photos"];
    self.cameraRollAlbumName = @"All Photos";
    
    if (completionBlock) {
        completionBlock();
    }
}

- (void)cacheThumbnailsForAlbum:(NSString*)wantedAlbumName withRange:(NSRange)requestedRange completionBlock:(void (^)(NSDictionary* photos))completionBlock
{
    if (cacher == nil) {
        cacher = [[PHCachingImageManager alloc] init];
        cacher.allowsCachingHighQualityImages = NO;
    }
    
    NSRange adjustedRange = requestedRange;
    
    PHFetchResult *fechResult = [albums objectForKey:wantedAlbumName];
    if (fechResult.count < requestedRange.length + requestedRange.location) {
        if (fechResult.count <= requestedRange.location) {
            return;
        }
        adjustedRange.length = fechResult.count - adjustedRange.location;
    }
    NSArray *loadableAssets = [fechResult objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:adjustedRange]];
    [cacher startCachingImagesForAssets:loadableAssets targetSize:thumbnailSize contentMode:PHImageContentModeAspectFill options:nil];
    
    [cachedLocations setObject:[NSNumber numberWithInteger:(adjustedRange.location+adjustedRange.length -1)] forKey:wantedAlbumName];
    
    if (completionBlock) {
        completionBlock(nil);
    }
}

- (void)fullsizeImageIn:(NSString*)wantedAlbumName atIndex:(NSInteger)wantedindex completionBlock:(void (^)(UIImage* image, CLLocation *location))completionBlock
{
    if (cacher == nil) {
        cacher = [[PHCachingImageManager alloc] init];
        cacher.allowsCachingHighQualityImages = NO;
    }
    
    PHFetchResult *fetchResult = [albums objectForKey:wantedAlbumName];
    PHAsset *asset = fetchResult[wantedindex];
    PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
    options.progressHandler = ^(double progress, NSError *error, BOOL *stop, NSDictionary *info){
        NSLog(@"download progress: %f, %@", progress, info);
        if (error) {
            NSLog(@"Error: %@", error);
        }
    };
    options.synchronous = NO;
    options.deliveryMode = PHImageRequestOptionsDeliveryModeOpportunistic;
    options.version = PHImageRequestOptionsVersionCurrent;
    options.networkAccessAllowed = YES;
    
    [[PHImageManager defaultManager] requestImageForAsset:asset targetSize:PHImageManagerMaximumSize contentMode:PHImageContentModeDefault options:options resultHandler:^(UIImage *result, NSDictionary *info) {
        if (completionBlock) {
            completionBlock(result, asset.location);
        }
    }];
}

- (void)getThumbnailFor:(NSString *)wantedAlbumName atIndex:(NSInteger)index completionBlock:(void (^)(UIImage *))completionBlock
{
    if (cacher == nil) {
        cacher = [[PHCachingImageManager alloc] init];
        cacher.allowsCachingHighQualityImages = NO;
    }
    
    PHFetchResult *fetchResult = [albums objectForKey:wantedAlbumName];
    PHAsset *asset = fetchResult[index];
    PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
    options.synchronous = NO;

    [cacher requestImageForAsset:asset targetSize:thumbnailSize contentMode:PHImageContentModeAspectFill options:options resultHandler:^(UIImage *result, NSDictionary *info) {
        if (completionBlock) {
            completionBlock(result);
        }
    }];
    
    if (([[cachedLocations objectForKey:wantedAlbumName] floatValue] - index) < PhotosToLoad*(0.75)) {
        NSRange newRange = {[[cachedLocations objectForKey:wantedAlbumName] integerValue] +1, PhotosToLoad};
        [self cacheThumbnailsForAlbum:wantedAlbumName withRange:newRange completionBlock:nil];
    }
}

- (UIImage*)imageForAlbum:(NSString*)albumName
{
    return nil;
}

- (NSInteger)countForAlbum:(NSString*)albumName
{
    PHFetchResult *fetchResult = [albums objectForKey:albumName];
    return fetchResult.count;
}

@end
