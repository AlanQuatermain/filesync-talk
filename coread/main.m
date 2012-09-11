//
//  main.m
//  coread
//
//  Created by Jim Dovey on 2012-09-11.
//  Copyright (c) 2012 Jim Dovey. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sysexits.h>

int main(int argc, const char * argv[])
{
    if ( argc != 2 )
    {
        fprintf(stderr, "Pass one parameter: a file path.\n");
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
        
        fprintf(stderr, "Reading from: %s\n", [[url absoluteString] UTF8String]);
        
        NSFileCoordinator * coordinator = [[NSFileCoordinator alloc] initWithFilePresenter: nil];
        __block NSString * read = nil;
        [coordinator coordinateReadingItemAtURL: url options: 0 error: NULL byAccessor: ^(NSURL *newURL) {
            read = [NSString stringWithContentsOfURL: newURL encoding: NSUTF8StringEncoding error: NULL];
        }];
        
        fprintf(stdout, "%s\n", [read UTF8String]);
    }
    
    return 0;
}

