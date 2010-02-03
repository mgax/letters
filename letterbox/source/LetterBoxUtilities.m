/*
 * MailCore
 *
 * Copyright (C) 2007 - Matt Ronge
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the MailCore project nor the names of its
 *    contributors may be used to endorse or promote products derived
 *    from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHORS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHORS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRELB, INDIRELB, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRALB, STRILB
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#import "LetterBoxUtilities.h"
#import "JRLog.h"

/* direction is 1 for send, 0 for receive, -1 when it does not apply */
void letterbox_logger(int direction, const char * str, size_t size) {
    char *str2 = malloc(size+1);
    strncpy(str2,str,size);
    str2[size] = 0;
    id self = nil; // Work around for using JRLogInfo in a C function
    if (direction == 1) {
        JRLogInfo(@"Client: %s\n", str2);
    }
    else if (direction == 0) {
        JRLogInfo(@"Server: %s\n", str2);
    }
    else {
        JRLogInfo(@"%s\n", str2);
    }
    free(str2);
}


void LBQuickError(NSError **err, NSString *domain, NSInteger code, NSString *description) {
    // fixme: add a com.lettersapp in front of the domain?
    if (err) {
        *err = [NSError errorWithDomain:domain code:code userInfo:[NSDictionary dictionaryWithObject:description forKey:NSLocalizedDescriptionKey]];
    }
    
}



NSString *LBQuote(NSString *body, NSString *prefix) {
    NSMutableString *ret = [NSMutableString string];
    
    // normalize the line endings to make things easier.
    body = [body stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
    body = [body stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];
    
    for (NSString *line in [body componentsSeparatedByString:@"\n"]) {
        [ret appendFormat:@"%@%@\n", prefix, line];
    }
    return ret;
}


NSString *LBWrapLines(NSString *body, int width) {
    
    if (width < 10) {
        width = 10; // some sanity here please.
    }
    
    NSMutableString *ret = [NSMutableString string];
    
    
    body = [body stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
    body = [body stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];
    
    for (NSString *line in [body componentsSeparatedByString:@"\n"]) {
        
        if (![line length]) {
            [ret appendString:@"\n"];
            continue;
        }
        
        int idx = 0;
        
        while ((idx < [line length]) && ([line characterAtIndex:idx] == '>')) {
            idx++;
        }
        
        NSMutableString *pre = [NSMutableString string];
        
        for (int i = 0; i < idx; i++) {
            [pre appendString:@">"];
        }
        
        NSString *oldLine = [line substringFromIndex:idx];
        
        NSMutableString *newLine = [NSMutableString string];
        
        [newLine appendString:pre];
        
        for (NSString *word in [oldLine componentsSeparatedByString:@" "]) {
            
            if ([newLine length] + [word length] > width) {
                [ret appendString:newLine];
                [ret appendString:@"\n"];
                [newLine setString:pre];
            }
            
            if ([word length] && [newLine length]) {
                [newLine appendString:@" "];
            }
            
            [newLine appendString:word];
            
        }
        
        [ret appendString:newLine];
        [ret appendString:@"\n"];
        
    }
    
    return ret;
}


NSDictionary* LBSimpleMesageHeaderSliceAndDice(NSData *msgData) {
    
    NSMutableDictionary *headers = [NSMutableDictionary dictionary];
    
    NSUInteger len          = [msgData length];
    NSUInteger idx          = 0;
    char *cdata             = (char *)[msgData bytes];
    NSUInteger lineStart    = 0;
    
    while (idx < len - 2) {
        
        if (cdata[idx] == '\r' && cdata[idx+1] == '\n') { // CRLF
            
            // get rid of the encountered lf, and the ending crlf
            NSRange r = NSMakeRange(lineStart, idx - (lineStart));
            NSData *subData = [msgData subdataWithRange:r];
            NSString *junk = [[[NSString alloc] initWithBytes:[subData bytes] length:[subData length] encoding:NSUTF8StringEncoding] autorelease];
            
            if ([junk hasPrefix:@" "] || [junk hasPrefix:@"\t"]) {
                // it's a continuation whatsname!
                // for now, we're just ignoring it.  This function all only cares about the simple stuff.
            }
            else {
                
                NSRange r = [junk rangeOfString:@":"];
                
                if (r.location == NSNotFound || ([junk length] < r.location + 2)) {
                    debug(@"Could not find marker in: '%@'", junk);
                    idx += 2;
                    continue;
                }
                
                NSString *name = [[junk substringToIndex:r.location] lowercaseString];
                NSString *res  = [junk substringFromIndex:NSMaxRange(r) + 1];
                
                NSMutableArray *l = [headers objectForKey:name];
                if (!l) {
                    l = [NSMutableArray array];
                    [headers setObject:l forKey:name];
                }
                
                [l addObject:res];
            }
            
            lineStart = idx + 2;
            
            if (cdata[idx+2] == '\r') {
                // it's an empty line, we're done!
                break;
            }
            
            idx++; // jumpity mick jump over the \r, and then the \n below
        }
        
        idx++;
    }
    
    return headers;
}

