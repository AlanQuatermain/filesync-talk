//
//  main.m
//  cowrite
//
//  Created by Jim Dovey on 2012-09-11.
//  Copyright (c) 2012 Jim Dovey. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sysexits.h>

int main(int argc, const char * argv[])
{
    if ( argc != 3 )
    {
        fprintf(stderr, "Pass two parameters: a file path and a string, in that order.\n");
        exit(EX_USAGE);
    }
    
    @autoreleasepool
    {
        NSString * path = [NSString stringWithUTF8String: argv[1]];
        NSURL * url = nil;
        if ( [path isAbsolutePath] )
        {
            url = [NSURL fileURLWithPath: [path stringByStandardizingPath] isDirectory: NO];
        }
        else
        {
            url = [NSURL fileURLWithPathComponents: @[[[NSFileManager defaultManager] currentDirectoryPath]]];
        }
        
        NSString * appended = [NSString stringWithUTF8String: argv[2]];
        if ( [appended hasSuffix: @"\n"] == NO )
            appended = [appended stringByAppendingString: @"\n"];
        
        NSFileCoordinator * coordinator = [[NSFileCoordinator alloc] initWithFilePresenter: nil];
        [coordinator coordinateWritingItemAtURL: url options: NSFileCoordinatorWritingForMerging error: NULL byAccessor: ^(NSURL *newURL) {
            NSFileHandle * handle = [NSFileHandle fileHandleForUpdatingURL: newURL error: NULL];
            [handle seekToEndOfFile];
            [handle writeData: [appended dataUsingEncoding: NSUTF8StringEncoding]];
            [handle closeFile];
        }];
    }
    
    return 0;
}

