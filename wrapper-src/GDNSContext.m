/*
 * Copyright (c) 2014, Verisign, Inc.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 * * Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * * Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the distribution.
 * * Neither the names of the copyright holders nor the
 *   names of its contributors may be used to endorse or promote products
 *   derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL Verisign, Inc. BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "GDNSContext.h"
#import "GDNSUtil.h"

#import <getdns/getdns.h>
#import <getdns/getdns_extra.h>

// user arg
@interface CallbackData : NSObject

@property (nonatomic, strong) GDNSContext* context;
@property (nonatomic, copy) GDNSCallback callback;

@end

@implementation CallbackData

@synthesize context;
@synthesize callback;

@end


@implementation GDNSContext

@synthesize context = context_;

-(id)initWithSettings:(BOOL)isStub
        withResolvers:(NSArray*)resolverIps {
    self = [super init];
    if (self) {
        context_ = NULL;
        int r = getdns_context_create(&context_, 0);
        r |= getdns_context_set_use_threads(context_, 1);
        if (isStub) {
            if (!resolverIps) {
                // get from network settings
                resolverIps = [GDNSUtil getDnsIPs];
            }
            getdns_list* ips = [GDNSUtil convertIpsToList:resolverIps];
            r |= getdns_context_set_upstream_recursive_servers(context_, ips);
        }
        if (r != GETDNS_RETURN_GOOD) {
            getdns_context_destroy(context_);
            context_ = NULL;
            self = nil;
        }
    }
    return self;
}

-(void)dealloc {
    getdns_context_destroy(context_);
}

-(CallbackData*)createCallbackData:(GDNSCallback)cb {
    CallbackData* result = [[CallbackData alloc] init];
    result.callback = cb;
    result.context = self;
    return result;
}

void getdns_cb(getdns_context *context,
               getdns_callback_type_t callbackType,
               getdns_dict *response,
               void *userarg,
               getdns_transaction_t tid)
{
    CallbackData* cbData = (__bridge CallbackData*)userarg;
    cbData.callback(cbData.context, callbackType,
                    response, tid);
}

-(int)lookup:(NSString*)name
       ofType:(uint16_t)request_type
      withExt:(NSDictionary*)extensions
      transId:(uint64_t*)tId
     callback:(GDNSCallback)cb {
    CallbackData* userarg = [self createCallbackData:cb];
    getdns_dict* ext = [GDNSUtil convertToDict:extensions];
    int r = getdns_general(context_, [name UTF8String], request_type,
                   ext, (__bridge void *)userarg,
                   tId, getdns_cb);
    getdns_dict_destroy(ext);
    return r;
}

-(int)address:(NSString*)name
       withExt:(NSDictionary*)extensions
       transId:(uint64_t*)tId
      callback:(GDNSCallback)cb {
    CallbackData* userarg = [self createCallbackData:cb];
    getdns_dict* ext = [GDNSUtil convertToDict:extensions];
    int r = getdns_address(context_, [name UTF8String],
                           ext, (__bridge void *)userarg,
                           tId, getdns_cb);
    getdns_dict_destroy(ext);
    return r;
}

-(int)hostname:(NSString*)address
        withExt:(NSDictionary*)extensions
        transId:(uint64_t*)tId
       callback:(GDNSCallback)cb {
    CallbackData* userarg = [self createCallbackData:cb];
    getdns_dict* ext = [GDNSUtil convertToDict:extensions];
    getdns_dict* addr = [GDNSUtil convertIpStr:address];
    int r = getdns_hostname(context_, addr,
                            ext, (__bridge void *)userarg,
                            tId, getdns_cb);
    getdns_dict_destroy(ext);
    getdns_dict_destroy(addr);
    return r;
}

-(int)service:(NSString*)name
       withExt:(NSDictionary*)extensions
       transId:(uint64_t*)tId
      callback:(GDNSCallback)cb {
    CallbackData* userarg = [self createCallbackData:cb];
    getdns_dict* ext = [GDNSUtil convertToDict:extensions];
    int r = getdns_service(context_, [name UTF8String],
                           ext, (__bridge void *)userarg,
                           tId, getdns_cb);
    getdns_dict_destroy(ext);
    return r;
}

@end
