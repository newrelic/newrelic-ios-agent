//
//  NRAutoLogCollector.m
//  Agent
//
//  Created by Mike Bruin on 10/9/24.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRAutoLogCollector.h"
#import "NRLogger.h"

int saved_stdout;
int saved_stderr;
FILE* fileDescriptor;

@interface NRAutoLogCollector()

@end

@implementation NRAutoLogCollector

+ (NSURL *) logFileURL {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray<NSURL *> *urls = [fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    NSURL *logsDirectory = [urls firstObject];
    return [logsDirectory URLByAppendingPathComponent:@"agent.log"];
}

+ (void) clearLogFile {
    [[NSFileManager defaultManager] removeItemAtURL:[NRAutoLogCollector logFileURL] error:nil];
    
    [NRAutoLogCollector redirectStandardOutputAndError];
}

+ (void) redirectStandardOutputAndError {
    // Save the original stdout file descriptor
    saved_stdout = dup(fileno(stdout));
    saved_stderr = dup(fileno(stderr));

    // Redirect stdout to the file
    freopen([[NRAutoLogCollector logFileURL].path cStringUsingEncoding:NSUTF8StringEncoding], "a+", stdout);
    fileDescriptor = freopen([[NRAutoLogCollector logFileURL].path cStringUsingEncoding:NSUTF8StringEncoding], "a+", stderr);
    
    [NRAutoLogCollector monitorFile:[NRAutoLogCollector logFileURL].path];
}

+ (void) restoreStandardOutputAndError {
    [NRAutoLogCollector readAndParseLogFile];
    
    // Restore the original stdout
    dup2(saved_stdout, fileno(stdout));
    dup2(saved_stderr, fileno(stderr));
    close(saved_stdout);
    close(saved_stderr);
}

+ (void) readAndParseLogFile {
    fflush(stdout);
    fflush(stderr);
    // Check if the file exists
    if (![[NSFileManager defaultManager] fileExistsAtPath:[NRAutoLogCollector logFileURL].path]) {
        return;
    }

    // Read the file content into an NSString
    NSError *error = nil;
    NSString *fileContents = [NSString stringWithContentsOfFile:[NRAutoLogCollector logFileURL].path
                                                       encoding:NSUTF8StringEncoding
                                                          error:&error];
    [NRAutoLogCollector clearLogFile];

    if (error) {
        return;
    } else if (fileContents.length == 0){
        return;
    }
    
    // Split the file contents into individual log entries
    NSArray<NSString *> *newLogEntries = [fileContents componentsSeparatedByString:@"\n\n"];
        
    // Process each log entry
    for (NSString *logEntry in newLogEntries) {
        if ([logEntry length] > 0) {
            [NRLogger log:[NRAutoLogCollector extractType:logEntry] withMessage:logEntry withTimestamp:[NRAutoLogCollector extractTimestamp:logEntry]];
        }
    }
}

+ (BOOL) isValidTimestamp:(NSString *) timestampString {
    // Check if the timestamp string can be converted to a double
    double timestamp = [timestampString doubleValue];
    return timestamp > 0;
}

+ (NSNumber *) extractTimestamp:(NSString *) inputString {
    // Define the regular expression pattern to match the t: value
    NSString *pattern = @"t:(\\d+(\\.\\d+)?)";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
    
    NSTextCheckingResult *match = [regex firstMatchInString:inputString options:0 range:NSMakeRange(0, [inputString length])];
    
    if (match) {
        // Extract the matched timestamp value
        NSRange timestampRange = [match rangeAtIndex:1];
        NSString *timestampString = [inputString substringWithRange:timestampRange];
        
        // Validate the timestamp
        if ([NRAutoLogCollector isValidTimestamp:(timestampString)]) {
            NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
            formatter.numberStyle = NSNumberFormatterDecimalStyle;
            NSNumber* originalTimestamp = [formatter numberFromString:timestampString];
            // If the timestamp has a decimal it is in second format, convert it to milliseconds.
            if([timestampString containsString:@"."]){
                double timestampInSeconds = [originalTimestamp doubleValue];
                long long timestampInMilliseconds = (long long)(timestampInSeconds * 1000);
                return [NSNumber numberWithLongLong:timestampInMilliseconds];
            } else {
                return originalTimestamp;
            }
        }
    }
    
    return nil;
}

+ (unsigned int) extractType:(NSString *) inputString {
        // Define the regular expression pattern to match the type: value
        NSString *pattern = @"type:\"([^\"]+)\"";
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
        
        // Find matches in the input string
        NSTextCheckingResult *match = [regex firstMatchInString:inputString options:0 range:NSMakeRange(0, [inputString length])];
        
        if (match) {
            // Extract the matched type value
            NSRange typeRange = [match rangeAtIndex:1];
            NSString *typeString = [inputString substringWithRange:typeRange];
            if([typeString caseInsensitiveCompare:@"Info"] == NSOrderedSame || [typeString caseInsensitiveCompare:@"Default"] == NSOrderedSame){
                return NRLogLevelInfo;
            } else if([typeString caseInsensitiveCompare:@"Debug"] == NSOrderedSame){
                return NRLogLevelDebug;
            } else if([typeString caseInsensitiveCompare:@"Warning"] == NSOrderedSame){
                return NRLogLevelWarning;
            } else if([typeString caseInsensitiveCompare:@"Error"] == NSOrderedSame || [typeString caseInsensitiveCompare:@"Fault"] == NSOrderedSame){
                return NRLogLevelError;
            }
        }
        
    return NRLogLevelNone;
}
    
+ (void) monitorFile:(NSString *) filePath {
    // Create a dispatch queue for handling log file events
    dispatch_queue_t queue = dispatch_queue_create("newrelic.log.monitor.queue", NULL);

    // Create a dispatch source to monitor the file descriptor for writes
    dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, fileno(fileDescriptor), DISPATCH_VNODE_WRITE, queue);

    // Set the event handler block
    dispatch_source_set_event_handler(source, ^{
        unsigned long flags = dispatch_source_get_data(source);
        if (flags & DISPATCH_VNODE_WRITE) {
            [NRAutoLogCollector readAndParseLogFile];
        }
    });

    // Set the cancel handler block
    dispatch_source_set_cancel_handler(source, ^{
        close(fileno(fileDescriptor));
    });

    // Start monitoring
    dispatch_resume(source);
}

@end
