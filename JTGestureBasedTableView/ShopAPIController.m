//
//  ShopAPIController.m
//  JTGestureBasedTableViewDemo
//
//  Created by Ben Davey on 2/19/13.
//
//

#import "ShopAPIController.h"

@interface ShopAPIController ()
@property (nonatomic,strong) NSMutableSet *delegates;

@end


@implementation ShopAPIController

- (id)init
{
    if (self = [super init]) {
        
        self.requestQueue = [[NSOperationQueue alloc] init];
        
        // Creating a non retaining set for delegates
        //Default callbacks
        CFSetCallBacks callbacks = kCFTypeSetCallBacks;
        
        //Disable retain and release
        callbacks.retain = NULL;
        callbacks.release = NULL;
        
        self.delegates = (NSMutableSet *)CFBridgingRelease(CFSetCreateMutable(kCFAllocatorDefault, 0, &callbacks));
    }
    
    return self;
}

- (void)dealloc
{
    [self.requestQueue cancelAllOperations];
}

+ (id)sharedInstance
{
    static ShopAPIController *sharedInstance;
    if (!sharedInstance) {
        sharedInstance = [[self alloc] init];
    }
    return sharedInstance;
}


#pragma mark - For Delegates
- (void)addDelegate:(id<ShopAPIControllerDelegate>)delegate
{
    [self.delegates addObject:delegate];
}

- (void)removeDelegate:(id<ShopAPIControllerDelegate>)delegate
{
    [self.delegates removeObject:delegate];
}

- (void)notifyRequestFinished:(ShopAPIControllerRequestType *)requestType withError:(NSError *)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
        for (id<ShopAPIControllerDelegate> delegate in self.delegates) {
            if ([delegate respondsToSelector:@selector(shopAPIControllerRequestFinished:withError:)]) {
                [delegate shopAPIControllerRequestFinished:requestType withError:error];
            }
        }
    });
}

#pragma mark - Requests

// Requests
- (void)getAllItems
{
    // Construct URL
    NSString *url = @"/items.json";
        
    [self sendRequest:ShopAPIControllerRequestTypeAdd body:nil url:url];
}

- (void)addItemByName:(NSString *)name andCategory:(NSString *)category
{
    // Construct URL
    NSString *url = @"/items.json";
    
    // Construct body
    NSDictionary *requestBody = @{
                                  @"item":@{
                                          @"name":(name?name:@""),
                                          @"category":(category?category: @"")
                                          }
                                  };
    
    [self sendRequest:ShopAPIControllerRequestTypeAdd body:requestBody url:url];
}

- (void)deleteItemWithID:(NSNumber *)itemID
{
    
}

- (void)updateItemWithID:(NSNumber *)itemID toName:(NSString *)name andCategory:(NSString *)category
{
    
}

- (void)sendRequest:(ShopAPIControllerRequestType)requestType body:(id)body url:(NSString *)url
{
    NSURL *nsURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@",SERVER_URL,url]];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:nsURL];
    
    // Set headers
    [request addValue:API_TOKEN forHTTPHeaderField:@"X-CM-Authorization"];
    
    switch (requestType) {
        case ShopAPIControllerRequestTypeGetAll:
            [request setHTTPMethod:@"GET"];
            [request addValue:@"application/json" forHTTPHeaderField:@"Accept"];
            break;
            
        case ShopAPIControllerRequestTypeAdd:
            [request setHTTPMethod:@"POST"];
            [request addValue:@"application/json" forHTTPHeaderField:@"Accept"];
            [request addValue:@"application/json" forHTTPHeaderField:@"Content-type"];
            break;
            
        case ShopAPIControllerRequestTypeDelete:
            [request setHTTPMethod:@"DELETE"];
            break;
            
        case ShopAPIControllerRequestTypeUpdate:
            [request setHTTPMethod:@"PUT"];
            [request addValue:@"application/json" forHTTPHeaderField:@"Accept"];
            [request addValue:@"application/json" forHTTPHeaderField:@"Content-type"];
            break;
            
        default:
            break;
    }
    
    // Construct JSON object    
    NSError *error = nil;
    NSData *jsonObject = [NSJSONSerialization dataWithJSONObject:body options:NSJSONWritingPrettyPrinted error:&error];
    
    if (error) {
        [self notifyRequestFinished:ShopAPIControllerRequestTypeAdd withError:error];
        return;
    }
    
    [request setHTTPBody:jsonObject];
    
    //NSLog(@"SETTING BODY: %@",[[NSString alloc] initWithData:jsonObject encoding:NSUTF8StringEncoding]);
    
    
    // Send the request
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:self.requestQueue
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
                               
                               if (error) {
                                   [self notifyRequestFinished:ShopAPIControllerRequestTypeAdd withError:error];
                                   return;
                               }
                               
                               // Data back
                               NSError *jsonError = nil;
                               NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data
                                                                                            options:NSJSONReadingMutableLeaves
                                                                                              error:&jsonError];
                               
                               if (jsonError) {
                                   [self notifyRequestFinished:ShopAPIControllerRequestTypeAdd withError:jsonError];
                                   return;
                               }
                               
                               // Store in database
                               MOListItem *item = [MOListItem MR_createEntity];
                               item.listItemID = responseDict[@"id"];
                               item.userID = responseDict[@"user_id"];
                               item.name = responseDict[@"name"];
                               item.category = responseDict[@"category"];
                               item.updatedAt = responseDict[@"updated_at"];
                               item.createdAt = responseDict[@"created_at"];
                               
                               NSError *cdError = nil;
                               [[NSManagedObjectContext MR_contextForCurrentThread] save:&cdError];
                               
                               if (cdError) {
                                   [self notifyRequestFinished:ShopAPIControllerRequestTypeAdd withError:cdError];
                                   return;
                               }
                           }];
}

@end
