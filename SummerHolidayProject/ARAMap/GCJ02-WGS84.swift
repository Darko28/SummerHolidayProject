//
//  GCJ02-WGS84.swift
//  MOSProject
//
//  Created by Darko on 2017/11/22.
//  Copyright © 2017年 Darko. All rights reserved.
//

import UIKit
import CoreLocation


let pi: Double = 3.14159265358979324
let ee: Double = 0.00669342162296594323
let a: Double = 6378245.0

class GCJ02_WGS84: NSObject {

    class func transformLat(x: Double, y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(fabs(x))
        ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0
        ret += (20.0 * sin(y * pi) + 40.0 * sin(y / 3.0 * pi)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * pi) + 320 * sin(y * pi / 30.0)) * 2.0 / 3.0
        return ret
    }
    
    class func transformLon(x: Double, y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(fabs(x))
        ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0
        ret += (20.0 * sin(x * pi) + 40.0 * sin(x / 3.0 * pi)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * pi) + 300.0 * sin(x / 30.0 * pi)) * 2.0 / 3.0
        return ret
    }
    
    class func transform(lat: Double, lon: Double) -> CLLocationCoordinate2D {
        
        // out of China
        
        var dLat: Double = transformLat(x: lon - 105.0, y: lat - 35.0)
        var dLon: Double = transformLon(x: lon - 105.0, y: lat - 35.0)
        let radLat: Double = lat / 180.0 * pi
        var magic: Double = sin(radLat)
        magic = 1 - ee * magic * magic
        
        let sqrtMagic: Double = sqrt(magic)
        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * pi)
        dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * pi)
        
        let myLat: Double = lat + dLat
        let myLon: Double = lon + dLon
        
        return CLLocationCoordinate2DMake(myLat, myLon)
    }
    
    class func gcj02ToWGS84(lat: Double, lon: Double) -> CLLocationCoordinate2D {
        let gps = transform(lat: lat, lon: lon)
        let longitude: Double = lon * 2 - gps.longitude
        let latitude: Double = lat * 2 - gps.latitude
        return CLLocationCoordinate2DMake(latitude, longitude)
    }
    
}
