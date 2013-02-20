//
//  ShopAPIController.h
//  JTGestureBasedTableViewDemo
//
//  Created by Ben Davey on 2/19/13.
//
//

#import <Foundation/Foundation.h>

#define API_TOKEN @"918ee4e316fbeef735526e56645f6129"
#define SERVER_URL @"http://cmshopper.herokuapp.com"

typedef enum ShopAPIControllerRequestType {
    ShopAPIControllerRequestTypeUnknown = 0,
    ShopAPIControllerRequestTypeGetAll,
    ShopAPIControllerRequestTypeAdd,
    ShopAPIControllerRequestTypeDelete,
    ShopAPIControllerRequestTypeUpdate
} ShopAPIControllerRequestType;

@protocol ShopAPIControllerDelegate <NSObject>
@optional
// We'll use CoreData changes to see changes made in the model, really only use this to see if the request has
// Finished with errors or not
- (void)shopAPIControllerRequestFinished:(ShopAPIControllerRequestType *)type withError:(NSError *)error;

@end

@interface ShopAPIController : NSObject
@property (nonatomic,strong) NSOperationQueue *requestQueue;

+ (id)sharedInstance;

// Requests
- (void)getAllItems;
- (void)addItemByName:(NSString *)name andCategory:(NSString *)category;
- (void)deleteItemWithID:(NSNumber *)itemID;
- (void)updateItemWithID:(NSNumber *)itemID toName:(NSString *)name andCategory:(NSString *)category;

// Delegate handling
- (void)addDelegate:(id<ShopAPIControllerDelegate>)delegate;
- (void)removeDelegate:(id<ShopAPIControllerDelegate>)delegate;

@end
