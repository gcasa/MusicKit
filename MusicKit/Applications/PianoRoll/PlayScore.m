/* $Id$
  Plays scorefile in background. -- David Jaffe 
*/

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <AudioToolbox/AudioToolbox.h>
#import <MusicKit/MusicKit.h>
#import "PlayScore.h"

@interface PianoRollAudioInstrument : MKInstrument {
    UInt8 channel;
    NSMutableDictionary *activeKeys;
}
- initWithProgram:(UInt8)program;
- (void)stopTag:(NSNumber *)tag;
@end

static AUGraph pianoRollGraph;
static AudioUnit pianoRollSynth;
static UInt8 pianoRollNextChannel;

static BOOL startPianoRollAudio(void)
{
    if (pianoRollGraph) return YES;
    AudioComponentDescription output = {kAudioUnitType_Output, kAudioUnitSubType_DefaultOutput,
                                        kAudioUnitManufacturer_Apple, 0, 0};
    AudioComponentDescription synth = {kAudioUnitType_MusicDevice, kAudioUnitSubType_DLSSynth,
                                       kAudioUnitManufacturer_Apple, 0, 0};
    AUNode outputNode, synthNode;
    OSStatus status = NewAUGraph(&pianoRollGraph);
    if (!status) status = AUGraphAddNode(pianoRollGraph, &output, &outputNode);
    if (!status) status = AUGraphAddNode(pianoRollGraph, &synth, &synthNode);
    if (!status) status = AUGraphOpen(pianoRollGraph);
    if (!status) status = AUGraphNodeInfo(pianoRollGraph, synthNode, NULL, &pianoRollSynth);
    if (!status) status = AUGraphConnectNodeInput(pianoRollGraph, synthNode, 0, outputNode, 0);
    if (!status) status = AUGraphInitialize(pianoRollGraph);
    if (!status) status = AUGraphStart(pianoRollGraph);
    if (!status) return YES;
    NSLog(@"Unable to start PianoRoll audio (OSStatus %d)", (int)status);
    if (pianoRollGraph) DisposeAUGraph(pianoRollGraph);
    pianoRollGraph = NULL;
    pianoRollSynth = NULL;
    return NO;
}

@implementation PianoRollAudioInstrument
- initWithProgram:(UInt8)program
{
    if ((self = [super init])) {
        [self addNoteReceiver:[[[MKNoteReceiver alloc] init] autorelease]];
        activeKeys = [[NSMutableDictionary alloc] init];
        channel = pianoRollNextChannel++ % 16;
        if (channel == 9) channel = pianoRollNextChannel++ % 16;
        if (startPianoRollAudio())
            MusicDeviceMIDIEvent(pianoRollSynth, 0xC0 | channel, program, 0, 0);
    }
    return self;
}
- (void)dealloc { [activeKeys release]; [super dealloc]; }
- (void)stopTag:(NSNumber *)tag
{
    NSNumber *key = [activeKeys objectForKey:tag];
    if (key) MusicDeviceMIDIEvent(pianoRollSynth, 0x80 | channel, [key intValue], 0, 0);
    [activeKeys removeObjectForKey:tag];
}
- realizeNote:(MKNote *)note fromNoteReceiver:(MKNoteReceiver *)receiver
{
    NSNumber *tag = [NSNumber numberWithInt:[note noteTag]];
    if ([note noteType] == MK_noteOff) { [self stopTag:tag]; return self; }
    if ([note noteType] != MK_noteOn && [note noteType] != MK_noteDur) return self;
    int key = [note keyNum];
    int velocity = [note isParPresent:MK_velocity] ? [note parAsInt:MK_velocity] : 96;
    if (key == MAXINT) key = 60;
    key = MAX(0, MIN(127, key)); velocity = MAX(1, MIN(127, velocity));
    MusicDeviceMIDIEvent(pianoRollSynth, 0x90 | channel, key, velocity, 0);
    if ([note noteTag] == MAXINT) tag = [NSNumber numberWithInt:MKNoteTag()];
    [activeKeys setObject:[NSNumber numberWithInt:key] forKey:tag];
    if ([note noteType] == MK_noteDur)
        [[note conductor] sel:@selector(stopTag:) to:self withDelay:[note dur] argCount:1, tag];
    return self;
}
- afterPerformance
{
    if (pianoRollSynth) MusicDeviceMIDIEvent(pianoRollSynth, 0xB0 | channel, 123, 0, 0);
    [activeKeys removeAllObjects];
    return [super afterPerformance];
}
@end

@implementation PlayScore:NSObject

static NSMutableArray *synthInstruments;
static MKScorePerformer *scorePerformer;
static MKOrchestra *theOrch;
static double samplingRate = 22050;
static double headroom = .1;
static double initialTempo;

static BOOL userCancelFileRead = NO;

static void handleMKError(NSString *msg)
{
    if (![MKConductor inPerformance]) {
	if (!NSRunAlertPanel(@"PianoRoll", msg, @"OK", @"Cancel", nil, NULL)) {
	  MKSetScorefileParseErrorAbort(0);
	  userCancelFileRead = YES;         /* A kludge for now. */
      }
    }
    else {
	NSLog(@"%@", msg);
    }
}

-(BOOL)isPlaying
{
    return [MKConductor inPerformance];
}

- (void)setUpPlay: (MKScore *) scoreObj
{
   /* Could keep these around, in repeat-play cases: */ 
    id scoreInfo;
    if ([self isPlaying])
    	[self stop];
    samplingRate = 22050;
    headroom = .1;
//    MKSetTrace(1023);
    [[MKConductor defaultConductor] setTempo:initialTempo = 60];
    scoreInfo = [scoreObj infoNote];
    if (scoreInfo) { /* Configure performance as specified in info. */ 
	if ([scoreInfo isParPresent:MK_headroom])
            headroom = [scoreInfo parAsDouble:MK_headroom];	  
	if ([scoreInfo isParPresent:MK_samplingRate]) {
	    samplingRate = [scoreInfo parAsDouble:MK_samplingRate];
	    if (!((samplingRate == 44100.0) || (samplingRate == 22050.0))) 
		NSRunAlertPanel(@"ScorePlayer", @"Sampling rate must be 44100 or 22050.\n", @"OK", nil, nil);
	}
	if ([scoreInfo isParPresent:MK_tempo]) {
	    initialTempo = [scoreInfo parAsDouble:MK_tempo];
        [[MKConductor defaultConductor] setTempo:initialTempo];
	} 
    } 
    [scorePerformer release];
    scorePerformer = nil;  // Be Wary of this LMS
    [synthInstruments removeAllObjects];
    [synthInstruments release]; 
    synthInstruments = nil;  // Be wary of this LMS
}

- (BOOL) play:scoreObj
{
    int partCount,synthPatchCount,voices,i;
    NSString *className;
    id partPerformers,synthPatchClass,partPerformer,partInfo,anIns,aPart;

    if ([self isPlaying])
    	[self stop];
    theOrch = [[MKOrchestra alloc] initOnDSP: 0]; /* Retained for legacy non-macOS builds. */
//    [theOrch setHeadroom:headroom];    /* Must be reset for each play */ 
    [theOrch setSamplingRate:samplingRate];
    #if !defined(__APPLE__)
    if (![theOrch open]) {
	NSRunAlertPanel(@"ScorePlayer", @"Can't open DSP. Perhaps another application has it.", @"OK", nil, nil);
	return NO;
    }
    #endif
    scorePerformer = [MKScorePerformer new];
    [scorePerformer setScore:scoreObj];
    [scorePerformer activate]; 
    partPerformers = [scorePerformer partPerformers];
    partCount = [partPerformers count];
    synthInstruments = [[NSMutableArray alloc] init];
    for (i = 0; i < partCount; i++) {
	partPerformer = [partPerformers objectAtIndex:i];
	aPart = [partPerformer part]; 
	partInfo = [aPart infoNote];      
	if ((!partInfo) || ![partInfo isParPresent:MK_synthPatch]) {
	    if (!NSRunAlertPanel(@"ScorePlayer", 
                [NSString stringWithFormat: @"%@ info missing.\n", MKGetObjectName(aPart)], @"Continue", @"Cancel", nil)) 
	      return NO;
	    continue;
	}		
	className = [partInfo parAsStringNoCopy:MK_synthPatch];
        #if defined(__APPLE__)
        anIns = [[PianoRollAudioInstrument alloc] initWithProgram:(UInt8)([className hash] % 128)];
        [synthInstruments addObject:anIns];
        [[partPerformer noteSender] connect:[anIns noteReceiver]];
        [anIns release];
        continue;
        #endif
        synthPatchClass = [MKSynthPatch findPatchClass:className];
        
	if (!synthPatchClass) {         /* Class not loaded in program? */ 
	    if (!NSRunAlertPanel(@"ScorePlayer", 
                [NSString stringWithFormat: @"This scorefile calls for a synthesis instrument (%@) that isn't available in this application.\n", className],
                     @"Continue", @"Cancel", nil))
	      return NO;
	    /* We would prefer to do dynamic loading here. */
	    continue;
	}
	anIns = [MKSynthInstrument new];      
	[synthInstruments addObject:anIns];
	[[partPerformer noteSender] connect:[anIns noteReceiver]];
	[anIns setSynthPatchClass:synthPatchClass];
	if (![partInfo isParPresent:MK_synthPatchCount])
	  continue;         
	voices = [partInfo parAsInt:MK_synthPatchCount];
	synthPatchCount = 
	  [anIns setSynthPatchCount:voices patchTemplate:
	   [synthPatchClass patchTemplateFor:partInfo]];
        [anIns release]; /* since retain is now held in synthInstruments array! */
	if (synthPatchCount < voices) {
	    if (!NSRunAlertPanel(@"ScorePlayer", 
                [NSString stringWithFormat: @"Could only allocate %d instead of %d %@s for %@\n",
		    synthPatchCount, voices, className, MKGetObjectName(aPart)], 
                    @"Continue", @"Cancel", nil))
	      return NO;
	}
    }
//    [partPerformers release];
    MKSetDeltaT(1.0);
    [MKConductor setClocked:YES];     
//    [MKOrchestra setTimed:YES];
    #if !defined(__APPLE__)
    [MKConductor afterPerformanceSel:@selector(close) to:theOrch argCount:0];
    #endif
//    [MKConductor afterPerformanceSel:@selector(hello) to:self argCount:0];

    #if !defined(__APPLE__)
    [theOrch run];
    #endif
    [MKConductor startPerformance];
    return YES; 
}

- init
{
    static int inited = 0;
    [super init];
    if (inited++)
        return self;
    [MKConductor setThreadPriority:1.0];
    [MKConductor useSeparateThread:YES];
    MKSetErrorProc(handleMKError);

    return self;
}

- (void)dealloc
{
    [scorePerformer release];
    [synthInstruments removeAllObjects];
    [synthInstruments release];
    [theOrch release];
    [super dealloc];
}

- stop
{
    [MKConductor lockPerformance];
//    [theOrch abort];
    [MKConductor finishPerformance];
    [MKConductor unlockPerformance];
    #if !defined(__APPLE__)
    [theOrch close];
    #endif
    return self;
}

@end
