//
//  AQAppDelegate.m
//  LogWatcher
//
//  Created by Jim Dovey on 2012-09-11.
//  Copyright (c) 2012 Jim Dovey. All rights reserved.
//

#import "AQAppDelegate.h"

@implementation AQAppDelegate
{
    NSOperationQueue *  _presentationQueue;
    NSDate *            _lastModDate;
    BOOL                _relinquished;
    BOOL                _hasDeferredWrites;
    BOOL                _hasDeferredReads;
}

+ (NSSet *) keyPathsForValuesAffectingPresentedItemURL
{
    return ( [NSSet setWithObject: @"fileURL"] );
}

- (BOOL) applicationShouldTerminateAfterLastWindowClosed: (NSApplication *) sender
{
    return ( YES );
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSURL * saved = [self loadBookmark];
    if ( saved == nil )
    {
        saved = [NSURL fileURLWithPathComponents: @[NSHomeDirectory(), @"Desktop", @"TestFile.txt"]];
        [self saveBookmark: saved];
    }
    
    [saved startAccessingSecurityScopedResource];
    
    self.fileURL = saved;
    
    // serialize file presentation access
    _presentationQueue = [NSOperationQueue new];
    [_presentationQueue setMaxConcurrentOperationCount: 1];
    
    [NSFileCoordinator addFilePresenter: self];
}

- (NSApplicationTerminateReply) applicationShouldTerminate: (NSApplication *) sender
{
    if ( [self.window isDocumentEdited] == NO )
        return ( NSTerminateNow );
    
    // ask the user what to do
    NSAlert * alert = [NSAlert alertWithMessageText: NSLocalizedString(@"Do you want to save your changes?", @"") defaultButton: NSLocalizedString(@"Save", @"") alternateButton: NSLocalizedString(@"Cancel", @"") otherButton: NSLocalizedString(@"Discard Changes", @"") informativeTextWithFormat: NSLocalizedString(@"You can choose to save your changes, discard your changes, or cancel closing the application. If you save or descard, you cannot undo that action.", @"")];
    [alert beginSheetModalForWindow: self.window modalDelegate: self didEndSelector: @selector(saveAlertEnded:returnCode:context:) contextInfo: NULL];
    
    return ( NSTerminateLater );
}

- (void) saveAlertEnded: (NSAlert *) alert returnCode: (NSInteger) returnCode context: (void *) context
{
    switch ( returnCode )
    {
            // Save option
        case NSAlertDefaultReturn:
            [self saveChangesWithCompletion: ^{[NSApp replyToApplicationShouldTerminate: YES];}];
            break;
            
            // Cancel option
        case NSAlertAlternateReturn:
            [NSApp replyToApplicationShouldTerminate: NO];
            break;
            
            // Discard changes
        case NSAlertOtherReturn:
        default:
            [NSApp replyToApplicationShouldTerminate: YES];
            break;
    }
}

- (void) applicationWillTerminate: (NSNotification *) notification
{
    [_fileURL stopAccessingSecurityScopedResource];
    [NSFileCoordinator removeFilePresenter: self];
}

- (void) textDidChange: (NSNotification *) notification
{
    [self.window setDocumentEdited: YES];
}

- (void) saveBookmark: (NSURL *) url
{
    NSData * bookmarkData = [url bookmarkDataWithOptions: NSURLBookmarkCreationSuitableForBookmarkFile|NSURLBookmarkCreationWithSecurityScope includingResourceValuesForKeys: nil relativeToURL: nil error: NULL];
    [[NSUserDefaults standardUserDefaults] setObject: bookmarkData forKey: @"fileURL"];
}

- (NSURL *) loadBookmark
{
    NSData * bookmarkData = [[NSUserDefaults standardUserDefaults] objectForKey: @"fileURL"];
    if ( bookmarkData == nil )
        return ( nil );
    
    return ( [NSURL URLByResolvingBookmarkData: bookmarkData options: NSURLBookmarkResolutionWithSecurityScope relativeToURL: nil bookmarkDataIsStale: NULL error: NULL] );
}

- (void) setFileURL: (NSURL *) fileURL
{
    if ( _fileURL == nil || [_fileURL isEqual: fileURL] == NO )
    {
        if ( [self.window isDocumentEdited] )
        {
            [self saveChangesWithCompletion: ^{
                [_fileURL stopAccessingSecurityScopedResource];
                [fileURL startAccessingSecurityScopedResource];
                [self willChangeValueForKey: @"fileURL"];
                _fileURL = [fileURL copy];
                [self didChangeValueForKey: @"fileURL"];
                [self saveBookmark: _fileURL];
                [self updateViewer];
            }];
        }
        else
        {
            [_fileURL stopAccessingSecurityScopedResource];
            [fileURL startAccessingSecurityScopedResource];
            [self willChangeValueForKey: @"fileURL"];
            _fileURL = [fileURL copy];
            [self didChangeValueForKey: @"fileURL"];
            [self saveBookmark: _fileURL];
            [self updateViewer];
        }
    }
}

- (BOOL) _updateViewerInternal: (NSURL *) newURL error: (NSError **) error
{
    // this is called in a couple of places
    NSDictionary * attrs = [newURL resourceValuesForKeys: @[NSURLContentModificationDateKey] error: error];
    if ( attrs == nil )
    {
        return ( NO );
    }
    
    _lastModDate = attrs[NSURLContentModificationDateKey];
    NSString * contents = [NSString stringWithContentsOfURL: newURL encoding: NSUTF8StringEncoding error: error];
    
    if ( contents == nil )
    {
        return ( NO );
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.textView setString: contents];
    });
    
    [self.window setDocumentEdited: NO];
    return ( YES );
}

- (void) updateViewer
{
    if ( _relinquished )
    {
        _hasDeferredReads = YES;
        return;
    }
    
    // coordinated read
    NSFileCoordinator * coordinator = [[NSFileCoordinator alloc] initWithFilePresenter: self];
    NSError * error = nil;
    [coordinator coordinateReadingItemAtURL: self.fileURL options: 0 error: &error byAccessor: ^(NSURL *newURL) {
        NSError * readError = nil;
        if ( [self _updateViewerInternal: newURL error: &readError] == NO )
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSAlert alertWithError: readError] runModal];
            });
        }
    }];
    
    if ( error != nil )
    {
        // display the error
        [[NSAlert alertWithError: error] runModal];
    }
}

- (BOOL) _writeChangesInternal: (NSURL *) newURL error: (NSError **) error
{
    // called from a couple of places
    if ( [[self.textView string] writeToURL: newURL atomically: YES encoding: NSUTF8StringEncoding error: error] == NO )
    {
        return ( NO );
    }
    
    NSDictionary * attrs = [newURL resourceValuesForKeys: @[NSURLContentModificationDateKey] error: error];
    if ( attrs != nil )
        _lastModDate = attrs[NSURLContentModificationDateKey];
    
    [self.window setDocumentEdited: NO];
    return ( YES );
}

- (void) saveChangesWithCompletion: (void (^)(void)) completion
{
    if ( _relinquished )
    {
        _hasDeferredWrites = YES;
        return;
    }
    
    // coordinated write
    NSFileCoordinator * coordinator = [[NSFileCoordinator alloc] initWithFilePresenter: self];
    NSError * error = nil;
    void (^completionCopy)(void) = [completion copy];
    
    [coordinator coordinateWritingItemAtURL: self.fileURL options: NSFileCoordinatorWritingForReplacing error: &error byAccessor: ^(NSURL *newURL) {
        NSError * writeError = nil;
        if ( [self _writeChangesInternal: newURL error: &writeError] == NO )
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSAlert alertWithError: writeError] runModal];
            });
        }
        
        if ( completionCopy != nil )
            dispatch_async(dispatch_get_main_queue(), completionCopy);
    }];
    
    if ( error != nil )
    {
        [[NSAlert alertWithError: error] runModal];
        
        if ( completionCopy != nil )
            completionCopy();
    }
}

- (void) saveAs: (NSAlert *) alert returned: (NSInteger) returnCode context: (void *) context
{
    switch ( returnCode )
    {
        case NSAlertDefaultReturn:
        {
            // dismiss the alert manually before attaching a new sheet
            [alert.window orderOut: self];
            
            NSSavePanel * panel = [NSSavePanel savePanel];
            [panel setAllowedFileTypes: @[@"public.text"]];
            [panel beginSheetModalForWindow: self.window completionHandler: ^(NSInteger result) {
                switch ( result )
                {
                    case NSFileHandlingPanelOKButton:
                    {
                        NSURL * chosenURL = [panel URL];
                        [self willChangeValueForKey: @"fileURL"];
                        _fileURL = [chosenURL copy];
                        [self didChangeValueForKey: @"fileURL"];
                        
                        // save it nicely
                        [self saveChangesWithCompletion: nil];
                    }
                        
                    default:
                    {
                        // discard the current data
                        [self.textView setString: @""];
                        [self.window setDocumentEdited: NO];
                        self.fileURL = nil;
                        break;
                    }
                }
            }];
        }
            
        default:
        {
            // discard the current data
            [self.textView setString: @""];
            [self.window setDocumentEdited: NO];
            self.fileURL = nil;
            break;
        }
    }
}

#pragma mark - NSFilePresenter Implementation

- (NSURL *) presentedItemURL
{
    return ( _fileURL );
}

- (NSOperationQueue *) presentedItemOperationQueue
{
    return ( _presentationQueue );
}

- (void) relinquishPresentedItemToReader: (void (^)(void (^reacquirer)(void))) reader
{
    _relinquished = YES;
    reader(^{
        _relinquished = NO;
        if ( _hasDeferredWrites )
            [self saveChangesWithCompletion: nil];
        else if ( _hasDeferredReads )
            [self updateViewer];
    });
}

- (void) relinquishPresentedItemToWriter: (void (^)(void (^reacquirer)(void))) writer
{
    _relinquished = YES;
    writer(^{
        _relinquished = NO;
        if ( _hasDeferredWrites )
            [self saveChangesWithCompletion: nil];
        else if ( _hasDeferredReads )
            [self updateViewer];
    });
}

- (void) savePresentedItemChangesWithCompletionHandler: (void (^)(NSError *)) completionHandler
{
    NSError * error = nil;
    if ( [self.window isDocumentEdited] )
    {
        [self _writeChangesInternal: self.fileURL error: &error];
    }
    
    completionHandler(error);
}

- (void) accommodatePresentedItemDeletionWithCompletionHandler: (void (^)(NSError *)) completionHandler
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert * alert = [NSAlert alertWithMessageText: NSLocalizedString(@"Item deleted", @"") defaultButton: NSLocalizedString(@"Save", @"") alternateButton: NSLocalizedString(@"Discard", @"") otherButton: nil informativeTextWithFormat: NSLocalizedString(@"The file you were using has been deleted. Would you like to save the current data to a new file or discard it?", @"")];
        
        [alert beginSheetModalForWindow: self.window modalDelegate: self didEndSelector: @selector(saveAs:returned:context:) contextInfo: NULL];
    });
    
    completionHandler(nil);     // never any errors
}

- (void) presentedItemDidMoveToURL: (NSURL *) newURL
{
    // we don't want to clear & re-load the document, just swap the value
    // for that reason we don't go through our special setter implementation
    [self willChangeValueForKey: @"fileURL"];
    _fileURL = [newURL copy];
    [self didChangeValueForKey: @"fileURL"];
}

- (void) presentedItemDidChange
{
    // look at the modification date to determine whether the *contents* changed
    NSFileCoordinator * coordinator = [[NSFileCoordinator alloc] initWithFilePresenter: self];
    [coordinator coordinateReadingItemAtURL: self.fileURL options: NSFileCoordinatorReadingWithoutChanges error: NULL byAccessor: ^(NSURL *newURL) {
        NSDate * modDate = nil;
        if ( [newURL getResourceValue: &modDate forKey: NSURLContentModificationDateKey error: NULL] == NO )
            return;
        
        if ( modDate == nil )
            return;
        
        if ( _lastModDate == nil || [_lastModDate laterDate: modDate] == modDate )
        {
            _lastModDate = modDate;
            NSError * readError = nil;
            if ( [self _updateViewerInternal: newURL error: &readError] == NO )
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSAlert alertWithError: readError] runModal];
                });
            }
        }
    }];
}

@end
