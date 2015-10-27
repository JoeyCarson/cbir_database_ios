//
//  CBLUtil.m
//  CBIRDatabase
//
//  Created by Joseph Carson on 10/20/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import <CouchbaseLite/CouchbaseLite.h>

#import "CBLUtil.h"

@implementation CBLUtil

+ (NSError *) saveAttachmentToDocument:(CBLDocument *)doc name:(NSString *)name mimeType:(NSString *)mimeType data:(NSData *)data
{
 
    CBLUnsavedRevision * revision = [doc newRevision];
    [revision setAttachmentNamed:name withContentType:mimeType content:data];
    
    NSError * error = nil;
    CBLSavedRevision * savedRevision = [revision save:&error];
    if ( error ) {
        NSLog(@"Failed to save revision.  %@", error);
    } else {
        //NSLog(@"doc %@ updated: %@", doc.documentID, savedRevision.properties);
    }
    
    return error;
}

@end
