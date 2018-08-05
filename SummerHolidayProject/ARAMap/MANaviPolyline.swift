//
//  MANaviPolyline.swift
//  SummerHolidayProject
//
//  Created by Darko on 2018/7/27.
//  Copyright © 2018 Darko. All rights reserved.
//

import Foundation
import MAMapKit


class MANaviPolyline: NSObject, MAOverlay {
    
    lazy var coordinate: CLLocationCoordinate2D = {
        return self.polyline.coordinate
    }()
    
    lazy var boundingMapRect: MAMapRect = {
        return self.polyline.boundingMapRect
    }()

    
    var type: MANaviAnnotationType!
    var polyline: MAPolyline
    
    init(polyline: MAPolyline) {
        self.polyline = polyline
        self.type = MANaviAnnotationType.Drive
    }    
}
