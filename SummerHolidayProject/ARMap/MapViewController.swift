//
//  MapViewController.swift
//  SummerHolidayProject
//
//  Created by Darko on 2018/7/17.
//  Copyright © 2018年 Darko. All rights reserved.
//

import UIKit
import MapKit
import GoogleMaps


enum Flow {
    case createMarkerByLongPressAndShowDirection
    case createMarkerByServerProvidedLocations
}


class MapViewController: UIViewController, UIGestureRecognizerDelegate {
    
    @IBOutlet weak var appleMap: MKMapView!
    @IBOutlet weak var googleMapCleanOutlet: UIBarButtonItem!
    
    let defaultZoomLabel: Float = 19.0
    let polylineStokeWidth: CGFloat = 5.0
    
    private var mapView: GMSMapView!
    private var userLocationMarker: GMSMarker!
    private var polyline: GMSPolyline!
    private var dropLocationMarker: GMSMarker!
    
    private var flow: Flow = .createMarkerByLongPressAndShowDirection
    private var paths: [[(Double, Double)]] = []
    private var destination: (Double, Double) = (Double(), Double())
    
    // MARK: View Controller Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        appDelegate.locationManager.delegate = self
        registerNotification()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        appDelegate.locationManager.startUpdatingLocation()
        reachabilityCheck()
        // handleAppleMap()
        handleGoogleMap()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        appDelegate.locationManager.stopUpdatingLocation()
        NotificationCenter.default.removeObserver(self)
    }
    
    private func reachabilityCheck() {
        if !NetworkReachability.isInternetAvailable() {
            let alert = UIAlertController(title: "No Internet", message: "Please connect to Internet", preferredStyle: .alert)
            let okButton = UIAlertAction(title: "OK", style: .default) { (button) in
                alert.dismiss(animated: true, completion: nil)
            }
            alert.addAction(okButton)
            present(alert, animated: true, completion: nil)
        }
    }
    
    private func registerNotification() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationWillEnterForeground, object: nil, queue: OperationQueue.main) { [weak self] (notification) in
            self?.reachabilityCheck()
        }
    }
    
    // MARK: - Apple Map Set up
    
    private func handleAppleMap() {
        
        self.appleMap.delegate = self
        self.appleMap.showsUserLocation = true
        
        let myLocation = CLLocationCoordinate2D(latitude: GPXFile.cherryHillPath.first?.0 ?? 0, longitude: GPXFile.cherryHillPath.first?.1 ?? 0)
        let cabLocation = CLLocationCoordinate2D(latitude: GPXFile.cherryHillPath.last?.0 ?? 0, longitude: GPXFile.cherryHillPath.last?.1 ?? 0)
        
        createRegion(coordinate: myLocation)
        // add annotations
        createAnnotation(location: cabLocation, title: "Cab Location")
    }
    
    private func createRegion(coordinate: CLLocationCoordinate2D) {
        let span = MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001)
        let region = MKCoordinateRegion(center: coordinate, span: span)
        self.appleMap.setRegion(region, animated: true)
    }
    
    private func createAnnotation(location: CLLocationCoordinate2D, title: String) {
        let annotation = MKPointAnnotation()
        annotation.coordinate = location
        annotation.title = title
        self.appleMap.addAnnotation(annotation)
    }
    
    // MARK: - Open AR view
    
    @IBAction func openARView(_ sender: UIBarButtonItem) {
        if let arVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "ARViewController") as? UINavigationController {
            if let vc = arVC.visibleViewController as? ARViewController {
                vc.sectionCoordinates = paths
                vc.carLocation = destination
            }
            self.present(arVC, animated: true, completion: nil)
        }
    }
    
    // MARK: - Google Map Set up
    
    @IBAction func clearGoogleMap(_ sender: UIBarButtonItem) {
        polyline?.map = nil
        dropLocationMarker?.map = nil
        paths = []
        destination = (Double(), Double())
    }
    
    private func handleGoogleMap() {
        
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        if let userLocation = appDelegate.locationManager.location?.coordinate {
            googleMapSetUp(location: userLocation)
        } else {
            googleMapSetUp(location: CLLocationCoordinate2D(latitude: 12.9716, longitude: 77.5946)) // bangalore location
        }
        
        if flow == .createMarkerByLongPressAndShowDirection {
            if mapView != nil {
                mapView.delegate = self
            }
            title = "Tap On Map"
        } else if flow == .createMarkerByServerProvidedLocations {
            
            let fromLocation = CLLocationCoordinate2D(latitude: GPXFile.cherryHillPath.first?.0 ?? 0, longitude: GPXFile.cherryHillPath.first?.1 ?? 0)
            let cabLocation = CLLocationCoordinate2D(latitude: GPXFile.cherryHillPath.last?.0 ?? 0, longitude: GPXFile.cherryHillPath.last?.1 ?? 0)
            let _ = createMarker(location: fromLocation, mapView: mapView, markerTitle: "From Location", snippet: "")
            let _ = createMarker(location: cabLocation, mapView: mapView, markerTitle: "Cab Location", snippet: "Waiting...")
            drawPath(map: mapView, pathArray: GPXFile.cherryHillPath)
        }
    }
    
    private func googleMapSetUp(location: CLLocationCoordinate2D) {
        
        let camera = GMSCameraPosition.camera(withLatitude: location.latitude, longitude: location.longitude, zoom: defaultZoomLabel)
        mapView = GMSMapView.map(withFrame: self.view.bounds, camera: camera)
        mapView.isUserInteractionEnabled = true
        mapView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        view.addSubview(mapView)
    }
    
    private func createMarker(location: CLLocationCoordinate2D, mapView: GMSMapView, markerTitle: String, snippet: String, image: UIImage? = nil, markerName: String? = nil) -> GMSMarker {
        
        let marker = GMSMarker(position: location)
        marker.title = marketTitle
        marker.snippet = snippet
        if let image = image {
            marker.icon = image
            marker.groundAnchor = CGPoint(x: 0.5, y: 1.0)
        }
        if let markerName = markerName {
            maker.userData = markerName
        }
        
        marker.map = mapView
        return marker
    }
    
    private func removeMarker(marker: GMSMarker) {
        marker.map = nil
    }
    
    private func drawPath(map: GMSMapView, pathArray: [(Double, Double)]) {
        
        let path = GMSMutablePath()
        for each in pathArray {
            path.add(CLLocationCoordinate2D(latitude: each.0, longitude: each.1))
        }
        
        let polyline = GMSPolyline(path: path)
        polyline.strokeColor = UIColor.blue
        polyline.strokeWidth = polylineStrokeWidth
        polyline.geodesic = true
        polyline.map = map
    }
}


extension MapViewController: MKMapViewDelegate, CLLocationManagerDelegate {
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        var annotationView: MKAnnotationView?
        annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "annotation")
        annotationView?.canShowCallout = true
        annotationView?.isEnabled = true
        return annotationView
    }
    
    private func sameLocation(location1: CLLocationCoordinate2D, location2: CLLocationCoordinate2D) -> Bool {
        return location1.latitude == location2.latitude && location1.longitude == location2.longitude
    }
    
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        if let location = locations.last {
            
            createRegion(coordinate: location.coordinate)
            if let userLocationMarker = self.userLocationMarker {
                removeMarker(marker: userLocationMarker)
            }
            
            userLocationMarker = GMSMarker(position: location.coordinate)
            userLocationMarker.title = "User Location"
            userLocationMarker.snippet = ""
            if let image = UIImage(named: "blue-dot") {
                userLocationMarker.icon = image
                userLocationMarker.groundAnchor = CGPoint(x: 0.5, y: 1.0)
            }
            userLocationMarker.map = mapView
            
            // one time execution
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate, appDelegate.one_time_execution == false {
                appDelegate.one_time_execution = true
                let cameraPosition = GMSCameraPosition(target: location.coordinate, zoom: defaultZoomLabel, bearing: 0, viewingAngle: 0)
                mapView.animate(to: cameraPosition)
            }
        }
    }
    
    // Getting a new heading
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let rotation = newHeading.magneticHeading * Double.pi / 180.0
        print("rotation: \(rotation)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            // If the status has not yet been determined, ask for authorization
            manager.requestWhenInUseAuthorization()
            break
        case .authorizedWhenInUse:
            // If authorized when in use
            manager.startUpdatingLocation()
            break
        case .authorizedAlways:
            // If always authorized
            manager.startUpdatingLocation()
            break
        case .restricted:
            // If restricted by e.g. parental controls. User can't enable Location Services
            break
        case .denied:
            // If user denied your app access to Location Services, but can grant access from Settings.app
            break
        }
    }
}


extension MapViewController: GMSMapViewDelegate {
    
    // MARK: - Create marker on long press
    
    func mapView(_ mapView: GMSMapView, didLongPressAt coordinate: CLLocationCoordinate2D) {
        
        self.dropLocationMarker?.map = nil
        self.dropLocationMarker = createMarker(location: coordinate, mapView: self.mapView, markerTitle: "Destination", snippet: "", image: UIImage(named: "drop-pin"))
        
        reachabilityCheck()
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        
        if let userLocation = appDelegate.locationManager.location?.coordinate {
            
            if NetworkReachability.isInternetAvailable() {
                
                fetchRoute(source: userLocation, destination: coordinate, completionHandler: { [weak self] (polyline) in
                    
                    if let polyline = polyline as? GMSPolyline {
                        
                        // Add user location
                        let path = GMSMutablePath()
                        if let userLocation = self?.userLocationMarker.position {
                            path.add(userLocation)
                        }
                        
                        // Add rest of the coordinates
                        if let polylinePath = polyline.path, polylinePath.count() > 0 {
                            for i in 0..<polylinePath.count() {
                                path.add(polylinePath.coordinate(at: i))
                            }
                        }
                        
                        let updatedPolyline = GMSPolyline(path: path)
                        updatedPolyline.strokeColor = UIColor.blue
                        updatedPolyline.strokeWidth = self?.polylineStrokeWidth ?? 5.0
                        
                        self?.polyline?.map = nil
                        self?.polyline = updatedPolyline
                        self?.polyline?.map = self?.mapView
                        
                        // Update path and destination
                        self?.destination = (coordinate.latitude, coordinate.longitude)
                        
                        if let path = updatedPolyline.path {
                            
                            var polylinePath: [(Double, Double)] = []
                            for i in 0..<path.count() {
                                let point = path.coordinate(at: i)
                                polylinePath.append((point.latitude, point.longitude))
                            }
                            self?.paths = []
                            self?.paths.append(polylinePath)
                        }
                    }
                    
                })
            }
        }
    }
    
    private func fetchRoute(source: CLLocationCoordinate2D, destination: CLLocationCoordinate2D, completionHandler: ((Any) -> ())? ) {
        
        let origin = String(format: "%f, %f", source.latitude, source.longitude)
        let destination = String(format: "%f, %f", destination.latitude, destination.longitude)
        let directionAPI = "https://maps.googleapis.com/maps/api/directions/json?"
        let directionUrlString = String(format: "%@&origin=%@&destination=%@&mode=driving", directionAPI, origin, destination)  // walking, driving
        
        if let url = URL(string: directionUrlString) {
            
            let fetchDirection = URLSession.shared.dataTask(with: url) { (data: Data?, response: URLResponse?, error: Error?) in
                
                DispatchQueue.main.async {
                    if error == nil && data != nil {
                        var polyline: GMSPolyline?
                        if let dictionary = try? JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.allowFragments) as? [String: Any] {
                            if let routesArray = dictionary?["routes"] as? [Any], !routesArray.isEmpty {
                                if let routeDict = routesArray.first as? [String: Any], !routesArray.isEmpty {
                                    if let routeOverviewPolyine = routeDict["overview_polyline"] as? [String: Any], !routeOverviewPolyline.isEmpty {
                                        if let points = routeOverviewPolyline["points"] as? String {
                                            if let path = GMSPath(fromEncodedPath: points) {
                                                polyline = GMSPolyline(path: path)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        if let polyline = polyline { completionHandler?(polyline) }
                    }
                }
            }
            
            fetchDirection.resume()
        }
    }
}
