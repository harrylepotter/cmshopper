//
//  MOListItem.h
//  JTGestureBasedTableViewDemo
//
//  Created by Andreas Wulf on 21/02/13.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface MOListItem : NSManagedObject

@property (nonatomic, retain) NSDate * updatedAt;
@property (nonatomic, retain) NSString * category;
@property (nonatomic, retain) NSDate * createdAt;
@property (nonatomic, retain) NSNumber * listItemID;
@property (nonatomic, retain) NSNumber * userID;
@property (nonatomic, retain) NSString * name;

@end
