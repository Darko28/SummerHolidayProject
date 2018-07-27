//
//  MANaviPolyline.swift
//  SummerHolidayProject
//
//  Created by Darko on 2018/7/27.
//  Copyright © 2018 Darko. All rights reserved.
//

import Foundation
import MAMapKit


class MANaviPolyline: MAPolyline, MAOverlay {
    
    var type: MANaviAnnotationType!
    var polyline: MAPolyline
    
    init(polyline: MAPolyline) {
        self.polyline = polyline
        self.type = MANaviAnnotationType.Drive
    }
    
    lazy var coordinate: CLLocationCoordinate2D = {
        return polyline.coordinate
    }()
    
    lazy var boundingMapRect: MAMapRect = {
        return polyline.boundingMapRect
    }()
}
