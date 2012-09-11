# filesync-talk
#### Copyright (c) 2012 Jim Dovey. See LICENSE file for license details.

This project implements a simple Cocoa app which presents a file using the `NSFilePresenter` API, possibly with some of its own changes pending. It also implements two command-line applications which append to or read from a file using the `NSFileCoordinator` API. Together these can be used to demonstrate (or debug!) the correct use of file coordination APIs on OS X.