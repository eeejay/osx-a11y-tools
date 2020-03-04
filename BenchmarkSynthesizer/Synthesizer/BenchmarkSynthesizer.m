#import <ApplicationServices/ApplicationServices.h>
#import "SpeechEngine.h"

NSMutableArray * sChannels = NULL;

static Boolean ConvertCFStringToOSType(CFStringRef string, OSType * type);
static CFStringRef CopyCFStringFromOSType(OSType type);

@interface SynthesizerSimulator : NSObject {

    NSString *                _spokenString;
    VoiceSpec                _voiceSpec;
    NSMutableDictionary *    _properties;
    NSTimer *                _wordCallbackTimer;
    NSTimer *                _phonemeCallbackTimer;
    long                    _phonemeCallbackCharIndex;
    long                    _wordCallbackCharIndex;

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
- (void)performSimulatedCallbacks;

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
    [_phonemeCallbackTimer invalidate];
    [_phonemeCallbackTimer release];
    [_spokenString release];
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

        // We're simulating word and phoneme callbacks by having a timer perform the callback every 1/4 second.
        _spokenString = [string retain];
        _phonemeCallbackCharIndex = 0;
        _phonemeCallbackTimer = [[NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(performSimulatedCallbacks) userInfo:NULL repeats:YES] retain];

        // Do our simluated speaking by playing an audio file, which is static and has no relationship to the given text.
        [_properties setObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithLong:1], kSpeechStatusOutputBusy, [NSNumber numberWithLong:0], kSpeechStatusOutputPaused, [NSNumber numberWithLong:0], kSpeechStatusNumberOfCharactersLeft, [NSNumber numberWithLong:0], kSpeechStatusPhonemeCode, NULL] forKey:(NSString *)kSpeechStatusProperty];
    }
}

- (void)stopSpeaking
{
    // We're done with the simulated callbacks, release our timer.
    [_phonemeCallbackTimer invalidate];
    [_phonemeCallbackTimer release];
    _phonemeCallbackTimer = NULL;
    [_spokenString release];
    _spokenString = NULL;
    
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

- (void)performSimulatedCallbacks
{

    if (_spokenString && _phonemeCallbackCharIndex < [_spokenString length]) {
    
        // Skip whitespace, and determine if this is the beginning of the next word
        BOOL foundWordBoundary = (_phonemeCallbackCharIndex == 0);
        while (_phonemeCallbackCharIndex < [_spokenString length] && ! [[NSCharacterSet alphanumericCharacterSet] characterIsMember:[_spokenString characterAtIndex:_phonemeCallbackCharIndex]]) {
            _phonemeCallbackCharIndex++;

            // Make CF-based error callback whenever it sees the beginning of an embedded command.
            // Note: this not the recommended approach for handling embedded commands, but only an example of how to call the error callback function.
            SpeechErrorCFProcPtr errorCallBackProcPtr = (SpeechErrorCFProcPtr)[[_properties objectForKey:(NSString *)kSpeechErrorCFCallBack] longValue];
            if (errorCallBackProcPtr && _phonemeCallbackCharIndex < [_spokenString length] - 1 && [_spokenString characterAtIndex:_phonemeCallbackCharIndex] == '[' && [_spokenString characterAtIndex:_phonemeCallbackCharIndex+1] == '[') {
                    
                CFMutableDictionaryRef mutableUserInfo = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
                if (mutableUserInfo) {
                    CFDictionarySetValue(mutableUserInfo, (const void *)kCFErrorDescriptionKey, (const void *)CFSTR("Beginning of embedded command.  This is just a demonstration of a CF-based error callback and not an actual error."));
                    CFDictionarySetValue(mutableUserInfo, (const void *)kSpeechErrorCallbackSpokenString, (const void *)_spokenString);
                    
                    CFNumberRef offsetAsCFNumber = CFNumberCreate(NULL, kCFNumberLongType, (const void *)&_phonemeCallbackCharIndex);
                    if (offsetAsCFNumber) {
                        CFDictionarySetValue(mutableUserInfo, (const void *)kSpeechErrorCallbackCharacterOffset, (const void *)offsetAsCFNumber);
                        CFRelease(offsetAsCFNumber);
                    }

                    CFErrorRef theError =  CFErrorCreate(NULL, kCFErrorDomainOSStatus, noErr, mutableUserInfo);
                    if (theError) {
                        (*errorCallBackProcPtr)((SpeechChannel)self, [[_properties objectForKey:(NSString *)kSpeechRefConProperty] longValue], theError);
                        CFRelease(theError);
                    }
                    CFRelease(mutableUserInfo);
                }
            }

            foundWordBoundary = true;
        }
        

        if (_phonemeCallbackCharIndex < [_spokenString length]) {
            
            // Make simulated phoneme callback
            // Note: we just send a random phoneme opcode.
            SpeechPhonemeProcPtr phonemeCallBackProcPtr = (SpeechPhonemeProcPtr)[[_properties objectForKey:(NSString *)kSpeechPhonemeCallBack] longValue];
            if (phonemeCallBackProcPtr) {
                (*phonemeCallBackProcPtr)((SpeechChannel)self, [[_properties objectForKey:(NSString *)kSpeechRefConProperty] longValue], (SInt16)((random() % 47) + 2));
            }
            
            if (foundWordBoundary) {
            
                // Make simulated word callback before the beginnin of words
                SpeechWordCFProcPtr wordCallBackProcPtr = (SpeechWordCFProcPtr)[[_properties objectForKey:(NSString *)kSpeechWordCFCallBack] longValue];
                if (wordCallBackProcPtr) {
                    
                    // Find end of word in order to determine length of word.
                    // Note: a normal synthesizer would have already parsed the text in a much more sophisticated way, so this is not an example of who a synthesizer should determine word boundaries.
                    CFIndex charIndex = _phonemeCallbackCharIndex;
                    while (charIndex < [_spokenString length] && ! [[NSCharacterSet whitespaceCharacterSet] characterIsMember:[_spokenString characterAtIndex:charIndex]]) {
                        charIndex++;
                    }
                    CFIndex wordLength = 0;
                    if (charIndex >= [_spokenString length] && _phonemeCallbackCharIndex < [_spokenString length]) {
                        wordLength = [_spokenString length] - _phonemeCallbackCharIndex;
                    }
                    else if (charIndex > _phonemeCallbackCharIndex) {
                        wordLength = charIndex - _phonemeCallbackCharIndex;
                    }
                    
                    CFRange wordRange = CFRangeMake(_phonemeCallbackCharIndex, wordLength);
                    (*wordCallBackProcPtr)((SpeechChannel)self, [[_properties objectForKey:(NSString *)kSpeechRefConProperty] longValue], (CFStringRef)_spokenString, wordRange);
                }
            }
        }
        _phonemeCallbackCharIndex++;
    }
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


