//
//  NewPathGeneratedControllerView.swift
//  PerfectPath
//
//  Created by Kasey Clark on 3/2/17.
//  Copyright © 2017 PerfectPath. All rights reserved.
//

import UIKit
import MapKit

class NewPathGeneratedControllerView: UIViewController, MKMapViewDelegate {
    var pathInformation: [String : Any?] = [:]

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var distanceLabel: UILabel!        
    @IBOutlet weak var guardianEnabledLabel: UILabel!
    
    //load view of route and metrics
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self        
        guard pathInformation["Starting Location"] != nil else {
            print ("starting location not entered")
            return
        }
        let clStartingPoint : CLPlacemark = pathInformation["Starting Location"] as! CLPlacemark
        let mkStartingPoint: MKPlacemark
        let addressDict : [String: Any] = clStartingPoint.addressDictionary as! [String : Any]
        let coordinate = clStartingPoint.location?.coordinate
        mkStartingPoint = MKPlacemark(coordinate: coordinate!, addressDictionary: addressDict)
        
        //generate placeholder path
        let request = MKDirectionsRequest()
        request.source = MKMapItem(placemark: mkStartingPoint)
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2DMake(37.33019786,  -122.02628653), addressDictionary: nil))
        request.transportType = .walking
        let directions = MKDirections(request: request)
        directions.calculate { [unowned self] response, error in
            guard let unwrappedResponse = response else { return }
            if (unwrappedResponse.routes.count > 0) {
                //display route as overlay
                let route: MKRoute = unwrappedResponse.routes[0]
                let distanceInMiles = route.distance/1609
                let formattedDistance = (Double(distanceInMiles)*100).rounded()/100
                self.distanceLabel.text = "Distance: " + String(formattedDistance) + " mi"
                let line: MKPolyline = route.polyline
                self.mapView.add(line)
                self.mapView.setVisibleMapRect(line.boundingMapRect, edgePadding: UIEdgeInsetsMake(50.0, 20.0, 20.0, 50.0) ,animated: false)
            }
        }
        /*let request2 = MKDirectionsRequest()
        request2.source = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2DMake(37.33019786,  -122.02628653), addressDictionary: nil))
        request2.destination = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2DMake(37.33509587,  -122.02356672), addressDictionary: nil))
        request2.transportType = .walking
        let directions2 = MKDirections(request: request2)
        directions2.calculate { [unowned self] response, error in
            guard let unwrappedResponse = response else { return }
            if (unwrappedResponse.routes.count > 0) {
                //display route as overlay
                let route: MKRoute = unwrappedResponse.routes[0]
                let distanceInMiles = route.distance/1609
                self.distance += distanceInMiles
                let line: MKPolyline = route.polyline
                line.title = "route"
                self.mapView.add(line)
                //self.mapView.setVisibleMapRect(line.boundingMapRect, edgePadding: UIEdgeInsetsMake(20.0, 20.0, 20.0, 20.0) ,animated: false)
            }
        }
        let request3 = MKDirectionsRequest()
        request3.source = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2DMake(37.33509587,  -122.02356672), addressDictionary: nil))
        request3.destination = MKMapItem(placemark: mkStartingPoint)
        request3.transportType = .walking
        let directions3 = MKDirections(request: request3)
        directions3.calculate { [unowned self] response, error in
            guard let unwrappedResponse = response else { return }
            if (unwrappedResponse.routes.count > 0) {
                //display route as overlay
                let route: MKRoute = unwrappedResponse.routes[0]
                let distanceInMiles = route.distance/1609
                self.distance += distanceInMiles
                let line: MKPolyline = route.polyline
                self.mapView.add(line)
                //self.mapView.setVisibleMapRect(line.boundingMapRect, edgePadding: UIEdgeInsetsMake(20.0, 20.0, 20.0, 20.0) ,animated: false)
            }
        }*/
        
        let guardianPathEnabled = pathInformation["Guardian Path Enabled"] as! Bool
        if guardianPathEnabled {
            guardianEnabledLabel.text = "Guardian Enabled: Yes"
        } else {
            guardianEnabledLabel.text = "Guardian Enabled: No"
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer! {
        if (overlay is MKPolyline) {
            let polylineRenderer = MKPolylineRenderer(overlay: overlay)
            polylineRenderer.strokeColor = UIColor.blue
            polylineRenderer.lineWidth = 3
            return polylineRenderer
        }
        return nil
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let destViewController : PathNavigationViewController = segue.destination as! PathNavigationViewController
        destViewController.pathInformation = pathInformation
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
