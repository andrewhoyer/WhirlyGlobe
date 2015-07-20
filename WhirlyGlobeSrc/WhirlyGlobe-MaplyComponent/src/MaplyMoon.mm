/*
 *  MaplyMoon.mm
 *  WhirlyGlobe-MaplyComponent
 *
 *  Created by Steve Gifford on 7/2/15.
 *  Copyright 2011-2015 mousebird consulting
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *  http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 *
 */

#import "MaplyMoon.h"
#import <AA+.h>

@implementation MaplyMoon
{
    NSDate *date;
    double moonLon,moonLat;
}

// Math borrowed from: http://www.lunar-occultations.com/rlo/ephemeris.htm
- (id)initWithDate:(NSDate *)inDate
{
    self = [super init];

    date = inDate;

    // Start with the Julian Date
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    calendar.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    NSDateComponents *components = [calendar components:(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit) fromDate:date];
    CAADate aaDate(components.year,components.month,components.day,components.hour,components.minute,components.second,true);
    double jd = aaDate.Julian();
    
    // Position of the moon in equatorial
    double moonEclipticLong = CAAMoon::EclipticLongitude(jd);
    double moonEclipticLat = CAAMoon::EclipticLatitude(jd);
    double obliquity = CAANutation::MeanObliquityOfEcliptic(jd);
    CAA2DCoordinate moonEquatorial = CAACoordinateTransformation::Ecliptic2Equatorial(moonEclipticLong,moonEclipticLat,obliquity);

    double siderealTime = CAASidereal::MeanGreenwichSiderealTime(jd);

    moonLon = CAACoordinateTransformation::DegreesToRadians(15*(moonEquatorial.X-siderealTime));
    moonLat = CAACoordinateTransformation::DegreesToRadians(moonEquatorial.Y);

    return self;
}

- (MaplyCoordinate)asCoordinate
{
    return MaplyCoordinateMake(moonLon,moonLat);
}

- (MaplyCoordinate3d)asPosition
{
    return MaplyCoordinate3dMake(moonLon,moonLat, 5.0);
}

@end
