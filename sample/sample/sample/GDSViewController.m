//
//  GDSViewController.m
//  sample
//
//  Created by Goyal, Neel on 3/1/14.
//  Copyright (c) 2014 getdnsapi. All rights reserved.
//

#import "GDSViewController.h"
#import <getdns/GDNS.h>

@interface GDSViewController ()

@property (strong, nonatomic) GDNSContext* context;

@end

@implementation GDSViewController

@synthesize context;

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    GDNSContext* ctx = [[GDNSContext alloc] initAsStub:YES withResolvers:nil];
    getdns_dict* info = getdns_context_get_api_information(ctx.context);
    char* f = getdns_pretty_print_dict(info);
    NSLog(@"%s", f);
    getdns_dict_destroy(info);
    free(f);
    [ctx address:@"getdnsapi.net" withExt:nil transId:nil callback:^(GDNSContext *context, uint16_t callback_type, struct getdns_dict *response, uint64_t transaction_id) {
        if (response) {
            char* r = getdns_pretty_print_dict(response);
            NSLog(@"%s", r);
            free(r);
            getdns_dict_destroy(response);
        }
    }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
