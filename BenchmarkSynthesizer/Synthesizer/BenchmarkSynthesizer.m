/* MIT License
 *
 * Copyright (c) 2020 Eitan Isaacson
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#import <ApplicationServices/ApplicationServices.h>
#import "SpeechEngine.h"

NSMutableArray * sChannels = NULL;

static Boolean ConvertCFStringToOSType(CFStringRef string, OSType * type);
static CFStringRef CopyCFStringFromOSType(OSType type);

@interface SynthesizerSimulator : NSObject {

    VoiceSpec                _voiceSpec;
    NSMutableDictionary *    _properties;
}

- (id)init;
- (void)setVoice:(VoiceSpec *)voiceSpec;
- (void)getVoice:(VoiceSpec *)voiceSpec;
- (void)startSpeaking:(NSString *)string;
- (void)stopSpeaking;
- (void)pauseSpeaking;
- (void)continueSpeaking;
- (void)setObject:(id)object forProperty:(NSString *)property;
- (id)copyProperty:(NSString *)property;

@end


@implementation SynthesizerSimulator

- (id)init
{
    if ((self = [super init])) {
        
        _properties = [NSMutableDictionary new];
        
        [_properties setObject:(NSString *)kSpeechModeText forKey:(NSString *)kSpeechInputModeProperty];
        [_properties setObject:(NSString *)kSpeechModeNormal forKey:(NSString *)kSpeechCharacterModeProperty];
        [_properties setObject:(NSString *)kSpeechModeNormal forKey:(NSString *)kSpeechNumberModeProperty];
        [_properties setObject:[NSNumber numberWithFloat:180.0] forKey:(NSString *)kSpeechRateProperty];
        [_properties setObject:[NSNumber numberWithFloat:100.0] forKey:(NSString *)kSpeechPitchBaseProperty];
        [_properties setObject:[NSNumber numberWithFloat:30.0] forKey:(NSString *)kSpeechPitchModProperty];
        [_properties setObject:[NSNumber numberWithFloat:1.0] forKey:(NSString *)kSpeechVolumeProperty];
        [_properties setObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithLong:0], kSpeechStatusOutputBusy, [NSNumber numberWithLong:0], kSpeechStatusOutputPaused, [NSNumber numberWithLong:0], kSpeechStatusNumberOfCharactersLeft, [NSNumber numberWithLong:0], kSpeechStatusPhonemeCode, NULL] forKey:(NSString *)kSpeechStatusProperty];

    }
    return self;
}

- (void)dealloc;
{
    [_properties release];
    
    [super dealloc];
}

- (void)setVoice:(VoiceSpec *)voiceSpec
{
    _voiceSpec = *voiceSpec;
}

- (void)getVoice:(VoiceSpec *)voiceSpec
{
    *voiceSpec = _voiceSpec;
}

- (void)startSpeaking:(NSString *)string;
{
    if (! [_properties objectForKey:(NSString *)kSpeechOutputToFileURLProperty]) {
        // Set properties to speaking
        [_properties setObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithLong:1], kSpeechStatusOutputBusy, [NSNumber numberWithLong:0], kSpeechStatusOutputPaused, [NSNumber numberWithLong:0], kSpeechStatusNumberOfCharactersLeft, [NSNumber numberWithLong:0], kSpeechStatusPhonemeCode, NULL] forKey:(NSString *)kSpeechStatusProperty];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 10), dispatch_get_main_queue(), ^{
            // Set properties to end speaking
            [_properties setObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithLong:0], kSpeechStatusOutputBusy, [NSNumber numberWithLong:0], kSpeechStatusOutputPaused, [NSNumber numberWithLong:0], kSpeechStatusNumberOfCharactersLeft, [NSNumber numberWithLong:0], kSpeechStatusPhonemeCode, NULL] forKey:(NSString *)kSpeechStatusProperty];

            // Dispatch end callback
            SpeechDoneProcPtr callBackProcPtr = (SpeechDoneProcPtr)[[_properties objectForKey:(NSString *)kSpeechSpeechDoneCallBack] longValue];
            if (callBackProcPtr) {
                    (*callBackProcPtr)((SpeechChannel)self, [[_properties objectForKey:(NSString *)kSpeechRefConProperty] longValue]);
            }
        });
    }
}

- (void)stopSpeaking
{
    [_properties setObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithLong:0], kSpeechStatusOutputBusy, [NSNumber numberWithLong:0], kSpeechStatusOutputPaused, [NSNumber numberWithLong:0], kSpeechStatusNumberOfCharactersLeft, [NSNumber numberWithLong:0], kSpeechStatusPhonemeCode, NULL] forKey:(NSString *)kSpeechStatusProperty];
}

- (void)pauseSpeaking
{
    [_properties setObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithLong:0], kSpeechStatusOutputBusy, [NSNumber numberWithLong:1], kSpeechStatusOutputPaused, [NSNumber numberWithLong:0], kSpeechStatusNumberOfCharactersLeft, [NSNumber numberWithLong:0], kSpeechStatusPhonemeCode, NULL] forKey:(NSString *)kSpeechStatusProperty];
}

- (void)continueSpeaking
{
    [_properties setObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithLong:1], kSpeechStatusOutputBusy, [NSNumber numberWithLong:0], kSpeechStatusOutputPaused, [NSNumber numberWithLong:0], kSpeechStatusNumberOfCharactersLeft, [NSNumber numberWithLong:0], kSpeechStatusPhonemeCode, NULL] forKey:(NSString *)kSpeechStatusProperty];
}

- (void)setObject:(id)object forProperty:(NSString *)property
{
    if (object) {
        [_properties setObject:object forKey:property];
    }
    else {
        [_properties removeObjectForKey:property];
    }
}

- (id)copyProperty:(NSString *)property
{
    return [[_properties objectForKey:property] retain];
}

@end

static void httpSend(NSString* string)
{
    NSString *urlStr=[NSString stringWithFormat:@"http://localhost:8080/?timestamp=%f&text=%@", CFAbsoluteTimeGetCurrent(),
                      [string stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet]];

    NSURL *url = [NSURL URLWithString:urlStr];
    NSURLSessionDataTask *downloadTask = [[NSURLSession sharedSession]
      dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
    }];
    [downloadTask resume];
}

long	SEOpenSpeechChannel( SpeechChannelIdentifier* ssr )
{
    if (sChannels == NULL) {
        sChannels = [NSMutableArray new];
    }

    SynthesizerSimulator * simulator = [SynthesizerSimulator new];
    [sChannels addObject:simulator];
    [simulator release];
    
    if (ssr) {
        *ssr = simulator;
	}

    return (simulator)?noErr:synthOpenFailed;
}

long 	SEUseVoice( SpeechChannelIdentifier ssr, VoiceSpec* voice, CFBundleRef inVoiceSpecBundle )
{
    long error = noErr;
    if ([sChannels containsObject:(id)ssr]) {
        [(SynthesizerSimulator *)ssr setVoice:voice];
    }
    else {
        error = noSynthFound;
    }
    return error;
}

long	SECloseSpeechChannel( SpeechChannelIdentifier ssr )
{
    long error = noErr;
    if ([sChannels containsObject:(id)ssr]) {
        [sChannels removeObject:(id)ssr];
    }
    else {
        error = noSynthFound;
    }
    return error;
} 


long 	SESpeakCFString( SpeechChannelIdentifier ssr, CFStringRef text, CFDictionaryRef options )
{
    httpSend((NSString*)text);
    long error = noErr;
    if ([sChannels containsObject:(id)ssr]) {
        [(SynthesizerSimulator *)ssr startSpeaking:(NSString *)text];
    }
    else {
        error = noSynthFound;
    }

    return error;
}

long 	SEStopSpeechAt( SpeechChannelIdentifier ssr, unsigned long whereToStop)
{
    long error = noErr;
    if ([sChannels containsObject:(id)ssr]) {
        [(SynthesizerSimulator *)ssr stopSpeaking];
    }
    else {
        error = noSynthFound;
    }
    return error;
} 

 
long 	SEPauseSpeechAt( SpeechChannelIdentifier ssr, unsigned long whereToPause )
{
    long error = noErr;
    if ([sChannels containsObject:(id)ssr]) {
        [(SynthesizerSimulator *)ssr pauseSpeaking];
    }
    else {
        error = noSynthFound;
    }
    return error;
} 


long 	SEContinueSpeech( SpeechChannelIdentifier ssr )
{
    long error = noErr;
    if ([sChannels containsObject:(id)ssr]) {
        [(SynthesizerSimulator *)ssr continueSpeaking];
    }
    else {
        error = noSynthFound;
    }
    return error;
} 

long 	SECopyPhonemesFromText 	( SpeechChannelIdentifier ssr, CFStringRef text, CFStringRef * phonemes)
{
    return noErr;
} 

long 	SEUseSpeechDictionary( SpeechChannelIdentifier ssr, CFDictionaryRef speechDictionary )
{
    return noErr;
} 

long 	SECopySpeechProperty( SpeechChannelIdentifier ssr, CFStringRef property, CFTypeRef * object )
{
    long error = noErr;
    if ([sChannels containsObject:(id)ssr]) {
        if (object) {
                *object = [(SynthesizerSimulator *)ssr copyProperty:(NSString *)property];
        }
        else {
                error = paramErr;
        }
    }
    else {
        error = noSynthFound;
    }
    return error;
} 


/*
    Set the information for the designated speech channel and selector
*/
long 	SESetSpeechProperty( SpeechChannelIdentifier ssr, CFStringRef property, CFTypeRef object)
{
    long error = noErr;
    if ([sChannels containsObject:(id)ssr]) {
        [(SynthesizerSimulator *)ssr setObject:(id)object forProperty:(NSString *)property];
    }
    else {
        error = noSynthFound;
    }
    return error;
} 


