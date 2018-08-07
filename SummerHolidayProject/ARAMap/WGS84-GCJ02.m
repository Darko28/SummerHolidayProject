//
//  WGS84-GCJ02.m
//  MOSProject
//
//  Created by Darko on 2017/11/22.
//  Copyright © 2017年 Darko. All rights reserved.
//

#import "WGS84-GCJ02.h"

/*
const double a = 6378245.0;
const double ee = 0.00669342162296594323;
const double pi = 3.14159265358979324;


@implementation WGS84_GCJ02

+(CLLocationCoordinate2D)transformFromWGSToGCJ:(CLLocationCoordinate2D)wgsLoc
{
    CLLocationCoordinate2D adjustLoc;
    if([self isLocationOutOfChina:wgsLoc]){
        adjustLoc = wgsLoc;
    }else{
        double adjustLat = [self transformLatWithX:wgsLoc.longitude - 105.0 withY:wgsLoc.latitude - 35.0];
        double adjustLon = [self transformLonWithX:wgsLoc.longitude - 105.0 withY:wgsLoc.latitude - 35.0];
        double radLat = wgsLoc.latitude / 180.0 * pi;
        double magic = sin(radLat);
        magic = 1 - ee * magic * magic;
        double sqrtMagic = sqrt(magic);
        adjustLat = (adjustLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * pi);
        adjustLon = (adjustLon * 180.0) / (a / sqrtMagic * cos(radLat) * pi);
        adjustLoc.latitude = wgsLoc.latitude + adjustLat;
        adjustLoc.longitude = wgsLoc.longitude + adjustLon;
    }
    return adjustLoc;
}

+(BOOL)isLocationOutOfChina:(CLLocationCoordinate2D)location
{
    if (location.longitude < 72.004 || location.longitude > 137.8347 || location.latitude < 0.8293 || location.latitude > 55.8271)
        return YES;
    return NO;
}

+(double)transformLatWithX:(double)x withY:(double)y
{
    double lat = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(fabs(x));
    lat += (20.0 * sin(6.0 * x * pi) + 20.0 *sin(2.0 * x * pi)) * 2.0 / 3.0;
    lat += (20.0 * sin(y * pi) + 40.0 * sin(y / 3.0 * pi)) * 2.0 / 3.0;
    lat += (160.0 * sin(y / 12.0 * pi) + 3320 * sin(y * pi / 30.0)) * 2.0 / 3.0;
    return lat;
}

+(double)transformLonWithX:(double)x withY:(double)y
{
    double lon = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(fabs(x));
    lon += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0;
    lon += (20.0 * sin(x * pi) + 40.0 * sin(x / 3.0 * pi)) * 2.0 / 3.0;
    lon += (150.0 * sin(x / 12.0 * pi) + 300.0 * sin(x / 30.0 * pi)) * 2.0 / 3.0;
    return lon;
}

// World Geodetic System ==> Mars Geodetic System
+ (CLLocationCoordinate2D)WorldGS2MarsGS:(CLLocationCoordinate2D)coordinate
{
    // a = 6378245.0, 1/f = 298.3
    // b = a * (1 - f)
    // ee = (a^2 - b^2) / a^2;
    const double a = 6378245.0;
    const double ee = 0.00669342162296594323;

    CLLocationCoordinate2D location = CLLocationCoordinate2DMake(coordinate.latitude, coordinate.longitude);
    
    if ([WGS84_GCJ02 isLocationOutOfChina:location])
    {
        return coordinate;
    }
    double wgLat = coordinate.latitude;
    double wgLon = coordinate.longitude;
    double dLat = [WGS84_GCJ02 transformLatWithX:(wgLon - 105.0) withY:(wgLat - 35.0)];
//    double dLat = [WGS84_GCJ02 transformLatWithX(wgLon - 105.0, withY: wgLat - 35.0)];
//    double dLon = transformLon(wgLon - 105.0, wgLat - 35.0);
    double dLon = [WGS84_GCJ02 transformLonWithX:(wgLon - 105.0) withY:(wgLat - 35.0)];
    double radLat = wgLat / 180.0 * pi;
    double magic = sin(radLat);
    magic = 1 - ee * magic * magic;
    double sqrtMagic = sqrt(magic);
    dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * pi);
    dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * pi);

    return CLLocationCoordinate2DMake(wgLat + dLat, wgLon + dLon);
}

// Mars Geodetic System ==> World Geodetic System
+ (CLLocationCoordinate2D)MarsGS2WorldGS:(CLLocationCoordinate2D)coordinate
{
    double gLat = coordinate.latitude;
    double gLon = coordinate.longitude;
    CLLocationCoordinate2D marsCoor = [WGS84_GCJ02 WorldGS2MarsGS:coordinate];
    double dLat = marsCoor.latitude - gLat;
    double dLon = marsCoor.longitude - gLon;
    return CLLocationCoordinate2DMake(gLat - dLat, gLon - dLon);
}

public static Gps gps84_To_Gcj02(double lat, double lon) {
    if (outOfChina(lat, lon)) {
        return null;
    }
    double dLat = transformLat(lon - 105.0, lat - 35.0);
    double dLon = transformLon(lon - 105.0, lat - 35.0);
    double radLat = lat / 180.0 * pi;
    double magic = Math.sin(radLat);
    magic = 1 - ee * magic * magic;
    double sqrtMagic = Math.sqrt(magic);
    dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * pi);
    dLon = (dLon * 180.0) / (a / sqrtMagic * Math.cos(radLat) * pi);
    double mgLat = lat + dLat;
    double mgLon = lon + dLon;
    return new Gps(mgLat, mgLon);
}

 * * 火星坐标系 (GCJ-02) to 84 * * @param lon * @param lat * @return
public static Gps gcj_To_Gps84(double lat, double lon) {
    Gps gps = transform(lat, lon);
    double lontitude = lon * 2 - gps.getWgLon();
    double latitude = lat * 2 - gps.getWgLat();
    return new Gps(latitude, lontitude);
}

public static Gps transform(double lat, double lon) {
    if (outOfChina(lat, lon)) {
        return new Gps(lat, lon);
    }
    double dLat = transformLat(lon - 105.0, lat - 35.0);
    double dLon = transformLon(lon - 105.0, lat - 35.0);
    double radLat = lat / 180.0 * pi;
    double magic = Math.sin(radLat);
    magic = 1 - ee * magic * magic;
    double sqrtMagic = Math.sqrt(magic);
    dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * pi);
    dLon = (dLon * 180.0) / (a / sqrtMagic * Math.cos(radLat) * pi);
    double mgLat = lat + dLat;
    double mgLon = lon + dLon;
    return new Gps(mgLat, mgLon);
}

public static double transformLat(double x, double y) {
    double ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y
    + 0.2 * Math.sqrt(Math.abs(x));
    ret += (20.0 * Math.sin(6.0 * x * pi) + 20.0 * Math.sin(2.0 * x * pi)) * 2.0 / 3.0;
    ret += (20.0 * Math.sin(y * pi) + 40.0 * Math.sin(y / 3.0 * pi)) * 2.0 / 3.0;
    ret += (160.0 * Math.sin(y / 12.0 * pi) + 320 * Math.sin(y * pi / 30.0)) * 2.0 / 3.0;
    return ret;
}

public static double transformLon(double x, double y) {
    double ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1
    * Math.sqrt(Math.abs(x));
    ret += (20.0 * Math.sin(6.0 * x * pi) + 20.0 * Math.sin(2.0 * x * pi)) * 2.0 / 3.0;
    ret += (20.0 * Math.sin(x * pi) + 40.0 * Math.sin(x / 3.0 * pi)) * 2.0 / 3.0;
    ret += (150.0 * Math.sin(x / 12.0 * pi) + 300.0 * Math.sin(x / 30.0
                                                               * pi)) * 2.0 / 3.0;
    return ret;
}


@end
*/
