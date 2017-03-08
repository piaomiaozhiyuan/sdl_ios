//  SDLProtocolReceivedMessageRouter.m
//

//  This class gets handed the SDLProtocol messages as they are received and decides what happens to them and where they are sent on to.

#import "SDLProtocolReceivedMessageRouter.h"
#import "SDLDebugTool.h"
#import "SDLProtocolMessage.h"
#import "SDLProtocolMessageAssembler.h"

NS_ASSUME_NONNULL_BEGIN

@interface SDLProtocolReceivedMessageRouter ()

@property (strong, nonatomic) NSMutableDictionary<NSNumber *, SDLProtocolMessageAssembler *> *messageAssemblers;

@end


@implementation SDLProtocolReceivedMessageRouter

- (instancetype)init {
    if (self = [super init]) {
        self.messageAssemblers = [NSMutableDictionary dictionaryWithCapacity:2];
    }
    return self;
}

- (void)handleReceivedMessage:(SDLProtocolMessage *)message {
    SDLFrameType frameType = message.header.frameType;

    switch (frameType) {
        case SDLFrameTypeSingle: {
            [self sdl_dispatchProtocolMessage:message];
        } break;
        case SDLFrameTypeControl: {
            [self sdl_dispatchControlMessage:message];
        } break;
        case SDLFrameTypeFirst: // fallthrough
        case SDLFrameTypeConsecutive: {
            [self sdl_dispatchMultiPartMessage:message];
        } break;
        default: break;
    }
}

- (void)sdl_dispatchProtocolMessage:(SDLProtocolMessage *)message {
    if ([self.delegate respondsToSelector:@selector(onProtocolMessageReceived:)]) {
        [self.delegate onProtocolMessageReceived:message];
    }
}

- (void)sdl_dispatchControlMessage:(SDLProtocolMessage *)message {
    switch (message.header.frameData) {
        case SDLFrameInfoStartServiceACK: {
            if ([self.delegate respondsToSelector:@selector(handleProtocolStartSessionACK:sessionID:version:)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                [self.delegate handleProtocolStartSessionACK:message.header.serviceType
                                                   sessionID:message.header.sessionID
                                                     version:message.header.version];
#pragma clang diagnostic pop
            }

            if ([self.delegate respondsToSelector:@selector(handleProtocolStartSessionACK:)]) {
                [self.delegate handleProtocolStartSessionACK:message.header];
            }
        } break;
        case SDLFrameInfoStartServiceNACK: {
            if ([self.delegate respondsToSelector:@selector(handleProtocolStartSessionNACK:)]) {
                [self.delegate handleProtocolStartSessionNACK:message.header.serviceType];
            }
        } break;
        case SDLFrameInfoEndServiceACK: {
            if ([self.delegate respondsToSelector:@selector(handleProtocolEndSessionACK:)]) {
                [self.delegate handleProtocolEndSessionACK:message.header.serviceType];
            }
        } break;
        case SDLFrameInfoEndServiceNACK: {
            if ([self.delegate respondsToSelector:@selector(handleProtocolStartSessionNACK:)]) {
                [self.delegate handleProtocolEndSessionNACK:message.header.serviceType];
            }
        } break;
        case SDLFrameInfoHeartbeat: {
            if ([self.delegate respondsToSelector:@selector(handleHeartbeatForSession:)]) {
                [self.delegate handleHeartbeatForSession:message.header.sessionID];
            }
        } break;
        case SDLFrameInfoHeartbeatACK: {
            if ([self.delegate respondsToSelector:@selector(handleHeartbeatACK)]) {
                [self.delegate handleHeartbeatACK];
            }
        } break;
        default: break;
    }
}

- (void)sdl_dispatchMultiPartMessage:(SDLProtocolMessage *)message {
    // Pass multipart messages to an assembler and call delegate when done.
    NSNumber *sessionID = [NSNumber numberWithUnsignedChar:message.header.sessionID];

    SDLProtocolMessageAssembler *assembler = self.messageAssemblers[sessionID];
    if (assembler == nil) {
        assembler = [[SDLProtocolMessageAssembler alloc] initWithSessionID:message.header.sessionID];
        self.messageAssemblers[sessionID] = assembler;
    }

    SDLMessageAssemblyCompletionHandler completionHandler = ^void(BOOL done, SDLProtocolMessage *assembledMessage) {
        if (done) {
            [self sdl_dispatchProtocolMessage:assembledMessage];
        }
    };
    [assembler handleMessage:message withCompletionHandler:completionHandler];
}

@end

NS_ASSUME_NONNULL_END