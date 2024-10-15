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
    freopen([[NRAutoLogCollector logFileURL].path cStringUsingEncoding:NSUTF8StringEncoding], "a+", stderr);
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
    if (error) {
        return;
    } else if (fileContents.length == 0){
        return;
    }
    
    [NRAutoLogCollector clearLogFile];

    // Split the file contents into individual log entries
    NSArray<NSString *> *newLogEntries = [fileContents componentsSeparatedByString:@"\n"];
        
    // Process each log entry
    for (NSString *logEntry in newLogEntries) {
        if ([logEntry length] > 0) {
            [NRLogger logMessage:logEntry withTimestamp:[NRAutoLogCollector extractTimestamp:logEntry]];
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
    NSString *pattern = @"t:(\\d+\\.\\d+)";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
    
    // Find matches in the input string
    NSTextCheckingResult *match = [regex firstMatchInString:inputString options:0 range:NSMakeRange(0, [inputString length])];
    
    if (match) {
        // Extract the matched timestamp value
        NSRange timestampRange = [match rangeAtIndex:1];
        NSString *timestampString = [inputString substringWithRange:timestampRange];
        
        // Validate the timestamp
        if ([NRAutoLogCollector isValidTimestamp:(timestampString)]) {
            NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
            formatter.numberStyle = NSNumberFormatterDecimalStyle;
            return [formatter numberFromString:timestampString];
        }
    }
    
    return nil;
}

@end
