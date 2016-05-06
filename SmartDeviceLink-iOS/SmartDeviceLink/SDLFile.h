//
//  SDLFile.h
//  SmartDeviceLink-iOS
//
//  Created by Joel Fischer on 10/14/15.
//  Copyright © 2015 smartdevicelink. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SDLFileType;


NS_ASSUME_NONNULL_BEGIN

@interface SDLFile : NSObject

@property (assign, nonatomic, readonly, getter=isPersistent) BOOL persistent;
@property (copy, nonatomic, readonly) NSString *name;
@property (copy, nonatomic, readonly) NSData *data;

/**
 *  Unless set manually, the system will attempt to determine the type of file that you have passed in.
 */
@property (strong, nonatomic, readonly) SDLFileType *fileType;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithURL:(NSURL *)url name:(NSString *)name persistent:(BOOL)persistent;

/**
 *  Create an SDL file using a local file URL.
 *
 *  This is a persistent file, it will be persisted through sessions / ignition cycles. You will only have a limited space for all files, so be sure to only persist files that are required for all or most sessions. For example, menu artwork should be persistent.
 *
 *  Ephemeral files should be created using ephemeralFileAtURL:name:
 *
 *  @warning If this is not a readable file, this will return nil
 *
 *  @param url The url to the file that should be uploaded.
 *  @param name The name of the file that will be used to reference the file in the future (for example on the remote file system).
 *
 *  @return An instance of this class, or nil if a readable file at the path could not be found.
 */
+ (instancetype)persistentFileAtURL:(NSURL *)url name:(NSString *)name;

/**
 *  Create an SDL file using a local file URL.
 *
 *  This is an ephemeral file, it will not be persisted through sessions / ignition cycles. Any files that you do not *know* you will use in future sessions should be created through this method. For example, album / artist artwork should be ephemeral.
 *
 *  Persistent files should be created using persistentFileAtURL:name:
 *
 *  @warning If this is not a readable file, this will return nil
 *
 *  @param url The url to the file that will be uploaded
 *  @param name The name of the file that will be used to reference the file in the future (for example on the remote file system).
 *
 *  @return An instance of this class, or nil if a readable file at the url could not be found.
 */
+ (instancetype)ephemeralFileAtURL:(NSURL *)url name:(NSString *)name;

/**
 *  Create an SDL file using raw data. It is strongly preferred to pass a file URL instead of data, as it is currently held in memory until the file is sent.
 *
 *  @param data         The raw data to be used for the file
 *  @param name         The name of the file that will be used to reference the file in the future (for example on the remote file system).
 *  @param fileType     The file type for this file
 *  @param persistent   Whether or not the remote file with this data should be persistent
 *
 *  @return An instance of this class
 */
- (instancetype)initWithData:(NSData *)data name:(NSString *)name type:(SDLFileType *)fileType persistent:(BOOL)persistent;

/**
 *  Create an SDL file using raw data. It is strongly preferred to pass a file URL instead of data, as it is currently held in memory until the file is sent.
 *
 *  @param data         The raw data to be used for the file
 *  @param name         The name of the file that will be used to reference the file in the future (for example on the remote file system).
 *  @param fileType     The file type for this file
 *  @param persistent   Whether or not the remote file with this data should be persistent
 *
 *  @return An instance of this class
 */
+ (instancetype)fileWithData:(NSData *)data name:(NSString *)name type:(SDLFileType *)fileType persistent:(BOOL)persistent;

@end

NS_ASSUME_NONNULL_END
