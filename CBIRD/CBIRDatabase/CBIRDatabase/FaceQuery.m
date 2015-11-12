//
//  FaceQuery.m
//  CBIRDatabase
//
//  Created by Joseph Carson on 11/11/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import "FaceQuery.h"
#import "FaceIndexer.h"
#import "CBIRDocument.h"

@implementation FaceQuery

@synthesize inputFaceImage = _inputFaceImage;

-(instancetype)initWithDelegate:(id<CBIRQueryDelegate>)delegate
{
    self = [self initWithDelegate:delegate];
    return self;
}

-(instancetype)initWithFaceImage:(CIImage *)faceImage andDelegate:(id<CBIRQueryDelegate>)delegate
{
    self = [super initWithDelegate:delegate];
    if ( self ) {
        _inputFaceImage = faceImage;
    }
    return self;
}

-(void)run
{
    NSLog(@"%s executing.", __FUNCTION__);
    // Retrieve the desired Indexer.
    FaceIndexer * faceIndexer = nil;
    const CBIRIndexer * indexer = [[CBIRDatabaseEngine sharedEngine] getIndexer:NSStringFromClass([FaceIndexer class])];
    
    if ( [indexer class] == [FaceIndexer class]) {
        faceIndexer = (FaceIndexer *)indexer;
        
        NSString * tempQueryID = @"face_query_temp";
        CBIRDocument * inputDocument = [[CBIRDocument alloc] initWithCIImage:self.inputFaceImage persistentID:tempQueryID type:QUERY_INPUT];
        CBLDocument * dbDocument = [[CBIRDatabaseEngine sharedEngine] newDocument:tempQueryID];
        [faceIndexer indexImage:inputDocument cblDocument:dbDocument];
    }
}



@end
