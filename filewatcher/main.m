#import <Foundation/Foundation.h>

struct options {
	BOOL json;
};

static struct options parseArgs(const char *argv[]);
static void cb(ConstFSEventStreamRef streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags eventFlags[], const FSEventStreamEventId eventIds[]);
static BOOL isInteresting(FSEventStreamEventFlags flags);
static void writePaths(NSArray *paths);
static void writeJson(NSArray *paths);

int main(int argc, const char * argv[]) {
	@autoreleasepool {
		struct options opts = parseArgs(argv);
		struct FSEventStreamContext context = { 0, &opts, NULL, NULL, NULL };
		NSString *dir = @".";
		FSEventStreamRef stream = FSEventStreamCreate(NULL, cb, &context, (__bridge CFArrayRef)(@[dir]), kFSEventStreamEventIdSinceNow, 1, kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents);
		FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
		FSEventStreamStart(stream);
		
		[[NSRunLoop currentRunLoop] run];
	}
	
	return EXIT_FAILURE; // can't happen
}

static struct options parseArgs(const char *argv[]) {
	struct options opts = { NO };
	
	for (int i = 1; argv[i] != NULL; i++) {
		if (strcmp(argv[i], "--json") == 0) {
			opts.json = YES;
		} else {
			fprintf(stderr, "Usage: %s [--json]\n", argv[0]);
			exit(EXIT_FAILURE);
		}
	}
	
	return opts;
}

static void cb(ConstFSEventStreamRef streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags eventFlags[], const FSEventStreamEventId eventIds[]) {
	
	NSMutableArray *interestings = [NSMutableArray array];
	
	for (size_t i = 0; i < numEvents; i++) {
		if (isInteresting(eventFlags[i])) {
			NSString *path = CFArrayGetValueAtIndex(eventPaths, i);
			[interestings addObject:path];
		}
	}
	
	
	if (((struct options *)clientCallBackInfo)->json) {
		writeJson(interestings);
	} else {
		writePaths(interestings);
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

static void writePaths(NSArray *paths) {
	for (NSString *path in paths) {
		puts([path UTF8String]);
	}
}

static void writeJson(NSArray *paths) {
	NSError *error = nil;
	NSData *data = [NSJSONSerialization dataWithJSONObject:paths
												   options:0
													 error:&error];
	
	if (data) {
		[data writeToFile:@"/dev/stdout" atomically:NO];
		putchar('\n');
	} else {
		fprintf(stderr, "Error serializing file paths: %s\n",
				[[error localizedDescription] UTF8String]);
	}
}
