#import <Foundation/Foundation.h>

static void cb(ConstFSEventStreamRef streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags eventFlags[], const FSEventStreamEventId eventIds[]);
static BOOL isInteresting(FSEventStreamEventFlags flags);

int main(int argc, const char * argv[]) {
	@autoreleasepool {
		NSString *dir = @".";
		FSEventStreamRef stream = FSEventStreamCreate(NULL, cb, NULL, (__bridge CFArrayRef)(@[dir]), kFSEventStreamEventIdSinceNow, 1, kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents);
		FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
		FSEventStreamStart(stream);
		
		[[NSRunLoop currentRunLoop] run];
	}
	
	return EXIT_FAILURE; // can't happen
}

static void cb(ConstFSEventStreamRef streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags eventFlags[], const FSEventStreamEventId eventIds[]) {
	
	for (size_t i = 0; i < numEvents; i++) {
		if (isInteresting(eventFlags[i])) {
			NSString *path = CFArrayGetValueAtIndex(eventPaths, i);
			puts([[NSString stringWithFormat:@"%@", path] UTF8String]);
		}
	}
}

static BOOL isInteresting(FSEventStreamEventFlags flags) {
	if (flags & kFSEventStreamEventFlagItemIsDir) {
		return NO;
	}
	
	if (flags & (kFSEventStreamEventFlagItemCreated | kFSEventStreamEventFlagItemRemoved | kFSEventStreamEventFlagItemRenamed | kFSEventStreamEventFlagItemModified)) {
		return YES;
	}
	
	return NO;
}
