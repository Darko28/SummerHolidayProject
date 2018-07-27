//
//  LineDashPolyline.swift
//  SummerHolidayProject
//
//  Created by Darko on 2018/7/27.
//  Copyright © 2018 Darko. All rights reserved.
//

import Foundation
import MAMapKit


class LineDashPolyline: MAPolyline, MAOverlay {
    
    lazy var coordinate: CLLocationCoordinate2D = {
        return self.polyline.coordinate
    }()
    
    lazy var boundingMapRect: MAMapRect = {
        return self.polyline.boundingMapRect
    }()
    
    var polyline: MAPolyline
    
    init(polyline: MAPolyline) {
        self.polyline = polyline
    }
}
