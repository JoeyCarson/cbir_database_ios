//
//  FaceIndexer.h
//  CBIRDatabase
//
//  Created by Joseph Carson on 10/15/15.
//  Copyright © 2015 Joseph Carson. All rights reserved.
//

#import <CBIRDatabase/CBIRDatabase.h>

// The grid size to partition each face into.
#define GRID_WIDTH_IN_BLOCKS 8
#define GRID_HEIGHT_IN_BLOCKS 8

static NSString * const FACE_DATA_LIST_DBKEY = @"face_data_list";

@interface FaceIndexer : CBIRIndexer

@end
