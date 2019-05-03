#import <Foundation/Foundation.h>

@interface Timetable : NSObject
{
}

@end

#pragma mark -------------------------------------------------------------------------------------------------------------

@interface Schedule : NSObject
{
	Timetable* m_thisway;
	Timetable* m_thatway;
}


@end


#pragma mark -------------------------------------------------------------------------------------------------------------

@interface Schedulizer : NSOperation
{
	NSString* m_route;
	
	Schedule* m_weekdaySchedule;
	NSURLConnection* m_weekdayConnection;
	NSMutableData* m_receivedWeekdayData;
	
	Schedule* m_saturdaySchedule;
	NSURLConnection* m_saturdayConnection;
	NSMutableData* m_receivedSaturdayData;
	
	Schedule* m_sundaySchedule;
	NSURLConnection* m_sundayConnection;
	NSMutableData* m_receivedSundayData;
}

-(id)initWithRouteID:(NSString*)route;

-(void)startScheduleDownload:(int)day connectionPtr:(NSURLConnection**)pConnection scheduleDataPtr:(NSData**)pScheduleData schedulePtr:(Schedule**)pSchedule;
-(Schedule*)parseSchedulePageData:(NSData*)data;

@end

#pragma mark -------------------------------------------------------------------------------------------------------------

@implementation Schedulizer

-(id)initWithRouteID:(NSString*)route
{
	if (nil != (self = [super init]) )
	{
		m_route = [route retain];
		m_weekdaySchedule = nil;
		m_saturdaySchedule = nil;
		m_sundaySchedule = nil;				
	}
	return self;
}

-(void)dealloc
{
	[m_route release];
	[m_weekdaySchedule release];
	[m_saturdaySchedule release];
	[m_sundaySchedule release];				
    [super dealloc];
}

-(void)main
{
	[self startScheduleDownload:0 connectionPtr:&m_weekdayConnection scheduleDataPtr:&m_receivedWeekdayData schedulePtr:&m_weekdaySchedule];
	[self startScheduleDownload:1 connectionPtr:&m_saturdayConnection scheduleDataPtr:&m_receivedSaturdayData schedulePtr:&m_saturdaySchedule];
	[self startScheduleDownload:2 connectionPtr:&m_sundayConnection scheduleDataPtr:&m_receivedSundayData schedulePtr:&m_sundaySchedule];		
}

// 0 == weekday, 1 == Saturday, 2 == Sunday
-(void)startScheduleDownload:(int)day connectionPtr:(NSURLConnection**)pConnection scheduleDataPtr:(NSData**)pScheduleData schedulePtr:(Schedule**)pSchedule
{
	static NSString* schedFormat = @"http://transit.metrokc.gov/tops/bus/schedules/s%03d_%d_.html";
	NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:schedFormat, [m_route intValue], day]]
											 cachePolicy:NSURLRequestUseProtocolCachePolicy
										 timeoutInterval:60.0];

#if 0 // async
	// create the connection with the request
	// and start loading the data
	*pConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	if ( *pConnection )
	{
		*pScheduleData = [[NSMutableData data] retain];
	}
	else
	{
		// inform the user that the download could not be made
	}
#else //sync
	NSHTTPURLResponse* response = nil;
	NSError* error = nil;
	
	*pScheduleData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
	
	if ( error == nil && *pScheduleData != nil && [response statusCode] == 200 )
	{
		*pSchedule = [self parseSchedulePageData:*pScheduleData];
		if ( *pSchedule )
		{
			NSLog(@"Schedule: %@\n", *pSchedule);
		}
	}
#endif
}

-(Schedule*)parseSchedulePageData:(NSData*)data
{
	NSString* scheduleSrc = [[NSString alloc] initWithBytes:[data bytes] length:[data length] encoding:NSUTF8StringEncoding];

	// find the 'thisway' timetable
	// find the string '<!-- end timetable bar nav -->', then the first <h5> element after that: that's the name of the thisway timetable
	// the <pre> section is the timetable.
	
	return nil;
}

-(void)connection:(NSURLConnection*)connection didReceiveResponse:(NSURLResponse*)response
{
	NSHTTPURLResponse* theHttpUrlResponse = (NSHTTPURLResponse*)response;
	
	if ( [connection isEqual:m_weekdayConnection] )
	{
		[m_receivedWeekdayData setLength:0];
	}
	else if ( [connection isEqual:m_saturdayConnection] )
	{
		[m_receivedSaturdayData setLength:0];
	}
	else
	{
		[m_receivedSundayData setLength:0];
	}
	
	if ( [theHttpUrlResponse statusCode] != 200 )
	{
		[connection cancel];
	}
}

-(void)connection:(NSURLConnection*)connection didReceiveData:(NSData*)data
{
	if ( [connection isEqual:m_weekdayConnection] )
	{
		[m_receivedWeekdayData appendData:data];
	}
	else if ( [connection isEqual:m_saturdayConnection] )
	{
		[m_receivedSaturdayData appendData:data];
	}
	else
	{
		[m_receivedSundayData appendData:data];
	}	
}

-(void)connection:(NSURLConnection*)connection didFailWithError:(NSError*)error
{
	if ( [connection isEqual:m_weekdayConnection] )
	{
		[m_receivedWeekdayData release];
	}
	else if ( [connection isEqual:m_saturdayConnection] )
	{
		[m_receivedSaturdayData release];
	}
	else
	{
		[m_receivedSundayData release];
	}	
	
    [connection release];
	
    // inform the user
    NSLog(@"Connection failed! Error - %@ %@",
          [error localizedDescription],
          [[error userInfo] objectForKey:NSErrorFailingURLStringKey]);
}

-(void)connectionDidFinishLoading:(NSURLConnection*)connection
{	
	if ( [connection isEqual:m_weekdayConnection] )
	{
		m_weekdaySchedule = [self parseSchedulePageData:m_receivedWeekdayData];
		
		[m_receivedWeekdayData release];
	}
	else if ( [connection isEqual:m_saturdayConnection] )
	{
		m_saturdaySchedule = [self parseSchedulePageData:m_receivedSaturdayData];
				
		[m_receivedSaturdayData release];
	}
	else
	{
		m_sundaySchedule = [self parseSchedulePageData:m_receivedSundayData];
				
		[m_receivedSundayData release];
	}	
	
    [connection release];	
}

@end



int main (int argc, const char * argv[])
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

	Schedulizer* operation = [[Schedulizer alloc] initWithRouteID:@"30"];
	
	[operation start];
	
	[operation release];
    [pool drain];
    return 0;
}
