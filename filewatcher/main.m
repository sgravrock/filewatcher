#import <Foundation/Foundation.h>

struct options {
	BOOL json;
	char * const *command;
};

static struct options parseArgs(char * const argv[]);
static void cb(ConstFSEventStreamRef streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags eventFlags[], const FSEventStreamEventId eventIds[]);
static BOOL isInteresting(FSEventStreamEventFlags flags);
static void doCommand(char * const *command);
static void waitFor(pid_t pid, int pipefd, const char *commandName);
static void writePaths(NSArray *paths);
static void writeJson(NSArray *paths);

int main(int argc, char * argv[]) {
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

static struct options parseArgs(char * const argv[]) {
	struct options opts = { NO, NULL };
	
	if (argv[1]) {
		if (strcmp(argv[1], "--json") == 0) {
			opts.json = YES;
		} else if (strcmp(argv[1], "--do") == 0) {
			if (!argv[2]) {
				fprintf(stderr, "--do requires a command\n");
				exit(EXIT_FAILURE);
			}
			
			opts.command = argv + 2;
		} else {
			fprintf(stderr, "Usage: %s [--json | --do command [arg1...]]\n", argv[0]);
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
	
	struct options *opts = clientCallBackInfo;
	
	if (opts->command) {
		doCommand(opts->command);
	} else if (opts->json) {
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

static void doCommand(char * const *command) {
	int pipefds[2];
	
	if (pipe(pipefds) < 0) {
		perror("pipe");
		return;
	}
	
	pid_t pid = fork();
	
	if (pid < 0) {
		perror("fork");
	} else if (pid > 0) {
		close(pipefds[1]);
		waitFor(pid, pipefds[0], command[0]);
	} else {
		execvp(command[0], command);
		// Can't use stdio after fork, so ask the parent process to report the error
		write(pipefds[1], &errno, sizeof errno);
		_exit(255);
	}
}

static void waitFor(pid_t pid, int pipefd, const char *commandName) {
	int status;
	
	if (waitpid(pid, &status, 0) < 0) {
		perror("Can't wait for child process");
		return;
	}
	
	if (WIFEXITED(status) && WEXITSTATUS(status) == 255) {
		int childErrno;
		
		if (read(pipefd, &childErrno, sizeof childErrno) < 0) {
			perror("Error figuring out why your command failed");
		} else {
			fprintf(stderr, "%s: %s\n", commandName, strerror(childErrno));
		}
	}
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
