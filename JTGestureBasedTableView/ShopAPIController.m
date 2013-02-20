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
@property (nonatomic,strong) NSDateFormatter *dateFormatter;

@end


@implementation ShopAPIController

- (id)init
{
    if (self = [super init]) {
        
        self.requestQueue = [[NSOperationQueue alloc] init];
        
        self.dateFormatter = [[NSDateFormatter alloc] init];
        [self.dateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"];
        [self.dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
        
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
        
    [self sendRequest:ShopAPIControllerRequestTypeGetAll body:nil url:url];
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
    // Construct URL
    NSString *url = [NSString stringWithFormat:@"/items/%@.json",itemID];

    [self sendRequest:ShopAPIControllerRequestTypeDelete body:nil url:url];
}

- (void)updateItemWithID:(NSNumber *)itemID toName:(NSString *)name andCategory:(NSString *)category
{
    // Construct URL
    NSString *url = [NSString stringWithFormat:@"/items/%@.json",itemID];
    
    // Construct body
    NSDictionary *requestBody = @{
                                  @"item":@{
                                          @"name":(name?name:@""),
                                          @"category":(category?category: @"")
                                          }
                                  };
    
    [self sendRequest:ShopAPIControllerRequestTypeUpdate body:requestBody url:url];
}

- (void)sendRequest:(ShopAPIControllerRequestType)requestType body:(id)body url:(NSString *)url
{
    NSURL *nsURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@",SERVER_URL,url]];
    NSLog(@"SETTING URL: %@",[nsURL absoluteString]);
    
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
    
    // Construct JSON object (if there's one)
    if (body) {
        NSError *error = nil;
        NSData *jsonObject = [NSJSONSerialization dataWithJSONObject:body options:NSJSONWritingPrettyPrinted error:&error];
        
        if (error) {
            [self notifyRequestFinished:ShopAPIControllerRequestTypeAdd withError:error];
            return;
        }
     
        NSLog(@"SETTING BODY: %@",[[NSString alloc] initWithData:jsonObject encoding:NSUTF8StringEncoding]);
        [request setHTTPBody:jsonObject];
    }
    
    
    // Send the request
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:self.requestQueue
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
                               
                               NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                               
                               NSLog(@"Response status code %d",httpResponse.statusCode);
                               
                               if (error) {
                                   [self notifyRequestFinished:ShopAPIControllerRequestTypeAdd withError:error];
                                   return;
                               }
                               
                               // A type of error has occured
                               if (httpResponse.statusCode>=400) {
                                   NSDictionary *userInfo = nil;
                                   
                                   switch (httpResponse.statusCode) {
                                       case 401:
                                           userInfo = @{NSLocalizedFailureReasonErrorKey: @"Unauthorized",
                                                        NSLocalizedDescriptionKey: @"Check your auth token"};
                                           break;
                                           
                                       case 404:
                                           userInfo = @{NSLocalizedFailureReasonErrorKey: @"Not Found",
                                                        NSLocalizedDescriptionKey: @"You tried to do something with a non-existent item"};
                                           break;
                                        
                                       case 422:
                                           userInfo = @{NSLocalizedFailureReasonErrorKey: @"Error",
                                                        NSLocalizedDescriptionKey: @"Errors during create or update (422)"};
                                           break;
                                           
                                       case 500:
                                           userInfo = @{NSLocalizedFailureReasonErrorKey: @"Server Error",
                                                        NSLocalizedDescriptionKey: @"Try again later"};
                                           break;
                                           
                                       default:
                                           userInfo = @{NSLocalizedFailureReasonErrorKey: @"HTTP Error",
                                                        NSLocalizedDescriptionKey: @"Failed to complete request"};
                                           break;
                                   }
                                   
                                   
                                   NSError *error = [[NSError alloc] initWithDomain:NSURLErrorDomain
                                                                               code:httpResponse.statusCode
                                                                           userInfo:userInfo];
                                   
                                   [self notifyRequestFinished:ShopAPIControllerRequestTypeAdd withError:error];
                                   return;
                               }
  
//                               NSString *mockResponse = @"[{ \
//                                   \"category\": \"Beverages\", \"created_at\": \"2012-10-10T18:28:03Z\", \"id\": 1,\
//                                   \"name\": \"Kool-aid\", \
//                                   \"updated_at\": \"2012-10-10T18:28:03Z\", \"user_id\": 3 \
//                               }, { \
//                                   \"category\": \"Beverages\", \"created_at\": \"2012-10-10T18:28:03Z\", \"id\": 2, \
//                                   \"name\": \"Ecto cooler\", \
//                                   \"updated_at\": \"2012-10-10T18:28:03Z\", \"user_id\": 3 \
//                               }]";
//                               data = [mockResponse dataUsingEncoding:NSUTF8StringEncoding];
                               
                               // Data back
                               id responseObject = nil;
                               if (data) {
                                   NSError *jsonError = nil;
                                   responseObject = [NSJSONSerialization JSONObjectWithData:data
                                                                                    options:NSJSONReadingMutableLeaves
                                                                                      error:&jsonError];
                                   
                                   if (jsonError) {
                                       [self notifyRequestFinished:ShopAPIControllerRequestTypeAdd withError:jsonError];
                                       return;
                                   }
                               }
                               
                               // Get the response array or put the list item in an array to streamline the process
                               NSArray *listItems = nil;
                               if ([responseObject isKindOfClass:[NSArray class]]) {
                                   listItems = responseObject;
                                   
                               } else if ([responseObject isKindOfClass:[NSDictionary class]]) {
                                   listItems = [NSArray arrayWithObject:responseObject];
                                   
                               }

                               // Store in database
                               [MagicalRecord saveWithBlock:^(NSManagedObjectContext *localContext) {
                                   
                                   // If it's a delete call
                                   if (requestType == ShopAPIControllerRequestTypeGetAll) {
                                       NSPredicate *predicate = [NSPredicate predicateWithFormat:@"listItemID LIKE %@",@"*"];
                                       [MOListItem MR_deleteAllMatchingPredicate:predicate inContext:localContext];
                                   }
                                   
                                   for (NSDictionary *listItemDict in listItems) {
                                       
                                       NSNumber *listItemID = listItemDict[@"id"];
                                       
                                       
                                       // First try to find existing, else create a new one
                                       MOListItem *item = [MOListItem MR_findFirstByAttribute:@"listItemID" withValue:listItemID inContext:localContext];
                                       if (!item) {
                                           item = [MOListItem MR_createInContext:localContext];
                                       }
                                       
                                       item.listItemID = listItemDict[@"id"];
                                       item.userID = listItemDict[@"user_id"];
                                       item.name = listItemDict[@"name"];
                                       item.category = listItemDict[@"category"];
                                       item.updatedAt = [_dateFormatter dateFromString:listItemDict[@"updated_at"]];
                                       item.createdAt = [_dateFormatter dateFromString:listItemDict[@"created_at"]];
                                   }
                                   
                                   // If it's a delete call
                                   if (requestType == ShopAPIControllerRequestTypeDelete) {
                                       // To make it easier, going to grab the ID back out of the URL
                                       // Its the second to last component within the punctuationCharacterSet
                                       NSArray *components = [url componentsSeparatedByCharactersInSet:[NSCharacterSet punctuationCharacterSet]];
                                       if (components.count>1) {
                                           NSString *listItemId = [components objectAtIndex:components.count-2];
                                           
                                           NSPredicate *predicate = [NSPredicate predicateWithFormat:@"listItemID == %@",listItemId];
                                           [MOListItem MR_deleteAllMatchingPredicate:predicate inContext:localContext];
                                       }
                                   }
                                   
                               } completion:^(BOOL success, NSError *error) {
                                   [self notifyRequestFinished:ShopAPIControllerRequestTypeAdd withError:error];
                               }];
                           }];
}

@end
