//
//  CBLUtil.h
//  CBIRDatabase
//
//  Created by Joseph Carson on 10/20/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import <Foundation/Foundation.h>

NSString * MIME_TYPE_OCTET_STREAM = @"application/octet-stream";

@interface CBLUtil : NSObject

+ (NSError *) saveAttachmentToDocument:(CBLDocument *)doc name:(NSString *)name mimeType:(NSString *)mimeType data:(NSData *)data;

@end
