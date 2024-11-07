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
int stdoutPipe[2];
int stderrPipe[2];
static BOOL hasRedirectedStdOut = false;

@interface NRAutoLogCollector()

@end

@implementation NRAutoLogCollector

+ (BOOL) redirectStandardOutputAndError {
    if (hasRedirectedStdOut){
        return true;
    }
    // Create pipes for stdout and stderr
    if (pipe(stdoutPipe) == -1) {
        return false;
    }
    if (pipe(stderrPipe) == -1) {
        // Should close the valid pipe if the other returns -1
        close(saved_stdout);
        return false;
    }

    // Save the original stdout and stderr file descriptors
    saved_stdout = dup(fileno(stdout));
    saved_stderr = dup(fileno(stderr));
    if (saved_stdout == -1 || saved_stderr == -1) {
        close(stdoutPipe[0]);
        close(stdoutPipe[1]);
        close(stderrPipe[0]);
        close(stderrPipe[1]);
        return false;
    }

    // Redirect stdout and stderr to the write ends of the pipes
    if (dup2(stdoutPipe[1], fileno(stdout)) == -1 || dup2(stderrPipe[1], fileno(stderr)) == -1) {
        close(stdoutPipe[0]);
        close(stdoutPipe[1]);
        close(stderrPipe[0]);
        close(stderrPipe[1]);
        close(saved_stdout);
        close(saved_stderr);
        return false;
    }
    close(stdoutPipe[1]); // Close the original write end of the stdout pipe
    close(stderrPipe[1]); // Close the original write end of the stderr pipe

    // Read from the pipes in background threads
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [NRAutoLogCollector readAndLog:stdoutPipe[0]];
    });
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [NRAutoLogCollector readAndLog:stderrPipe[0]];
    });

    // Restore the original stdout and stderr when done
    atexit_b(^{
        [NRAutoLogCollector restoreStandardOutputAndError];
    });
    
    hasRedirectedStdOut = true;
    
    return true;
}

+ (void) readAndLog:(int) fd {
    char buffer[2048];
    ssize_t count;
    while ((count = read(fd, buffer, sizeof(buffer) - 1)) > 0) {
        buffer[count] = '\0'; // Null-terminate the string
        NSString *output = [NSString stringWithUTF8String:buffer];
        NSArray<NSString *> *newLogEntries = [output componentsSeparatedByString:@"\n\n"];
            
        // Process each log entry
        for (NSString *logEntry in newLogEntries) {
            if ([logEntry length] > 0) {
                [NRLogger log:[NRAutoLogCollector extractType:logEntry] withMessage:logEntry withTimestamp:[NRAutoLogCollector extractTimestamp:logEntry]];
            }
        }
    }
    close(fd);
}

+ (void) restoreStandardOutputAndError {
    if (!hasRedirectedStdOut){
        return;
    }
    dup2(saved_stdout, fileno(stdout));
    dup2(saved_stderr, fileno(stderr));
    close(saved_stdout);
    close(saved_stderr);
    
    hasRedirectedStdOut = false;
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
        
    return NRLogLevelInfo;
}

@end
