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

#import <Foundation/Foundation.h>

struct getdns_context;
struct getdns_dict;

@interface GDNSContext : NSObject {
    struct getdns_context* context_;
}

@property (nonatomic, readonly) struct getdns_context* context;
@property (nonatomic, readonly) BOOL destroyed;

// callback
typedef void (^GDNSCallback)(GDNSContext* context, uint16_t callback_type,
                            struct getdns_dict* response,
                            uint64_t transaction_id);

// Create a context.  If isStub is false, acts as recursive.
// if isStub is true, then uses either resolverIps or network setting resolvers
// as the upstreams
-(id)initAsStub:(BOOL)isStub
  withResolvers:(NSArray*)resolverIps;

// analogous to getdns_general
-(int)lookup:(NSString*)name
       ofType:(uint16_t)request_type
      withExt:(NSDictionary*)extensions
      transId:(uint64_t*)tId
     callback:(GDNSCallback)cb;

// analogous to getdns_address
-(int)address:(NSString*)name
       withExt:(NSDictionary*)extensions
       transId:(uint64_t*)tId
      callback:(GDNSCallback)cb;

// analogous to getdns_hostname
-(int)hostname:(NSString*)address
        withExt:(NSDictionary*)extensions
        transId:(uint64_t*)tId
       callback:(GDNSCallback)cb;

// analogous to getdns_service
-(int)service:(NSString*)address
       withExt:(NSDictionary*)extensions
       transId:(uint64_t*)tId
      callback:(GDNSCallback)cb;



@end
