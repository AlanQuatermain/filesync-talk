//
//  AQAppDelegate.h
//  LogWatcher
//
//  Created by Jim Dovey on 2012-09-11.
//  Copyright (c) 2012 Jim Dovey. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AQAppDelegate : NSObject <NSApplicationDelegate, NSFilePresenter, NSTextViewDelegate>

@property (assign) IBOutlet NSWindow *window;

@property (nonatomic, copy) NSURL * fileURL;
@property (assign) IBOutlet NSTextView * textView;

@end
