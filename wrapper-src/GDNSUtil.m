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

#import <CFNetwork/CFNetwork.h>
#import <getdns/getdns.h>
#import <getdns/getdns_extra.h>

#import <ctype.h>
#include <arpa/inet.h>
#include <ifaddrs.h>
#include <resolv.h>
#include <dns.h>
#include <netinet/in.h>

#import "GDNSUtil.h"
#import "GDNSContext.h"

@implementation GDNSUtil

struct nsrunloop_data {
    CFSocketRef cSock;
    CFRunLoopRef runLoop;
    CFRunLoopSourceRef source;
};

static void
request_count_changed(uint32_t request_count, struct nsrunloop_data *ev_data) {
    if (request_count > 0) {
        CFRunLoopAddSource(ev_data->runLoop, ev_data->source, kCFRunLoopCommonModes);
    } else {
        CFRunLoopRemoveSource(ev_data->runLoop, ev_data->source, kCFRunLoopCommonModes);
    }
}

static void readCallback (CFSocketRef s,
                          CFSocketCallBackType callbackType,
                          CFDataRef address,
                          const void *data,
                          void *info)
{
    
    GDNSContext *ctx = (__bridge GDNSContext *)info;
    struct getdns_context* context = ctx.context;
    getdns_context_process_async(context);
    uint32_t rc = getdns_context_get_num_pending_requests(context, NULL);
    struct nsrunloop_data* ev_data =
    (struct nsrunloop_data*) getdns_context_get_extension_data(context);
    request_count_changed(rc, ev_data);
}

// event loop

/* getdns extension functions */
static getdns_return_t
getdns_nsrunloop_request_count_changed(struct getdns_context* context,
                                       uint32_t request_count, void* eventloop_data) {
    struct nsrunloop_data *edata = (struct nsrunloop_data*) eventloop_data;
    request_count_changed(request_count, edata);
    return GETDNS_RETURN_GOOD;
}

static getdns_return_t
getdns_nsrunloop_cleanup(struct getdns_context* context, void* data) {
    struct nsrunloop_data *edata = (struct nsrunloop_data*) data;
    CFRunLoopRemoveSource(edata->runLoop, edata->source, kCFRunLoopCommonModes);
    CFRelease(edata->source);
    CFRelease(edata->cSock);
    free(edata);
    return GETDNS_RETURN_GOOD;
}

static getdns_return_t
getdns_nsrunloop_schedule_timeout(struct getdns_context* context,
                                  void* eventloop_data, uint16_t timeout,
                                  getdns_timeout_data_t* timeout_data,
                                  void** eventloop_timer) {
    return GETDNS_RETURN_GOOD;
}

static getdns_return_t
getdns_nsrunloop_clear_timeout(struct getdns_context* context,
                               void* eventloop_data, void* eventloop_timer) {
    return GETDNS_RETURN_GOOD;
}


static getdns_eventloop_extension nsrunloop_EXT = {
    getdns_nsrunloop_cleanup,
    getdns_nsrunloop_schedule_timeout,
    getdns_nsrunloop_clear_timeout,
    getdns_nsrunloop_request_count_changed
};

// event loop attachment
+(BOOL)attachEventLoop:(GDNSContext*)context {
    struct getdns_context* ctx = context.context;
    int fd = getdns_context_fd(ctx);
    CFSocketContext theContext;
    theContext.version = 0;
    theContext.info = (__bridge void *)(context);
    theContext.retain = nil;
    theContext.release = nil;
    theContext.copyDescription = nil;
    CFSocketRef cSock = CFSocketCreateWithNative(kCFAllocatorDefault, fd, kCFSocketReadCallBack, readCallback, &theContext);
    struct nsrunloop_data* data = (struct nsrunloop_data*) malloc(sizeof(struct nsrunloop_data));
    data->cSock = cSock;
    data->source = CFSocketCreateRunLoopSource(kCFAllocatorDefault, cSock, 0);
    data->runLoop = [[NSRunLoop currentRunLoop] getCFRunLoop];
    return getdns_extension_set_eventloop(ctx, &nsrunloop_EXT, data) == GETDNS_RETURN_GOOD;
}

+(id)convertBinData:(getdns_bindata*)data {
    BOOL printable = YES;
    for (size_t i = 0; i < data->size; ++i) {
        if (isprint(data->data[i])) {
            printable = NO;
            break;
        }
    }
    if (printable) {
        // convert to nsstring
        return [[NSString alloc] initWithBytes:data->data length:data->size encoding:NSASCIIStringEncoding];
    } else {
        return [NSData dataWithBytes:data->data length:data->size];
    }
}

// conversions
+(NSArray*)convertToNSArray:(struct getdns_list*)list {
    if (!list) {
        return nil;
    }
    NSMutableArray* result = [NSMutableArray array];
    size_t len = 0;
    getdns_list_get_length(list, &len);
    for (size_t i = 0; i < len; ++i) {
        getdns_data_type type;
        getdns_list_get_data_type(list, i, &type);
        switch (type) {
            case t_bindata:
            {
                getdns_bindata* data = NULL;
                getdns_list_get_bindata(list, i, &data);
                [result addObject:[GDNSUtil convertBinData:data]];
                break;
            }
            case t_int:
            {
                uint32_t res = 0;
                getdns_list_get_int(list, i, &res);
                [result addObject:[NSNumber numberWithUnsignedInteger:res]];
                break;
            }
            case t_dict:
            {
                getdns_dict* dict = NULL;
                getdns_list_get_dict(list, i, &dict);
                [result addObject:[GDNSUtil convertToNSDict:dict]];
                break;
            }
            case t_list:
            {
                getdns_list* sublist = NULL;
                getdns_list_get_list(list, i, &sublist);
                [result addObject:[GDNSUtil convertToNSArray:sublist]];
                break;
            }
            default:
                break;
        }
    }
    return result;
}

+(NSDictionary*)convertToNSDict:(struct getdns_dict*)dict {
    if (!dict) {
        return nil;
    }
    getdns_list* names;
    getdns_dict_get_names(dict, &names);
    size_t len = 0;
    NSMutableDictionary* result = [NSMutableDictionary dictionary];
    getdns_list_get_length(names, &len);
    for (size_t i = 0; i < len; ++i) {
        getdns_bindata* nameBin;
        getdns_list_get_bindata(names, i, &nameBin);
        NSString* name = [GDNSUtil convertBinData:nameBin];
        getdns_data_type type;
        getdns_dict_get_data_type(dict, (char*)nameBin->data, &type);
        switch (type) {
            case t_bindata:
            {
                getdns_bindata* data = NULL;
                getdns_dict_get_bindata(dict, (char*)nameBin->data, &data);
                [result setObject:[GDNSUtil convertBinData:data] forKey:name];
                break;
            }
            case t_int:
            {
                uint32_t res = 0;
                getdns_dict_get_int(dict, (char*)nameBin->data, &res);
                [result setObject:[NSNumber numberWithUnsignedInteger:res] forKey:name];
                break;
            }
            case t_dict:
            {
                getdns_dict* subdict = NULL;
                getdns_dict_get_dict(dict, (char*)nameBin->data, &subdict);
                [result setObject:[GDNSUtil convertToNSDict:subdict] forKey:name];
                break;
            }
            case t_list:
            {
                getdns_list* list = NULL;
                getdns_dict_get_list(dict, (char*)nameBin->data, &list);
                [result setObject:[GDNSUtil convertToNSArray:list] forKey:name];
                break;
            }
            default:
                break;
        }
    }
    getdns_list_destroy(names);
    return result;
}



+(struct getdns_dict*)convertToDict:(NSDictionary*)dict {
    if (!dict) {
        return NULL;
    }
    getdns_dict* result = getdns_dict_create();
    for (NSString* key in dict) {
        const char* cKey = [key UTF8String];
        id val = [dict objectForKey:key];
        if ([val isKindOfClass:[NSString class]]) {
            NSString* v = val;
            getdns_dict_util_set_string(result, (char*) cKey, [v UTF8String]);
        } else if ([val isKindOfClass:[NSData class]]) {
            getdns_bindata bdata;
            NSData* data = val;
            bdata.data = (uint8_t*)data.bytes;
            bdata.size = data.length;
            getdns_dict_set_bindata(result, cKey, &bdata);
        } else if ([val isKindOfClass:[NSDictionary class]]) {
            NSDictionary* d = val;
            getdns_dict* subdict = [GDNSUtil convertToDict:d];
            getdns_dict_set_dict(result, cKey, subdict);
            getdns_dict_destroy(subdict);
        } else if ([val isKindOfClass:[NSArray class]]) {
            NSArray* l = val;
            getdns_list* sublist = [GDNSUtil convertToList:l];
            getdns_dict_set_list(result, cKey, sublist);
            getdns_list_destroy(sublist);
        } else if ([val isKindOfClass:[NSNumber class]]) {
            NSNumber* num = val;
            getdns_dict_set_int(result, cKey, [num unsignedIntegerValue]);
        }
    }
    return result;
}

+(struct getdns_list*)convertToList:(NSArray*)list {
    if (!list) {
        return NULL;
    }
    getdns_list* result = getdns_list_create();
    size_t idx = 0;
    for (id val in list) {
        getdns_list_get_length(result, &idx);
        if ([val isKindOfClass:[NSString class]]) {
            NSString* v = val;
            getdns_bindata bdata;
            NSData* data = [v dataUsingEncoding:NSASCIIStringEncoding];
            bdata.data = (uint8_t*)data.bytes;
            bdata.size = data.length;
            getdns_list_set_bindata(result, idx, &bdata);
        } else if ([val isKindOfClass:[NSData class]]) {
            getdns_bindata bdata;
            NSData* data = val;
            bdata.data = (uint8_t*)data.bytes;
            bdata.size = data.length;
            getdns_list_set_bindata(result, idx, &bdata);
        } else if ([val isKindOfClass:[NSDictionary class]]) {
            NSDictionary* d = val;
            getdns_dict* subdict = [GDNSUtil convertToDict:d];
            getdns_list_set_dict(result, idx, subdict);
            getdns_dict_destroy(subdict);
        } else if ([val isKindOfClass:[NSArray class]]) {
            NSArray* l = val;
            getdns_list* sublist = [GDNSUtil convertToList:l];
            getdns_list_set_list(result, idx, sublist);
            getdns_list_destroy(sublist);
        } else if ([val isKindOfClass:[NSNumber class]]) {
            NSNumber* num = val;
            getdns_list_set_int(result, idx, [num unsignedIntegerValue]);
        }
    }
    return result;
}

// Courtesy of http://stackoverflow.com/questions/10999612/iphone-get-3g-dns-host-name-and-ip-address
+ (NSArray *) getDnsIPs {
    NSMutableArray *addresses = [NSMutableArray array];
    struct __res_state rs;
    res_state res = &rs;
    int result = res_ninit(res);
    if ( result == 0 )
    {
        for ( int i = 0; i < res->nscount; i++ )
        {
            NSString *s = [NSString stringWithUTF8String :  inet_ntoa(res->nsaddr_list[i].sin_addr)];
            [addresses addObject:s];
        }
    }
    return addresses;
}

+(struct getdns_dict*)convertIpStr:(NSString*)ip {
    int ret;
    struct in_addr dst;
    getdns_bindata addr_data;
    const char* ipStr = [ip UTF8String];
    ret = inet_pton(AF_INET, ipStr, &dst);
    if (ret == 1) {
        // v4
        getdns_dict* res = getdns_dict_create();
        getdns_dict_util_set_string(res, "address_type", "IPv4");
        addr_data.data = (uint8_t*) &dst;
        addr_data.size = sizeof(dst);
        getdns_dict_set_bindata(res, "address_data", &addr_data);
        return res;
    } else {
        struct in6_addr dst6;
        ret = inet_pton(AF_INET6, ipStr, &dst6);
        if (ret != 1) {
            // failure
            return NULL;
        }
        getdns_dict* res = getdns_dict_create();
        getdns_dict_util_set_string(res, "address_type", "IPv6");
        addr_data.data = (uint8_t*)&dst6;
        addr_data.size = sizeof(dst6);
        getdns_dict_set_bindata(res, "address_data", &addr_data);
        return res;
    }
}

+(struct getdns_list*)convertIpsToList:(NSArray*)ips {
    getdns_list* result = getdns_list_create();
    for (NSString* ip in ips) {
        NSArray* parts = [ip componentsSeparatedByString:@" "];
        NSString* ipStr = [parts objectAtIndex:0];
        getdns_dict* ipDict = [GDNSUtil convertIpStr:ipStr];
        if (ipDict) {
            if (parts.count > 1) {
                NSInteger port = [[parts objectAtIndex:1] integerValue];
                if (port != 0) {
                    getdns_dict_set_int(ipDict, "port", port);
                }
            }
            size_t idx = 0;
            getdns_list_get_length(result, &idx);
            getdns_list_set_dict(result, idx, ipDict);
            getdns_dict_destroy(ipDict);
        }
    }
    return result;
}

@end
