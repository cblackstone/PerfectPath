//
//  PathNavigationViewController.swift
//  PerfectPath
//
//  Created by Rachel Martin on 3/21/17.
//  Copyright © 2017 PerfectPath. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import HealthKit

class PathNavigationViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {
    
    var locationManager: CLLocationManager!
    var locations = [CLLocation]()
    var oldLocation: CLLocation!
    @IBOutlet weak var mapView: MKMapView!
    var timer = Timer()
    var seconds = 0.0
    var distance = 0.0
    @IBOutlet weak var paceLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    var pathInformation: [String : Any?] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        locationManager = CLLocationManager()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.delegate = self
        locationManager.activityType = .fitness
        locationManager.distanceFilter = 1.0
        let status = CLLocationManager.authorizationStatus()
        if status == .notDetermined || status == .denied || status == .authorizedWhenInUse {
            locationManager.requestAlwaysAuthorization()
            locationManager.requestWhenInUseAuthorization()
        }
        
        mapView.delegate = self
        mapView.showsUserLocation = true
        mapView.mapType = MKMapType(rawValue: 0)!
        mapView.userTrackingMode = MKUserTrackingMode(rawValue: 2)!
        
        //create dummy route for testing
        let clStartingPoint : CLPlacemark = pathInformation["Starting Location"] as! CLPlacemark
        let mkStartingPoint: MKPlacemark
        let addressDict : [String: Any] = clStartingPoint.addressDictionary as! [String : Any]
        let coordinate = clStartingPoint.location?.coordinate
        mkStartingPoint = MKPlacemark(coordinate: coordinate!, addressDictionary: addressDict)
        
        //generate placeholder path
        let request = MKDirectionsRequest()
        request.source = MKMapItem(placemark: mkStartingPoint)
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2DMake(37.33069, -122.03066), addressDictionary: nil))
        request.transportType = .walking
        let directions = MKDirections(request: request)
        directions.calculate { [unowned self] response, error in
            guard let unwrappedResponse = response else { return }
            if (unwrappedResponse.routes.count > 0) {
                //display route as overlay
                let route: MKPolyline = unwrappedResponse.routes[0].polyline
                route.title = "route"
                self.mapView.add(route)
                self.mapView.setVisibleMapRect(route.boundingMapRect, edgePadding: UIEdgeInsetsMake(10.0, 10.0, 10.0, 10.0) ,animated: false)
            }
        }
        
        seconds = 0.0
        distance = 0.0
        locations.removeAll(keepingCapacity: false)
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.eachSecond(timer:)), userInfo: nil, repeats: true)
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }
    
    func eachSecond(timer: Timer) {
        seconds += 1
        let secondsQuantity = HKQuantity(unit: HKUnit.second(), doubleValue: seconds)
        timeLabel.text = "Time: " + secondsQuantity.description
        let distanceInMiles = ((distance/1609)*100).rounded()/100
        let distanceQuantity = HKQuantity(unit: HKUnit.mile(), doubleValue: distanceInMiles)
        distanceLabel.text = "Distance: " + distanceQuantity.description
        let speedUnit = HKUnit.mile().unitDivided(by: HKUnit.hour())
        let speed = ((distanceInMiles*60*60/(seconds))*100).rounded()/100
        let paceQuantity = HKQuantity(unit: speedUnit, doubleValue: speed)
        paceLabel.text = "Speed: " + paceQuantity.description
    }
    
    override func viewWillAppear(_ animated: Bool) {
        locationManager.requestAlwaysAuthorization()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer.invalidate()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            if location.horizontalAccuracy < 20 {
                //update distance
                if self.locations.count > 0 {
                    distance += location.distance(from: self.locations.last!)
                }
                
                //save location
                self.locations.append(location)
            }
        }
        let newLocation:CLLocation = locations[locations.count - 1]
        if let oldLocationNew = oldLocation as CLLocation? {
            let oldCoordinates = oldLocationNew.coordinate
            let newCoordinates = newLocation.coordinate
            var area = [oldCoordinates, newCoordinates]
            let polyline = MKPolyline(coordinates: &area, count: area.count)
            polyline.title = "user path"
            mapView.add(polyline)
        }
        oldLocation = newLocation
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer! {
        if (overlay is MKPolyline) {
            let polylineRenderer = MKPolylineRenderer(overlay: overlay)
            if overlay.title! == "route" {
                polylineRenderer.strokeColor = UIColor.blue
            } else if overlay.title! == "user path"{
                polylineRenderer.strokeColor = UIColor.red
            }
            polylineRenderer.lineWidth = 3
            return polylineRenderer
        }
        return nil
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    
}
